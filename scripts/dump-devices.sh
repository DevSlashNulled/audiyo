#!/usr/bin/env bash
set -euo pipefail

system_profiler SPAudioDataType

echo
echo "Audiyo logs:"
log show --style compact --last 5m --predicate 'subsystem == "ca.5350.audiyo"'
