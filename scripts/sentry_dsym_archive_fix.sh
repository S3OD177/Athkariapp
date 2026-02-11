#!/bin/sh

# Ensures App Store archives include Sentry.framework dSYM, then uploads
# dSYMs to Sentry when sentry-cli is available.

copy_matching_sentry_dsym() {
  SENTRY_FRAMEWORK_BINARY="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/Sentry.framework/Sentry"

  if [ ! -f "$SENTRY_FRAMEWORK_BINARY" ]; then
    return 0
  fi

  FRAMEWORK_UUIDS="$(dwarfdump --uuid "$SENTRY_FRAMEWORK_BINARY" 2>/dev/null | awk '{print toupper($2)}')"
  if [ -z "$FRAMEWORK_UUIDS" ]; then
    echo "warning: Could not read UUIDs from Sentry.framework binary."
    return 0
  fi

  MATCHED_DSYM=""
  for ROOT in "$DERIVED_DATA_DIR" "$BUILD_DIR" "$PROJECT_TEMP_ROOT" "$SOURCE_ROOT"; do
    if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
      continue
    fi

    while IFS= read -r DSYM_DIR; do
      if [ -z "$DSYM_DIR" ]; then
        continue
      fi

      DSYM_BINARY="$DSYM_DIR/Contents/Resources/DWARF/Sentry"
      if [ ! -f "$DSYM_BINARY" ]; then
        continue
      fi

      DSYM_UUIDS="$(dwarfdump --uuid "$DSYM_BINARY" 2>/dev/null | awk '{print toupper($2)}')"
      if [ -z "$DSYM_UUIDS" ]; then
        continue
      fi

      FOUND_UUID_MATCH=0
      for FRAMEWORK_UUID in $FRAMEWORK_UUIDS; do
        if echo "$DSYM_UUIDS" | grep -q "$FRAMEWORK_UUID"; then
          FOUND_UUID_MATCH=1
          break
        fi
      done

      if [ "$FOUND_UUID_MATCH" -eq 1 ]; then
        MATCHED_DSYM="$DSYM_DIR"
        break
      fi
    done <<EOF
$(find "$ROOT" -type d -name "Sentry.framework.dSYM" 2>/dev/null)
EOF

    if [ -n "$MATCHED_DSYM" ]; then
      break
    fi
  done

  if [ -z "$MATCHED_DSYM" ]; then
    echo "warning: Could not locate a matching Sentry.framework.dSYM for UUID(s): $FRAMEWORK_UUIDS"
    return 0
  fi

  mkdir -p "$DWARF_DSYM_FOLDER_PATH"
  rsync -a "$MATCHED_DSYM" "$DWARF_DSYM_FOLDER_PATH/" >/dev/null 2>&1 || {
    echo "warning: Failed to copy Sentry.framework.dSYM from $MATCHED_DSYM"
    return 0
  }

  echo "Included Sentry.framework.dSYM in $DWARF_DSYM_FOLDER_PATH"
}

# Archive/install builds need the framework dSYM present for App Store validation.
if [ "$ACTION" = "install" ] || [ "$ACTION" = "archive" ] || [ "$CONFIGURATION" = "Release" ]; then
  copy_matching_sentry_dsym
fi

# Upload dSYMs to Sentry when sentry-cli is available.
if command -v sentry-cli >/dev/null 2>&1; then
  export SENTRY_ORG=saudlab
  export SENTRY_PROJECT=athkariapp
  ERROR=$(sentry-cli debug-files upload --include-sources "$DWARF_DSYM_FOLDER_PATH" 2>&1 >/dev/null)
  if [ ! $? -eq 0 ]; then
    echo "warning: sentry-cli - $ERROR"
  fi
else
  if [ "$CONFIGURATION" = "Release" ]; then
    echo "warning: sentry-cli not installed, download from https://github.com/getsentry/sentry-cli/releases"
  else
    echo "Sentry dSYM upload skipped in $CONFIGURATION (sentry-cli missing)"
  fi
fi

touch "${DERIVED_FILE_DIR}/sentry-upload-dsym.stamp"
