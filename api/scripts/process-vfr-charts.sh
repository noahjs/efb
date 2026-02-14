#!/bin/bash
#
# FAA VFR Chart Tile Generator
#
# Downloads FAA VFR Sectional and Terminal Area Chart (TAC) GeoTIFFs
# and converts them to XYZ web map tiles for use as a Mapbox raster source.
#
# Usage:
#   ./scripts/process-vfr-charts.sh                    # Process all sectionals + all TACs
#   ./scripts/process-vfr-charts.sh sectional Denver    # Process one sectional
#   ./scripts/process-vfr-charts.sh tac Phoenix         # Process one TAC
#   ./scripts/process-vfr-charts.sh sectional           # All sectionals only
#   ./scripts/process-vfr-charts.sh tac                 # All TACs only
#
# Requirements: gdal2tiles.py, gdalwarp, gdal_translate, nearblack (brew install gdal)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$(dirname "$SCRIPT_DIR")"
RAW_DIR="$API_DIR/data/charts/raw"
TILES_DIR="$API_DIR/data/charts/tiles"

# FAA chart edition date (update each 56-day cycle)
EDITION_DATE="01-22-2026"

# ---------------------------------------------------------------------------
# All 37 FAA VFR Sectional Charts (full CONUS + Alaska + Hawaii)
# ---------------------------------------------------------------------------
ALL_SECTIONALS=(
    Albuquerque
    Anchorage
    Atlanta
    Bethel
    Billings
    Brownsville
    Cape_Lisburne
    Charlotte
    Cheyenne
    Chicago
    Cincinnati
    Cold_Bay
    Dallas-Ft_Worth
    Dawson
    Denver
    Detroit
    Dutch_Harbor
    El_Paso
    Fairbanks
    Great_Falls
    Green_Bay
    Halifax
    Hawaiian_Islands
    Houston
    Jacksonville
    Juneau
    Kansas_City
    Ketchikan
    Lake_Huron
    Las_Vegas
    Los_Angeles
    McGrath
    Memphis
    Miami
    Minneapolis
    Montreal
    New_Orleans
    New_York
    Nome
    Omaha
    Phoenix
    Point_Barrow
    Salt_Lake_City
    San_Antonio
    San_Francisco
    Seattle
    Seward
    St_Louis
    Twin_Cities
    Washington
    Western_Aleutian_Islands
    Wichita
)

# ---------------------------------------------------------------------------
# All 30 FAA Terminal Area Charts (Class B airspace areas)
# ---------------------------------------------------------------------------
ALL_TACS=(
    Anchorage-Fairbanks
    Atlanta
    Baltimore-Washington
    Boston
    Charlotte
    Chicago
    Cincinnati
    Cleveland
    Dallas-Ft_Worth
    Denver
    Detroit
    Houston
    Kansas_City
    Las_Vegas
    Los_Angeles
    Memphis
    Miami
    Minneapolis-St_Paul
    New_Orleans
    New_York
    Philadelphia
    Phoenix
    Pittsburgh
    Puerto_Rico-VI
    Salt_Lake_City
    San_Diego
    San_Francisco
    Seattle
    St_Louis
    Tampa-Orlando
)

