#!/bin/sh
set -eu

# Removes Finder-style duplicate file/folder names ending with " <number>".
# Example: "AppAuth 2", "Podfile.lock 3".

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <path> [<path> ...]"
  exit 1
fi

cleanup_root() {
  root="$1"

  if [ ! -e "$root" ]; then
    return 0
  fi

  # Delete deepest paths first to avoid parent/child removal ordering issues.
  find "$root" -depth -name '* [0-9]*' -print | while IFS= read -r candidate; do
    name="$(basename "$candidate")"
    if printf '%s\n' "$name" | grep -Eq ' [0-9]+$'; then
      echo "Removing duplicate path: $candidate"
      rm -rf "$candidate"
    fi
  done
}

for root in "$@"; do
  cleanup_root "$root"
done
