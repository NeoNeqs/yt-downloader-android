#!/usr/bin/env fish

set SCRIPT_DIR (cd (dirname (status filename)); and pwd)

if not test -x "$SCRIPT_DIR/setup-native.sh"
    echo "ERROR: setup-native.sh was not found or is not executable."
    echo
    echo "Run:"
    echo "  chmod +x setup-native.sh"
    exit 1
end

exec bash "$SCRIPT_DIR/setup-native.sh" $argv