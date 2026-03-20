#!/bin/bash
set -e

APP_PATH="/Users/yokina/work/girlschan_app/build/macos/Build/Products/Release/girlschan_app.app"
OUT_PATH="/Users/yokina/work/apps-web/public/garunavi/assets/girlschan_setup.zip"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUT_PATH"

echo "Done: $OUT_PATH"
