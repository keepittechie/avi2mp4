#!/bin/bash

# Mounted directory location on the remote computer
SEARCH_DIR="Path-to-Directory"

# Function to convert AVI to MP4 with balanced compression
convert_video() {
    local FILE="$1"
    local MP4_FILE="${FILE%.avi}.mp4"

    # Check if the MP4 file already exists
    if [ -f "$MP4_FILE" ]; then
        echo "Skipping conversion: '$MP4_FILE' already exists."
        return 2
    fi

    # Check if the input file exists
    if [ ! -f "$FILE" ]; then
        echo "Error: File not found '$FILE'"
        return 1
    fi

    # Get video duration using ffprobe
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FILE" 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error with ffprobe: $duration"
        return 1
    fi

    local duration_ms=$(echo "$duration*1000000" | bc | cut -d'.' -f1)

    # Start conversion with adjusted CRF and preset for better size management
    (ffmpeg -i "$FILE" -c:v libx264 -preset faster -crf 23 -c:a aac -b:a 192k -progress pipe:1 "$MP4_FILE" 2>&1 & pid=$!
    trap "kill $pid 2> /dev/null" EXIT
    while kill -0 $pid 2> /dev/null; do
        sleep 1
    done
    trap - EXIT) | while IFS='=' read -r key value; do
        if [[ $key == 'out_time_ms' ]]; then
            local percent=$(echo "scale=2; $value/$duration_ms*100" | bc)
            echo -ne "Converting: $(printf "%.2f" $percent)%\r"
        fi
    done

    if wait $pid; then
        echo -e "\nCompleted: '$MP4_FILE'"
    else
        echo -e "\nConversion failed: '$MP4_FILE'"
        return 1
    fi
}

# Initialize counter and file count
CURRENT=0
TOTAL=$(find "$SEARCH_DIR" -type f -name "*.avi" -print0 | grep -cz '^')

echo "Searching for AVI files in '$SEARCH_DIR'. Total files found: $TOTAL"

# Process all AVI files in the directory
find "$SEARCH_DIR" -type f -name "*.avi" -print0 | while IFS= read -r -d $'\0' FILE; do
    CURRENT=$((CURRENT+1))
    echo "Processing $CURRENT of $TOTAL: '$FILE'"
    convert_video "$FILE"
done

echo "All conversions completed."
