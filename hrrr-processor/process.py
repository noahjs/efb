#!/usr/bin/env python3
"""
HRRR GRIB2 Processor — extracts grid values from HRRR model data.

Called by HrrrPoller via child_process.execFile().
Reads GRIB2 files (wrfsfcf and/or wrfprsf), extracts weather data at 1° grid
spacing across CONUS, and outputs JSON to stdout for Node.js to ingest.

Usage:
  python process-hrrr.py \
    --surface /tmp/hrrr_sfc_f01.grib2 \
    --pressure /tmp/hrrr_prs_f01.grib2 \
    --grid-spacing 1.0 \
    --lat-min 24 --lat-max 50 \
    --lng-min -125 --lng-max -66

Output (JSON to stdout):
{
  "surface": [ { "lat": 24, "lng": -125, "cloud_total": 85, ... }, ... ],
  "pressure": [ { "lat": 24, "lng": -125, "pressure_level": 850, ... }, ... ]
}
"""

import argparse
import json
import sys
import math
import warnings

import numpy as np

# Suppress cfgrib/xarray warnings about experimental features
warnings.filterwarnings('ignore', category=FutureWarning)
warnings.filterwarnings('ignore', message='.*eccodes.*')


def load_grib2(path, filter_keys=None):
    """Load a GRIB2 file as an xarray Dataset using cfgrib."""
    import xarray as xr

    kwargs = {}
    if filter_keys:
        kwargs['backend_kwargs'] = {'filter_by_keys': filter_keys}

    try:
        return xr.open_dataset(path, engine='cfgrib', **kwargs)
    except Exception:
        # Some GRIB files have multiple hypercubes; try loading all and merging
        datasets = []
        import cfgrib
        for msg in cfgrib.open_datasets(path, backend_kwargs=filter_keys or {}):
            datasets.append(msg)
        if datasets:
            return datasets
        raise


def nearest_idx(arr, value):
    """Find index of nearest value in a sorted array."""
    idx = np.searchsorted(arr, value, side='left')
    if idx > 0 and (idx == len(arr) or abs(value - arr[idx - 1]) < abs(value - arr[idx])):
        return idx - 1
    return idx


def uv_to_dir_speed(u, v):
    """Convert U/V wind components (m/s) to direction (degrees true) and speed (knots)."""
    speed_ms = math.sqrt(u * u + v * v)
    speed_kt = round(speed_ms * 1.944)

    if speed_ms < 0.01:
        return 0, 0

    # Meteorological convention: direction wind is coming FROM
    direction = (270 - math.degrees(math.atan2(v, u))) % 360
    return round(direction), speed_kt


def gpm_to_feet(gpm):
    """Convert geopotential meters to feet MSL."""
    if gpm is None or math.isnan(gpm):
        return None
    return round(gpm * 3.28084)


def meters_to_sm(m):
    """Convert meters to statute miles."""
    if m is None or math.isnan(m):
        return None
    return round(m / 1609.34, 1)


def kelvin_to_celsius(k):
    """Convert Kelvin to Celsius."""
    if k is None or math.isnan(k):
        return None
    return round(k - 273.15, 1)


def compute_flight_category(ceiling_ft, visibility_sm):
    """Derive flight category from ceiling and visibility."""
    if ceiling_ft is not None and ceiling_ft < 500:
        return 'LIFR'
    if visibility_sm is not None and visibility_sm < 1:
        return 'LIFR'
    if ceiling_ft is not None and ceiling_ft < 1000:
        return 'IFR'
    if visibility_sm is not None and visibility_sm < 3:
        return 'IFR'
    if ceiling_ft is not None and ceiling_ft < 3000:
        return 'MVFR'
    if visibility_sm is not None and visibility_sm < 5:
        return 'MVFR'
    return 'VFR'


def safe_float(val):
    """Safely convert a numpy/xarray value to a Python float, handling NaN."""
    if val is None:
        return None
    try:
        f = float(val)
        if math.isnan(f) or math.isinf(f):
            return None
        return f
    except (TypeError, ValueError):
        return None


def extract_value(ds, var_name, lat_idx, lng_idx):
    """Extract a single value from an xarray Dataset at given indices."""
    if var_name not in ds:
        return None
    try:
        val = ds[var_name].values
        if val.ndim == 2:
            return safe_float(val[lat_idx, lng_idx])
        elif val.ndim == 1:
            return safe_float(val[lat_idx])
        elif val.ndim == 0:
            return safe_float(val)
    except (IndexError, KeyError):
        pass
    return None


