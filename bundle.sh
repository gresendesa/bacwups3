#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
OUTPUT_FILE="$DIST_DIR/bacwaps3.bundle.sh"

mkdir -p "$DIST_DIR"

{
    echo "#!/bin/bash"
    echo
    echo "# =========================================="
    echo "# bAcWapS3 - Bundle único gerado automaticamente"
    echo "# =========================================="
    echo

    awk '!/^#!/' "$ROOT_DIR/lib_core.sh"
    echo
    awk '!/^#!/' "$ROOT_DIR/lib_ui.sh"
    echo
    awk '!/^#!/ && !/^source "\$DIR\/lib_core\.sh"/ && !/^source "\$DIR\/lib_ui\.sh"/' "$ROOT_DIR/bacwaps3.sh"
} > "$OUTPUT_FILE"

chmod +x "$OUTPUT_FILE"

echo "Bundle gerado em: $OUTPUT_FILE"
