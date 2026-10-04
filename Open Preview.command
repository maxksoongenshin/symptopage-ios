#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -d '../SymptoPage-iOS-Preview.app' ]; then
  bash scripts/build_preview.sh
fi
open '../SymptoPage-iOS-Preview.app'
