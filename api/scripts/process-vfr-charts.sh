#!/bin/bash
#
# FAA VFR Sectional Chart Tile Generator
#
# Downloads FAA VFR Sectional GeoTIFFs and converts them to
# XYZ web map tiles for use as a Mapbox raster source.
#
# Usage: ./scripts/process-vfr-charts.sh [chart_name]
#   e.g.: ./scripts/process-vfr-charts.sh Denver
#   No argument = process Denver only (for prototype)
#
# Requirements: gdal2tiles.py (brew install gdal)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$(dirname "$SCRIPT_DIR")"
RAW_DIR="$API_DIR/data/charts/raw"
TILES_DIR="$API_DIR/data/charts/tiles"

# FAA chart edition date (update each 56-day cycle)
EDITION_DATE="01-22-2026"
BASE_URL="https://aeronav.faa.gov/visual/$EDITION_DATE/sectional-files"

# Charts to process (default: just Denver for prototype)
CHARTS="${1:-Denver}"

mkdir -p "$RAW_DIR" "$TILES_DIR"

for CHART in $CHARTS; do
    echo ""
    echo "=== Processing: $CHART ==="

    ZIP_FILE="$RAW_DIR/${CHART}.zip"
    TIFF_DIR="$RAW_DIR/${CHART}"

    # Step 1: Download
    if [ ! -f "$ZIP_FILE" ]; then
        echo "Downloading $CHART sectional..."
        curl -L -o "$ZIP_FILE" "$BASE_URL/${CHART}.zip"
        echo "  Downloaded: $(du -h "$ZIP_FILE" | cut -f1)"
    else
        echo "  Already downloaded: $ZIP_FILE"
    fi

    # Step 2: Extract
    if [ ! -d "$TIFF_DIR" ]; then
        echo "Extracting..."
        mkdir -p "$TIFF_DIR"
        unzip -o "$ZIP_FILE" -d "$TIFF_DIR"
    else
        echo "  Already extracted: $TIFF_DIR"
    fi

    # Step 3: Find the GeoTIFF
    GEOTIFF=$(find "$TIFF_DIR" -name "*.tif" -type f | head -1)
    if [ -z "$GEOTIFF" ]; then
        echo "  ERROR: No .tif file found in $TIFF_DIR"
        continue
    fi
    echo "  GeoTIFF: $GEOTIFF"

    # Step 4a: Convert indexed color to RGBA
    RGB_FILE="$RAW_DIR/${CHART}_rgba.tif"
    if [ ! -f "$RGB_FILE" ]; then
        echo "Converting to RGBA..."
        gdal_translate \
            -expand rgba \
            -co COMPRESS=LZW \
            "$GEOTIFF" "$RGB_FILE"
        echo "  RGBA: $(du -h "$RGB_FILE" | cut -f1)"
    else
        echo "  Already converted: $RGB_FILE"
    fi

    # Step 4b: Reproject to Web Mercator (EPSG:3857)
    REPROJECTED="$RAW_DIR/${CHART}_3857.tif"
    if [ ! -f "$REPROJECTED" ]; then
        echo "Reprojecting to EPSG:3857..."
        gdalwarp \
            -t_srs EPSG:3857 \
            -r bilinear \
            -dstalpha \
            -co COMPRESS=LZW \
            "$RGB_FILE" "$REPROJECTED"
        echo "  Reprojected: $(du -h "$REPROJECTED" | cut -f1)"
    else
        echo "  Already reprojected: $REPROJECTED"
    fi

    # Step 5: Generate XYZ tiles
    CHART_TILES="$TILES_DIR/vfr-sectional/${CHART}"
    if [ ! -d "$CHART_TILES" ]; then
        echo "Generating tiles (zoom 5-11, this may take a few minutes)..."
        gdal2tiles.py \
            --zoom=5-11 \
            --processes=4 \
            --tmscompatible \
            --webviewer=none \
            --resampling=bilinear \
            "$REPROJECTED" "$CHART_TILES"

        # Count tiles
        TILE_COUNT=$(find "$CHART_TILES" -name "*.png" | wc -l | tr -d ' ')
        echo "  Generated $TILE_COUNT tiles"
    else
        echo "  Tiles already exist: $CHART_TILES"
    fi

    echo "=== $CHART complete ==="
done

echo ""
echo "=== All charts processed ==="
echo "Tiles directory: $TILES_DIR"
echo ""
echo "To serve these tiles, the NestJS API will expose them at:"
echo "  /api/tiles/vfr-sectional/{chart}/{z}/{x}/{y}.png"
