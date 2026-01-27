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
    echo -e "# $CURRENT_DATE\n\n## todo\n- [ ] \n- [ ] \n- [ ] \n- [ ] \n- [ ] \n\n## extra" > "$CURRENT_FILE"
fi

# Function to check if a line exists in a file
line_exists() {
    grep -Fxq "$1" "$2"
}

# Check if yesterday's note exists and add a link to today's note if the link doesn't already exist
if [ -f "$YESTERDAY_FILE" ]; then
    YESTERDAY_LINK="[Next Day: $CURRENT_DATE](./$CURRENT_DATE.md)"
    if ! line_exists "$YESTERDAY_LINK" "$YESTERDAY_FILE"; then
        echo -e "\n\n$YESTERDAY_LINK" >> "$YESTERDAY_FILE"
    fi
fi

# Add a link to yesterday's note at the top of today's note (if it exists) if the link doesn't already exist
if [ -f "$YESTERDAY_FILE" ]; then
    YESTERDAY_NOTE_LINK="[Previous Day: $YESTERDAY_DATE](./$YESTERDAY_DATE.md)"
    if ! line_exists "$YESTERDAY_NOTE_LINK" "$CURRENT_FILE"; then
        echo -e "\n$YESTERDAY_NOTE_LINK\n" | cat - "$CURRENT_FILE" > temp && mv temp "$CURRENT_FILE"
    fi
fi

# Open Neovim with the specified file
nvim "$CURRENT_FILE"