def process_surface(surface_path, grid_lats, grid_lngs):
    """Extract surface-level data from wrfsfcf GRIB2 file."""
    import cfgrib

    # Open all datasets from the GRIB file (may have multiple hypercubes)
    all_datasets = cfgrib.open_datasets(surface_path)

    # Build a lookup: short_name -> dataset
    var_ds = {}
    for ds in all_datasets:
        for var in ds.data_vars:
            var_ds[var] = ds

    # Get lat/lon arrays from any dataset
    ref_ds = all_datasets[0]
    lats = ref_ds.latitude.values
    lngs = ref_ds.longitude.values

    # HRRR uses 0-360 longitude; convert to -180 to 180 if needed
    if lngs.max() > 180:
        lngs = np.where(lngs > 180, lngs - 360, lngs)

    results = []

    for glat in grid_lats:
        for glng in grid_lngs:
            # Find nearest grid point
            if lats.ndim == 2:
                # Lambert conformal: 2D lat/lon arrays
                dist = (lats - glat) ** 2 + (lngs - glng) ** 2
                lat_idx, lng_idx = np.unravel_index(np.argmin(dist), dist.shape)
            else:
                lat_idx = nearest_idx(lats, glat)
                lng_idx = nearest_idx(lngs, glng)

            def get_val(short_name, ds_override=None):
                ds = ds_override or var_ds.get(short_name)
                if ds is None:
                    return None
                return extract_value(ds, short_name, lat_idx, lng_idx)

            # Cloud composites
            # cfgrib maps TCDC to 'tcc', LCDC to 'lcc', MCDC to 'mcc', HCDC to 'hcc'
            cloud_total = safe_float(get_val('tcc'))
            cloud_low = safe_float(get_val('lcc'))
            cloud_mid = safe_float(get_val('mcc'))
            cloud_high = safe_float(get_val('hcc'))

            # Cloud geometry
            # cfgrib may use different short names; try common ones
            ceiling_gpm = safe_float(get_val('ceil'))
            cloud_base_gpm = safe_float(get_val('gh') if 'gh' in var_ds else get_val('ceil'))
            cloud_top_gpm = None  # Cloud top may be in a separate message

            ceiling_ft = gpm_to_feet(ceiling_gpm) if ceiling_gpm is not None else None
            cloud_base_ft = gpm_to_feet(cloud_base_gpm) if cloud_base_gpm is not None else None
            cloud_top_ft = gpm_to_feet(cloud_top_gpm) if cloud_top_gpm is not None else None

            # Visibility
            vis_m = safe_float(get_val('vis'))
            visibility_sm = meters_to_sm(vis_m) if vis_m is not None else None

            # Flight category
            flight_category = compute_flight_category(ceiling_ft, visibility_sm)

            # Surface wind (U/V at 10m)
            u10 = safe_float(get_val('u10'))
            v10 = safe_float(get_val('v10'))
            if u10 is not None and v10 is not None:
                wind_dir, wind_speed_kt = uv_to_dir_speed(u10, v10)
            else:
                wind_dir, wind_speed_kt = None, None

            # Wind gust
            gust_ms = safe_float(get_val('gust') or get_val('i10fg'))
            wind_gust_kt = round(gust_ms * 1.944) if gust_ms is not None else None

            # Surface temperature (2m, Kelvin)
            t2m = safe_float(get_val('t2m'))
            temperature_c = kelvin_to_celsius(t2m) if t2m is not None else None

            # Clamp cloud values to 0-100
            def clamp_cloud(v):
                if v is None:
                    return None
                return max(0, min(100, round(v)))

            results.append({
                'lat': glat,
                'lng': glng,
                'cloud_total': clamp_cloud(cloud_total),
                'cloud_low': clamp_cloud(cloud_low),
                'cloud_mid': clamp_cloud(cloud_mid),
                'cloud_high': clamp_cloud(cloud_high),
                'ceiling_ft': ceiling_ft,
                'cloud_base_ft': cloud_base_ft,
                'cloud_top_ft': cloud_top_ft,
                'flight_category': flight_category,
                'visibility_sm': visibility_sm,
                'wind_dir': wind_dir,
                'wind_speed_kt': wind_speed_kt,
                'wind_gust_kt': wind_gust_kt,
                'temperature_c': temperature_c,
            })

    return results


