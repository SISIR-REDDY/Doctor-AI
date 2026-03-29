#!/bin/sh
set -eu

# Removes Finder-style duplicate file/folder names ending with " <number>"
# across the project tree (for example: "Pods 2", "Flutter 3.podspec").

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=0

if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

if [ "$#" -eq 0 ]; then
  set -- "$PROJECT_ROOT"
fi

cleanup_root() {
  root="$1"

  if [ ! -e "$root" ]; then
    return 0
  fi

  find "$root" -depth -name '* [0-9]*' | while IFS= read -r candidate; do
    base_name="$(basename "$candidate")"

    # Match Finder duplicate naming patterns:
    # - "name 2"
    # - "name 2.ext"
    if ! printf '%s\n' "$base_name" | grep -Eq ' [0-9]+(\..+)?$'; then
      continue
    fi

    # Never touch repository metadata.
    case "$candidate" in
      */.git|*/.git/*)
        continue
        ;;
    esac

    if [ "$DRY_RUN" -eq 1 ]; then
      echo "Would remove: $candidate"
    else
      echo "Removing: $candidate"
      rm -rf "$candidate"
    fi
  done
}

for root in "$@"; do
  case "$root" in
    /*) target="$root" ;;
    *) target="$PROJECT_ROOT/$root" ;;
  esac
  cleanup_root "$target"
done
