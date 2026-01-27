#!/bin/bash

# Check if the 'link' parameter is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <link>"
  exit 1
fi

# Assign the first argument to the variable link
link=$1

# Step 1: Run the command with the provided link
/home/tt/storage/main/d-fi/d-fi -d -conf '/home/tt/storage/main/d-fi/d-fi.config.json' -q flac -u "$link"

# Step 2: Get all folder names in '/home/tt/storage/main/d-fi/Playlist'
playlist_folders=("/home/tt/storage/main/d-fi/Playlist"/*)

# Step 3: Iterate over each folder in the Playlist directory
for playlist_folder in "${playlist_folders[@]}"; do
  if [ -d "$playlist_folder" ]; then
    # Extract the folder name (without path)
    folder_name=$(basename "$playlist_folder")
    
    # Check if this folder exists in '/home/tt/storage/main/music'
    music_folder="/home/tt/storage/main/music/$folder_name"
    if [ -d "$music_folder" ]; then
      # Get all file names in the Playlist folder
      playlist_files=("$playlist_folder"/*)
      
      for playlist_file in "${playlist_files[@]}"; do
        if [ -f "$playlist_file" ]; then
          # Extract the file name (without path)
          file_name=$(basename "$playlist_file")
          
          # Check if this file exists in the music folder using a wildcard search
          found_duplicate=false
          for music_file in "$music_folder"/*; do
            if [ -f "$music_file" ]; then
              music_file_name=$(basename "$music_file")
              if [[ "$music_file_name" == *"$file_name"* ]]; then
                echo "Deleting $playlist_file as it is a duplicate."
                rm "$playlist_file"
                found_duplicate=true
                break
              fi
            fi
          done
        fi
      done
    fi
  fi
done

# Step 4: Copy all folders from '/home/tt/storage/main/d-fi/Playlist' to '/home/tt/storage/main/music'
cp -r /home/tt/storage/main/d-fi/Playlist/* /home/tt/storage/main/music/

# Step 5: Collect the file paths of transferred files into an array
transferred_files=()
for playlist_folder in "${playlist_folders[@]}"; do
  if [ -d "$playlist_folder" ]; then
    for playlist_file in "${playlist_files[@]}"; do
      if [ -f "$playlist_file" ]; then
        transferred_files+=("$playlist_file")
      fi
    done
  fi
done

# Step 6: Create a .m3u playlist file with the paths of transferred files
playlist_file="/home/tt/storage/main/music/playlists/playlist.m3u"
echo "#EXTM3U" > "$playlist_file"
for file_path in "${transferred_files[@]}"; do
  echo "$(realpath "$file_path")" >> "$playlist_file"
done

echo "Playlist creation complete."

