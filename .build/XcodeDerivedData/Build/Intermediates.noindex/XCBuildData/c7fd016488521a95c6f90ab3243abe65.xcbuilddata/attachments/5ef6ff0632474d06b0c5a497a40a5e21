#!/bin/sh
BUILD_FILE="${SRCROOT}/BuildNumber.txt"
if [ ! -f "$BUILD_FILE" ]; then echo "0" > "$BUILD_FILE"; fi
BUILD=$(cat "$BUILD_FILE")
BUILD=$((BUILD + 1))
printf "%d" "$BUILD" > "$BUILD_FILE"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

