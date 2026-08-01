#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
exec sh "$ROOT_DIR/.agents/skills/orchestrating-herdr-workers/tests/herdr-worker.sh" "$@"