# ---------------------------------------------------------------------------
# process_chart <chart_type> <chart_name>
#   chart_type: "sectional" or "tac"
# ---------------------------------------------------------------------------
process_chart() {
    local CHART_TYPE="$1"
    local CHART="$2"

    if [ "$CHART_TYPE" = "tac" ]; then
        local URL_BASE="https://aeronav.faa.gov/visual/$EDITION_DATE/tac-files"
        local ZIP_NAME="${CHART}_TAC.zip"
        local TILE_SUBDIR="vfr-tac"
        local ZOOM="7-13"
        local LABEL="TAC"
    else
        local URL_BASE="https://aeronav.faa.gov/visual/$EDITION_DATE/sectional-files"
        local ZIP_NAME="${CHART}.zip"
        local TILE_SUBDIR="vfr-sectional"
        local ZOOM="5-11"
        local LABEL="Sectional"
    fi

    echo ""
    echo "=== Processing $LABEL: $CHART ==="

    local PREFIX="${CHART_TYPE}_${CHART}"
    local ZIP_FILE="$RAW_DIR/${PREFIX}.zip"
    local TIFF_DIR="$RAW_DIR/${PREFIX}"

    # Step 1: Download
    if [ ! -f "$ZIP_FILE" ]; then
        echo "Downloading $CHART $LABEL..."
        curl -L -o "$ZIP_FILE" "$URL_BASE/$ZIP_NAME"
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
        return 1
    fi
    echo "  GeoTIFF: $GEOTIFF"

    # Step 4a: Convert indexed color to RGBA
    local RGB_FILE="$RAW_DIR/${PREFIX}_rgba.tif"
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

    # Step 4b: Remove white chart collar by making border pixels transparent
    # This trims the white edges/border outside the chart neatline for both
    # sectional and TAC charts so adjacent charts blend seamlessly.
    local TRIMMED_FILE="$RAW_DIR/${PREFIX}_trimmed.tif"
    if [ ! -f "$TRIMMED_FILE" ]; then
        echo "Removing white border (nearblack)..."
        nearblack \
            -white \
            -near 20 \
            -setalpha \
            -co COMPRESS=LZW \
            -o "$TRIMMED_FILE" \
            "$RGB_FILE"
        echo "  Trimmed: $(du -h "$TRIMMED_FILE" | cut -f1)"
    else
        echo "  Already trimmed: $TRIMMED_FILE"
    fi

    # Step 4c: Reproject to Web Mercator (EPSG:3857)
    local REPROJECTED="$RAW_DIR/${PREFIX}_3857.tif"
    if [ ! -f "$REPROJECTED" ]; then
        echo "Reprojecting to EPSG:3857..."
        gdalwarp \
            -t_srs EPSG:3857 \
            -r bilinear \
            -dstalpha \
            -co COMPRESS=LZW \
            "$TRIMMED_FILE" "$REPROJECTED"
        echo "  Reprojected: $(du -h "$REPROJECTED" | cut -f1)"
    else
        echo "  Already reprojected: $REPROJECTED"
    fi

    # Step 5: Generate XYZ tiles
    # Sectionals: zoom 5-11 (1:500,000 scale)
    # TACs:       zoom 7-13 (1:250,000 scale — 2x detail)
    local CHART_TILES="$TILES_DIR/${TILE_SUBDIR}/${CHART}"
    if [ ! -d "$CHART_TILES" ]; then
        echo "Generating tiles (zoom $ZOOM, this may take a few minutes)..."
        gdal2tiles.py \
            --zoom="$ZOOM" \
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

    echo "=== $CHART $LABEL complete ==="
}

# ---------------------------------------------------------------------------
# Main: parse arguments
# ---------------------------------------------------------------------------
mkdir -p "$RAW_DIR" "$TILES_DIR"

CHART_TYPE="${1:-all}"    # "sectional", "tac", or "all"
CHART_NAME="${2:-}"       # optional: specific chart name

case "$CHART_TYPE" in
    sectional)
        if [ -n "$CHART_NAME" ]; then
            process_chart sectional "$CHART_NAME"
        else
            for CHART in "${ALL_SECTIONALS[@]}"; do
                process_chart sectional "$CHART"
            done
        fi
        ;;
    tac)
        if [ -n "$CHART_NAME" ]; then
            process_chart tac "$CHART_NAME"
        else
            for CHART in "${ALL_TACS[@]}"; do
                process_chart tac "$CHART"
            done
        fi
        ;;
    all)
        echo "Processing all VFR Sectional charts..."
        for CHART in "${ALL_SECTIONALS[@]}"; do
            process_chart sectional "$CHART"
        done
        echo ""
        echo "Processing all Terminal Area Charts..."
        for CHART in "${ALL_TACS[@]}"; do
            process_chart tac "$CHART"
        done
        ;;
    *)
        echo "Usage: $0 [sectional|tac|all] [chart_name]"
        echo "  $0                          # Process everything"
        echo "  $0 sectional Denver         # One sectional"
        echo "  $0 tac Phoenix              # One TAC"
        echo "  $0 sectional                # All sectionals"
        echo "  $0 tac                      # All TACs"
        exit 1
        ;;
esac

echo ""
echo "=== All charts processed ==="
echo "Tiles directory: $TILES_DIR"
echo ""
echo "Tiles are served at:"
echo "  /api/tiles/vfr-sectional/{chart}/{z}/{x}/{y}.png"
echo "  /api/tiles/vfr-tac/{chart}/{z}/{x}/{y}.png"
