#!/bin/bash

# Define the directory path
DIR="/mnt/tt-s2/shared/notes/ttnotes/daily"

# Get the current date and yesterday's date in DD-MM-YYYY format
CURRENT_DATE=$(date +%d-%m-%Y)
YESTERDAY_DATE=$(date -d "yesterday" +%d-%m-%Y)

# Define the file names
CURRENT_FILE="$DIR/$CURRENT_DATE.md"
YESTERDAY_FILE="$DIR/$YESTERDAY_DATE.md"

# Check if today's note already exists
if [ ! -f "$CURRENT_FILE" ]; then
    # Create today's note and pre-populate it with the required content
    echo -e "# $CURRENT_DATE Daily note\n\n## Todo\n- [ ] \n- [ ] \n- [ ] \n- [ ] \n- [ ] \n\n## Extra" > "$CURRENT_FILE"
fi

# Function to check if a line exists in a file
line_exists() {
    grep -Fxq "$1" "$2"
}

# Find the last created note if yesterday's note doesn't exist or is not in the same month
if [ ! -f "$YESTERDAY_FILE" ]; then
    # Get a list of all markdown files sorted by modification time (newest first)
    LAST_NOTE=$(ls -tr "$DIR"/*.md 2>/dev/null | head -n 1)

    # If there are no notes, exit the script or handle accordingly
    if [ ! "$LAST_NOTE" ]; then
        echo "No previous notes found."
        nvim "$CURRENT_FILE"
        exit 0
    fi

    LAST_NOTE_DATE=$(basename "$LAST_NOTE" .md)
else
    LAST_NOTE="$YESTERDAY_FILE"
    LAST_NOTE_DATE="$YESTERDAY_DATE"
fi

# Add a link to today's note at the end of the last created note if the link doesn't already exist
CURRENT_LINK="[Next Day: $CURRENT_DATE](./$CURRENT_DATE.md)"
if ! line_exists "$CURRENT_LINK" "$LAST_NOTE"; then
    echo -e "\n\n$CURRENT_LINK" >> "$LAST_NOTE"
fi

# Add a link to the last created note at the top of today's note if the link doesn't already exist
LAST_NOTE_LINK="[Previous Day: $LAST_NOTE_DATE](./$LAST_NOTE_DATE.md)"
if ! line_exists "$LAST_NOTE_LINK" "$CURRENT_FILE"; then
    echo -e "\n$LAST_NOTE_LINK\n" | cat - "$CURRENT_FILE" > temp && mv temp "$CURRENT_FILE"
fi

# Open Neovim with the specified file
nvim "$CURRENT_FILE"
