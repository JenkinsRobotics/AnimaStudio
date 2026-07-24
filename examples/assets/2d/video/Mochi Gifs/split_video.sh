#!/bin/bash

# --- Configuration ---
# The script will look for the input video in its own directory.
INPUT_VIDEO="mochi.mp4"
OUTPUT_DIR="video_splits_ffmpeg"
GRID_ROWS=5
GRID_COLS=2

# --- Video Properties ---
# Original video dimensions
VIDEO_WIDTH=576
VIDEO_HEIGHT=1024

# Padding to remove from the original video
TOP_BORDER=24
BOTTOM_BORDER=40 # This is for documentation; only TOP_BORDER is needed for the offset calculation

# --- Script ---

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Define absolute paths based on the script's location
ABS_INPUT_VIDEO="${SCRIPT_DIR}/${INPUT_VIDEO}"
ABS_OUTPUT_DIR="${SCRIPT_DIR}/${OUTPUT_DIR}"

# Calculate the dimensions of the active video area (after removing padding)
ACTIVE_VIDEO_HEIGHT=$((VIDEO_HEIGHT - TOP_BORDER - BOTTOM_BORDER)) # 1024 - 24 - 40 = 960

# Calculate the final dimensions of each grid cell
CELL_WIDTH=$((VIDEO_WIDTH / GRID_COLS)) # 576 / 2 = 288
CELL_HEIGHT=$((ACTIVE_VIDEO_HEIGHT / GRID_ROWS)) # 960 / 5 = 192

# Create output directory if it doesn't exist
mkdir -p "$ABS_OUTPUT_DIR"

echo "Original video dimensions: ${VIDEO_WIDTH}x${VIDEO_HEIGHT}"
echo "Removing top border of ${TOP_BORDER}px and bottom border of ${BOTTOM_BORDER}px."
echo "Active area to split: ${VIDEO_WIDTH}x${ACTIVE_VIDEO_HEIGHT}"
echo "Splitting into a ${GRID_COLS}x${GRID_ROWS} grid..."
echo "Each cell will be ${CELL_WIDTH}x${CELL_HEIGHT} pixels."

# Loop through rows and columns to create cropped videos
for r in $(seq 0 $((GRID_ROWS - 1))); do
    for c in $(seq 0 $((GRID_COLS - 1))); do
        # Calculate the top-left corner (x, y) for the crop from the original video frame
        X_OFFSET=$((c * CELL_WIDTH))
        # The Y offset must skip the top border, then find the correct row position
        Y_OFFSET=$((TOP_BORDER + (r * CELL_HEIGHT)))
        
        OUTPUT_FILE="${ABS_OUTPUT_DIR}/split_${r}_${c}.mp4"

        echo "Processing tile at row ${r}, col ${c} (source offset x:${X_OFFSET}, y:${Y_OFFSET})..."

        # Use ffmpeg to crop a section from the original video.
        # The filter is "crop=width:height:x:y"
        ffmpeg -i "$ABS_INPUT_VIDEO" -vf "crop=${CELL_WIDTH}:${CELL_HEIGHT}:${X_OFFSET}:${Y_OFFSET}" -an "$OUTPUT_FILE" -y
    done
done

echo "Video splitting complete. Files are in '${ABS_OUTPUT_DIR}'"
