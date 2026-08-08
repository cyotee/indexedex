#!/usr/bin/env bash
# Thin wrapper — canonical logic lives under frontend/ (Vercel Root Directory).
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$ROOT/frontend/scripts/vercel-ignore-build.sh" "$@"
