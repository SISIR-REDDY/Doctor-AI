#!/bin/sh
set -eu

mode="${1:-default}"

APP_ROOT="${PROJECT_DIR}/.."

# Remove duplicate artifacts recursively across the project (for example: "Flutter 2.podspec").
"${APP_ROOT}/scripts/cleanup_duplicate_artifacts.sh" "${APP_ROOT}" || true

if [ "${mode}" = "force-code-assets" ]; then
  rm -rf "${APP_ROOT}/.dart_tool/flutter_build" || true
fi

sanitize_dir() {
  dir_path="$1"
  if [ -d "${dir_path}" ]; then
    xattr -rc "${dir_path}" 2>/dev/null || true
  fi
}

flutter_build_dir="${FLUTTER_BUILD_DIR:-build}"
sanitize_dir "${APP_ROOT}/${flutter_build_dir}"
sanitize_dir "${APP_ROOT}/${flutter_build_dir}/native_assets/ios"
sanitize_dir "${APP_ROOT}/ios/Pods"
sanitize_dir "${APP_ROOT}/ios/Runner"
sanitize_dir "${APP_ROOT}/build/native_assets/ios"
sanitize_dir "${APP_ROOT}/.dart_tool/flutter_build"

for objective_c_pkg in "${HOME}/.pub-cache/hosted/pub.dev"/objective_c-*; do
  if [ -d "${objective_c_pkg}" ]; then
    sanitize_dir "${objective_c_pkg}"
  fi
done

if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${WRAPPER_NAME:-}" ]; then
  sanitize_dir "${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
  sanitize_dir "${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Frameworks"
fi
