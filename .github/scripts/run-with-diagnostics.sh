#!/usr/bin/env bash
# Run a CI command and make failure details visible in GitHub check annotations.
set +e
log_file="${RUNNER_TEMP:-/tmp}/planning-ci-${RANDOM}.log"
"$@" > "$log_file" 2>&1
status=$?
cat "$log_file"

if [ "$status" -ne 0 ]; then
  python3 - "$log_file" <<'PY'
import sys

with open(sys.argv[1], encoding='utf-8', errors='replace') as log:
    lines = log.read().splitlines()

markers = ('[E]', 'EXCEPTION', 'Error:', 'error:', 'Expected:',
           'Actual:', 'FAILURE:', 'What went wrong:', 'BUILD FAILED',
           'Some tests failed')
ranges = []
for i, line in enumerate(lines):
    if any(marker in line for marker in markers):
        start, end = max(0, i - 3), min(len(lines), i + 22)
        if ranges and start <= ranges[-1][1]:
            ranges[-1] = (ranges[-1][0], max(end, ranges[-1][1]))
        else:
            ranges.append((start, end))
if not ranges:
    ranges = [(max(0, len(lines) - 100), len(lines))]
message = '\n\n'.join('\n'.join(lines[start:end]) for start, end in ranges)
if len(message) > 48000:
    message = message[:32000] + '\n…\n' + message[-15000:]
message = message.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
print('::error title=Détails de la commande en échec::' + message)
PY
fi
rm -f "$log_file"
exit "$status"