def process_pressure(pressure_path, grid_lats, grid_lngs, levels):
    """Extract pressure-level data from wrfprsf GRIB2 file."""
    import cfgrib

    # Pressure level to altitude mapping (feet MSL)
    level_altitudes = {
        1000: 360, 950: 1640, 925: 2500, 900: 3200, 850: 5000,
        800: 6200, 700: 10000, 600: 14000, 500: 18000,
        400: 24000, 300: 30000, 250: 34000, 200: 39000, 150: 44000,
    }

    results = []

    for level_hpa in levels:
        level_pa = level_hpa * 100  # cfgrib uses Pa

        # Try loading with pressure level filter
        try:
            datasets = cfgrib.open_datasets(
                pressure_path,
                backend_kwargs={'filter_by_keys': {'typeOfLevel': 'isobaricInhPa', 'level': level_hpa}},
            )
        except Exception:
            # Fallback: load all and filter
            try:
                datasets = cfgrib.open_datasets(pressure_path)
            except Exception as e:
                print(f"Warning: Could not load pressure level {level_hpa}: {e}", file=sys.stderr)
                continue

        if not datasets:
            continue

        # Build variable lookup for this level
        var_ds = {}
        for ds in datasets:
            for var in ds.data_vars:
                var_ds[var] = ds

        ref_ds = datasets[0]
        lats = ref_ds.latitude.values
        lngs = ref_ds.longitude.values

        if lngs.max() > 180:
            lngs = np.where(lngs > 180, lngs - 360, lngs)

        alt_ft = level_altitudes.get(level_hpa, 0)

        for glat in grid_lats:
            for glng in grid_lngs:
                if lats.ndim == 2:
                    dist = (lats - glat) ** 2 + (lngs - glng) ** 2
                    lat_idx, lng_idx = np.unravel_index(np.argmin(dist), dist.shape)
                else:
                    lat_idx = nearest_idx(lats, glat)
                    lng_idx = nearest_idx(lngs, glng)

                def get_val(short_name):
                    ds = var_ds.get(short_name)
                    if ds is None:
                        return None
                    return extract_value(ds, short_name, lat_idx, lng_idx)

                # Relative humidity at this level (RH > 80% indicates cloud)
                rh = safe_float(get_val('r'))
                def clamp_pct(v):
                    if v is None:
                        return None
                    return max(0, min(100, round(v)))

                # Wind U/V at this level
                u = safe_float(get_val('u'))
                v = safe_float(get_val('v'))
                if u is not None and v is not None:
                    wind_dir, wind_speed_kt = uv_to_dir_speed(u, v)
                else:
                    wind_dir, wind_speed_kt = None, None

                # Temperature at this level (Kelvin)
                t = safe_float(get_val('t'))
                temperature_c = kelvin_to_celsius(t) if t is not None else None

                results.append({
                    'lat': glat,
                    'lng': glng,
                    'pressure_level': level_hpa,
                    'altitude_ft': alt_ft,
                    'relative_humidity': clamp_pct(rh),
                    'wind_dir': wind_dir,
                    'wind_speed_kt': wind_speed_kt,
                    'temperature_c': temperature_c,
                })

    return results


def main():
    parser = argparse.ArgumentParser(description='Process HRRR GRIB2 data')
    parser.add_argument('--surface', help='Path to wrfsfcf GRIB2 file')
    parser.add_argument('--pressure', help='Path to wrfprsf GRIB2 file')
    parser.add_argument('--grid-spacing', type=float, default=1.0)
    parser.add_argument('--lat-min', type=float, default=24.0)
    parser.add_argument('--lat-max', type=float, default=50.0)
    parser.add_argument('--lng-min', type=float, default=-125.0)
    parser.add_argument('--lng-max', type=float, default=-66.0)
    parser.add_argument('--pressure-levels', default='1000,950,925,900,850,800,700,600,500,400,300,250,200,150',
                        help='Comma-separated pressure levels in hPa')

    args = parser.parse_args()

    # Generate grid points
    spacing = args.grid_spacing
    grid_lats = list(np.arange(args.lat_min, args.lat_max + spacing, spacing))
    grid_lngs = list(np.arange(args.lng_min, args.lng_max + spacing, spacing))

    pressure_levels = [int(p) for p in args.pressure_levels.split(',')]

    output = {'surface': [], 'pressure': []}

    if args.surface:
        print(f"Processing surface file: {args.surface}", file=sys.stderr)
        output['surface'] = process_surface(args.surface, grid_lats, grid_lngs)
        print(f"  Extracted {len(output['surface'])} surface grid points", file=sys.stderr)

    if args.pressure:
        print(f"Processing pressure file: {args.pressure}", file=sys.stderr)
        output['pressure'] = process_pressure(
            args.pressure, grid_lats, grid_lngs, pressure_levels,
        )
        print(f"  Extracted {len(output['pressure'])} pressure-level grid points", file=sys.stderr)

    # Output JSON to stdout (Node.js reads this)
    json.dump(output, sys.stdout, separators=(',', ':'))


if __name__ == '__main__':
    main()
