#!/bin/bash

LOG_FILE="$(dirname "$0")/setup.log"

# Log function
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

EXTENSIONS_DIR="$(dirname "$0")/extensions"

# Check if the extensions directory exists and is not empty
if [[ -d "$EXTENSIONS_DIR" && $(ls -A "$EXTENSIONS_DIR") ]]; then
    log "Running additional setup scripts from $EXTENSIONS_DIR..."
    for script in "$EXTENSIONS_DIR"/*; do
        if [[ -x "$script" ]]; then
            log "Running script: $script"
            bash "$script" | tee -a "$LOG_FILE"
        else
            log "Skipping non-executable script: $script"
        fi
    done
else
    log "No additional setup scripts found in $EXTENSIONS_DIR. Skipping additional setup."
fi
