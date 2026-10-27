#!/usr/bin/env bash
# Run a CI command and make concise failure details visible in check annotations.
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

# GitHub truncates individual annotation messages, so emit short, independent
# excerpts and prioritize the lines that identify the failing test.
test_failures = [i for i, line in enumerate(lines) if '[E]' in line]
markers = ('EXCEPTION CAUGHT', 'Error:', 'error:', 'FAILURE:',
           'What went wrong:', 'BUILD FAILED', 'Some tests failed')
other_errors = [i for i, line in enumerate(lines)
                if any(marker in line for marker in markers)]
indices = test_failures + other_errors
if not indices:
    indices = [max(0, len(lines) - 30)]

seen = set()
for i in indices:
    # Keep only the useful beginning of an error; long render-object dumps can
    # otherwise hide other failures behind GitHub's annotation size limit.
    snippet = '\n'.join(lines[max(0, i - 1):min(len(lines), i + 15)])
    snippet = snippet.encode('utf-8')[:3000].decode('utf-8', errors='ignore')
    if snippet in seen:
        continue
    seen.add(snippet)
    escaped = snippet.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print('::error title=Diagnostic CI::' + escaped)
    if len(seen) == 35:
        break
PY
fi
rm -f "$log_file"
exit "$status"
