#!/bin/bash

README="README.md"
TMP_README="${README}.tmp"
SCRIPTS_DIR="scripts"

cp "$README" "$TMP_README"

for SCRIPT in "$SCRIPTS_DIR"/*; do
  SCRIPT_NAME=$(basename "$SCRIPT")
  SECTION="$SCRIPT_NAME"
  # Escape backticks in the script content
  SCRIPT_CONTENT=$(sed 's/`/\\`/g' "$SCRIPT")
  SCRIPT_BLOCK="\`\`\`bash
$SCRIPT_CONTENT
\`\`\`"

  # Use awk to replace the section between the markers for this script
  awk -v section="$SECTION" -v new_block="$SCRIPT_BLOCK" '
    BEGIN { in_section=0 }
    {
      if ($0 ~ "<!-- BEGIN " section " -->") {
        print $0
        print new_block
        in_section=1
        next
      }
      if ($0 ~ "<!-- END " section " -->") {
        in_section=0
      }
      if (!in_section) print $0
    }
  ' "$TMP_README" > "${TMP_README}.new" && mv "${TMP_README}.new" "$TMP_README"
done

mv "$TMP_README" "$README"
