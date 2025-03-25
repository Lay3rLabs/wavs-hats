#!/bin/bash

# Path to the environment file
ENV_FILE=".env"
BACKUP_FILE=".env.bak"
SECTION_MARKER="# Hats Protocol AVS Integration Addresses"

# Create a backup
cp "$ENV_FILE" "$BACKUP_FILE"
echo "Created backup of .env file at $BACKUP_FILE"

# Check if the marker exists
if grep -q "$SECTION_MARKER" "$ENV_FILE"; then
  echo "Found duplicate Hats Protocol AVS sections, cleaning up..."
  
  # Create a temp file
  TEMP_FILE=$(mktemp)
  
  # Remove lines between the marker and the next section/blank line
  # This is a simplified approach - it keeps the first section and removes others
  FOUND=0
  while IFS= read -r line; do
    if [[ "$line" == "$SECTION_MARKER" ]]; then
      if [[ $FOUND -eq 0 ]]; then
        # First occurrence of the marker - keep it
        echo "$line" >> "$TEMP_FILE"
        FOUND=1
      else
        # Subsequent occurrences - skip this and following lines until blank line or next section
        SKIP=1
      fi
    elif [[ -z "$line" || "$line" == \#* ]]; then
      # Empty line or new section - stop skipping
      SKIP=0
      echo "$line" >> "$TEMP_FILE"
    elif [[ $SKIP -eq 0 ]]; then
      # Regular line and not skipping
      echo "$line" >> "$TEMP_FILE"
    fi
  done < "$ENV_FILE"
  
  # Copy back to the original
  cp "$TEMP_FILE" "$ENV_FILE"
  rm "$TEMP_FILE"
  echo "Duplicate sections removed"
else
  echo "No duplicate sections found"
fi

echo "Environment file cleanup complete"
