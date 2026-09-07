#!/bin/zsh
# The constitution's verification command (CLAUDE.md, "Verification").
#
# Builds the app and runs the tests on the simulator, then prints a short
# summary instead of the raw log: compile errors, test failures, the
# count lines, and the last 40 non-CloudKit lines. Every verification —
# implementer, reviewer, orchestrator — goes through this and nothing
# more verbose.
#
#   scripts/verify.sh            # build + the unit suite (TroveTests)
#   scripts/verify.sh ui         # build + the UI suite (TroveUITests)
#   scripts/verify.sh all        # build + both
#   scripts/verify.sh -only-testing:TroveTests/SuiteStructName   # one suite
#
# Suite-level selectors only: a per-function `-only-testing:` selector
# matches zero tests and still reports success.

set -o pipefail

DESTINATION='platform=iOS Simulator,id=FE0861F8-C0B3-4DD1-83BC-F52AF5C5110C'
case "${1:-unit}" in
  unit) SELECTOR=(-only-testing:TroveTests) ;;
  ui)   SELECTOR=(-only-testing:TroveUITests) ;;
  all)  SELECTOR=() ;;
  -only-testing:*) SELECTOR=("$1") ;;   # one suite, for a mutation check
  *)    echo "usage: scripts/verify.sh [unit|ui|all|-only-testing:<target>/<suite>]" >&2; exit 2 ;;
esac

LOG="$(mktemp -t trove-verify)"
xcodebuild test -scheme Trove -destination "$DESTINATION" "${SELECTOR[@]}" > "$LOG" 2>&1
STATUS=$?

echo "## errors"
grep -E '\.swift:[0-9]+:[0-9]+: error:|^error:|xcodebuild: error:|\*\* BUILD FAILED \*\*' "$LOG" | sort -u | head -n 20
echo "## failures"
grep '✘' "$LOG" | sed 's/^[[:space:]\xe2\x80\x8b]*//' | sort -u | head -n 20
echo "## counts"
grep -E 'Test run with [0-9]+ tests|Executed [1-9][0-9]* tests?|\*\* (TEST|BUILD) (SUCCEEDED|FAILED) \*\*' "$LOG" | sort -u
echo "## tail"
grep -vE '◇ |✔ Test |CloudKit|NSURLError|LocalDataTask|^\), _NSURL|IDETestOperationsObserverDebug|Recovery encountered|^[[:space:]]*$' "$LOG" | tail -n 40
if ! grep -qE 'Test run with [1-9][0-9]* tests|Executed [1-9][0-9]* tests?' "$LOG"; then
  echo "## NO TEST COUNT — zero tests ran (bad selector?); treating as failure"
  STATUS=1
fi
echo "## exit=$STATUS (log: $LOG)"
exit $STATUS
