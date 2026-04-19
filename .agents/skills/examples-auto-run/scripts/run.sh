#!/bin/bash
# examples-auto-run skill script
# Automatically discovers and runs example scripts, reporting pass/fail status

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EXAMPLES_DIR="${REPO_ROOT}/examples"
RESULTS_FILE="${REPO_ROOT}/.agents/skills/examples-auto-run/results.json"
TIMEOUT=${EXAMPLES_TIMEOUT:-30}
PYTHON=${PYTHON_BIN:-python}

passed=0
failed=0
skipped=0
results=[]

log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }

check_prerequisites() {
  if ! command -v "$PYTHON" &>/dev/null; then
    log_error "Python interpreter not found: $PYTHON"
    exit 1
  fi
  if [ ! -d "$EXAMPLES_DIR" ]; then
    log_error "Examples directory not found: $EXAMPLES_DIR"
    exit 1
  fi
}

should_skip() {
  local file="$1"
  # Skip files that declare they need real API keys or special setup
  if grep -qE '^\s*#\s*SKIP_AUTO_RUN' "$file" 2>/dev/null; then
    return 0
  fi
  # Skip files that import modules not available in CI
  if grep -qE 'import (anthropic|boto3|google\.cloud)' "$file" 2>/dev/null; then
    return 0
  fi
  return 1
}

run_example() {
  local file="$1"
  local rel_path="${file#$REPO_ROOT/}"
  local status="pass"
  local output
  local exit_code=0

  if should_skip "$file"; then
    log_warn "SKIP  $rel_path"
    ((skipped++)) || true
    echo "{\"file\": \"$rel_path\", \"status\": \"skipped\"}" >> "$RESULTS_FILE.tmp"
    return
  fi

  log_info "RUN   $rel_path"
  set +e
  output=$(cd "$REPO_ROOT" && timeout "$TIMEOUT" "$PYTHON" "$file" 2>&1)
  exit_code=$?
  set -e

  if [ $exit_code -eq 124 ]; then
    status="timeout"
    log_warn "TIMEOUT $rel_path (>${TIMEOUT}s)"
    ((failed++)) || true
  elif [ $exit_code -ne 0 ]; then
    status="fail"
    log_error "FAIL  $rel_path (exit $exit_code)"
    log_error "      $(echo "$output" | tail -3)"
    ((failed++)) || true
  else
    log_info "PASS  $rel_path"
    ((passed++)) || true
  fi

  # Escape output for JSON
  local escaped_output
  escaped_output=$(echo "$output" | tail -5 | python3 -c \
    "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"\"")

  echo "{\"file\": \"$rel_path\", \"status\": \"$status\", \"exit_code\": $exit_code, \"output_tail\": $escaped_output}" \
    >> "$RESULTS_FILE.tmp"
}

write_summary() {
  local total=$((passed + failed + skipped))
  log_info "-----------------------------------"
  log_info "Results: $passed passed, $failed failed, $skipped skipped / $total total"

  # Assemble JSON results file
  echo "{" > "$RESULTS_FILE"
  echo "  \"summary\": {\"passed\": $passed, \"failed\": $failed, \"skipped\": $skipped, \"total\": $total}," >> "$RESULTS_FILE"
  echo "  \"examples\": [" >> "$RESULTS_FILE"
  if [ -f "$RESULTS_FILE.tmp" ]; then
    paste -sd',' "$RESULTS_FILE.tmp" | sed 's/,$//' >> "$RESULTS_FILE"
    rm "$RESULTS_FILE.tmp"
  fi
  echo "  ]" >> "$RESULTS_FILE"
  echo "}" >> "$RESULTS_FILE"

  log_info "Results written to $RESULTS_FILE"
}

main() {
  check_prerequisites

  rm -f "$RESULTS_FILE" "$RESULTS_FILE.tmp"
  mkdir -p "$(dirname "$RESULTS_FILE")"

  log_info "Discovering examples in $EXAMPLES_DIR ..."

  while IFS= read -r -d '' example_file; do
    run_example "$example_file"
  done < <(find "$EXAMPLES_DIR" -name '*.py' -not -path '*/.*' -print0 | sort -z)

  write_summary

  if [ "$failed" -gt 0 ]; then
    log_error "$failed example(s) failed."
    exit 1
  fi
}

main "$@"
