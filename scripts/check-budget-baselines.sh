#!/usr/bin/env bash
# check-budget-baselines.sh
#
# Flags any entry in budget-baselines.toml whose cpu or memory value is
# suspiciously low (below SANITY_FLOOR), which almost certainly means it
# is still a placeholder left over from when the entry was first added.
#
# A placeholder like "cpu = 1, memory = 1" will cause the
# assert_budget_within_threshold regression check to trivially pass
# against any real measurement, masking actual regressions.
#
# Exit codes:
#   0 — all entries look reasonable (or HARD_FAIL is not set and some
#       entries are below the floor but we warn instead of failing)
#   1 — one or more entries are below SANITY_FLOOR and HARD_FAIL=1

set -euo pipefail

BASELINES_FILE="${1:-budget-baselines.toml}"
SANITY_FLOOR="${SANITY_FLOOR:-100}"
HARD_FAIL="${HARD_FAIL:-1}"

if [ ! -f "$BASELINES_FILE" ]; then
  echo "ERROR: $BASELINES_FILE not found"
  exit 1
fi

echo "Checking $BASELINES_FILE for placeholder entries (sanity floor: $SANITY_FLOOR)..."
echo ""

PLACEHOLDERS=()
current_section=""

while IFS= read -r line; do
  # Match section headers like [allowlist-token.transfer]
  if [[ "$line" =~ ^\[(.+)\]$ ]]; then
    current_section="${BASH_REMATCH[1]}"
  fi

  # Match "cpu = <n>" or "memory = <n>"
  if [[ "$line" =~ ^(cpu|memory)[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    if [ "$value" -lt "$SANITY_FLOOR" ]; then
      PLACEHOLDERS+=("[$current_section] $key = $value (below floor of $SANITY_FLOOR)")
      echo "⚠  [$current_section] $key = $value — looks like a placeholder (floor: $SANITY_FLOOR)"
    else
      echo "✓  [$current_section] $key = $value"
    fi
  fi
done < "$BASELINES_FILE"

echo ""

if [ "${#PLACEHOLDERS[@]}" -gt 0 ]; then
  echo "Found ${#PLACEHOLDERS[@]} likely-placeholder value(s) in $BASELINES_FILE:"
  for entry in "${PLACEHOLDERS[@]}"; do
    echo "  • $entry"
  done
  echo ""
  echo "These entries need real measurements before the budget regression"
  echo "check (assert_budget_within_threshold) will be meaningful."
  echo "Run the benchmark script and update budget-baselines.toml with"
  echo "actual cpu/memory instruction counts."

  if [ "$HARD_FAIL" = "1" ]; then
    exit 1
  fi
fi

exit 0
