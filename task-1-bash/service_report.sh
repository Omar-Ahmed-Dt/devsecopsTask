#!/usr/bin/env bash
set -euo pipefail

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

# Check that inventory file path was provided as first argument
if [[ $# -lt 1 ]]; then
  echo "ERROR: missing inventory file path. Usage: $0 <inventory-file>" >&2
  exit 1
fi

inventory_file="$1"

# Check file exists and is readable
if [[ ! -f "$inventory_file" || ! -r "$inventory_file" ]]; then
  echo "ERROR: file does not exist or is not readable: $inventory_file" >&2
  exit 1
fi

processed=0
reported=0
skipped=0
line_number=0

while IFS= read -r line; do
  ((line_number += 1))

  # Remove left and right whitespace from the full line
  line="$(trim "$line")"

  # Skip header or blank lines
  if [[ "$line_number" -eq 1 ]] || [[ -z "$line" ]]; then
    continue
  fi

  ((processed += 1))

  # Split line by colon
  IFS=':' read -r name env port weight <<< "$line"

  # Trim each field
  name="$(trim "${name:-}")"
  env="$(trim "${env:-}")"
  port="$(trim "${port:-}")"
  weight="$(trim "${weight:-}")"

  # Skip if the environment is not prod or staging
  if [[ "$env" != "prod" && "$env" != "staging" ]]; then
    ((skipped += 1))
    continue
  fi

  # Validate port
  if [[ -z "$port" || ! "$port" =~ ^[0-9]+$ ]]; then
    echo "WARNING: line $line_number skipped: invalid TCP port for service '$name': '${port:-<missing>}'" >&2
    ((skipped += 1))
    continue
  fi

  if (( port < 1 || port > 65535 )); then
    echo "WARNING: line $line_number skipped: invalid TCP port for service '$name': '$port'" >&2
    ((skipped += 1))
    continue
  fi

  # Validate weight
  if [[ -z "$weight" || ! "$weight" =~ ^[0-9]+$ || "$weight" -lt 1 ]]; then
    echo "WARNING: line $line_number skipped: invalid weight for service '$name': '${weight:-<missing>}'" >&2
    ((skipped += 1))
    continue
  fi

  # Check even or odd
  if (( weight % 2 == 0 )); then
    parity="even"
  else
    parity="odd"
  fi

  echo "Service $name on port $port has an $parity weight of $weight."
  ((reported += 1))

done < "$inventory_file"

echo "Summary: processed=$processed reported=$reported skipped=$skipped" >&2
