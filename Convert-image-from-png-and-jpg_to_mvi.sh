#!/bin/bash

# Script Directory
script_dir="$(dirname "$(realpath "$0")")"

# Supported image formats and resolutions
supported_formats=("jpg" "jpeg" "png")
resolutions=("1280x720" "1920x1080")

# Counters for success and error
success_count=0
error_count=0

# Temporary directory for conversions
temp_dir="/tmp/image_conversion"
mkdir -p "$temp_dir" || { echo ">>> Error: Unable to create temporary directory."; exit 1; }

# Function to check and install a package
check_and_install_package() {
    local package="$1"
    echo ">>> Checking if $package is installed..."
    if ! command -v "$package" &> /dev/null; then
        echo ">>> $package is not installed. Attempting to install..."
        if opkg list | grep -q "^$package "; then
            echo ">>> $package is available in the feed. Installing..."
            opkg update > /dev/null 2>&1
            if ! opkg install "$package"; then
                echo ">>> Failed to install $package. Exiting."
                exit 1
            fi
        else
            echo ">>> $package is not available in the feed. Exiting."
            exit 1
        fi
    else
        echo ">>> $package is already installed."
    fi
}

# Check if ffmpeg is installed
check_and_install_package "ffmpeg"

# Start conversion process
echo ">>> Starting image conversion in folder: $script_dir ..."

# Find all supported images
images=()
for fmt in "${supported_formats[@]}"; do
    while IFS= read -r -d '' file; do
        images+=("$file")
    done < <(find "$script_dir" -maxdepth 1 -type f \( -iname "*.$fmt" \) -print0)
done

total_files=${#images[@]}

# If no images found, exit
if [ "$total_files" -eq 0 ]; then
    echo ">>> No images found for conversion."
    exit 1
else
    echo ">>> Found $total_files images for conversion."
fi

start_time=$(date +%s)

# Process each image
for i in "${!images[@]}"; do
    file="${images[$i]}"
    base_name=$(basename "$file")
    ext="${file##*.}"
    image_name="${base_name%.*}"

    for resolution in "${resolutions[@]}"; do
        width="${resolution%x*}"
        height="${resolution#*x}"

        resized_image="$temp_dir/${image_name}_${width}x${height}.png"
        temp_video="$temp_dir/temp_video_${width}x${height}.mpg"
        output_file="$script_dir/${image_name}_${width}x${height}.mvi"

        # Resize the image
        if ! ffmpeg -y -i "$file" -vf "scale=$width:$height" "$resized_image" > /dev/null 2>&1; then
            echo ">>> Error: Failed to resize image $file to resolution $resolution."
            ((error_count++))
            continue
        fi

        # Convert resized image to video
        if ! ffmpeg -y -loop 1 -i "$resized_image" -c:v mpeg1video -t 1 "$temp_video" > /dev/null 2>&1; then
            echo ">>> Error: Failed to convert resized image $resized_image to video."
            ((error_count++))
            continue
        fi

        # Move the final output
        mv "$temp_video" "$output_file" || {
            echo ">>> Error: Failed to move video $temp_video to $output_file."
            ((error_count++))
            continue
        }
        ((success_count++))
    done
done

# Clean up temporary directory
rm -rf "$temp_dir"

end_time=$(date +%s)
total_elapsed_time=$((end_time - start_time))
total_minutes=$((total_elapsed_time / 60))
total_seconds=$((total_elapsed_time % 60))

# Final output summary
echo ">>> Conversion completed!"
echo "Total files processed: $total_files"
echo "Successful conversions: $success_count"
echo "Failed conversions: $error_count"
echo "Total time taken: ${total_minutes} minutes and ${total_seconds} seconds."
echo ">>> Best regards, Mohamed ElSafty $(date '+%d-%m-%Y')."


