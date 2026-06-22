#!/bin/sh

set -euo pipefail

# Check that inventory file path was provided as first argument
if [[ $# -lt 1 ]]; then
  echo "ERROR: missing inventory file path. Usage: $0 <inventory-file>"
  exit 1
fi

inventory_file="$1"

# Check file exists
if [[ ! -e "$inventory_file" ]]; then
  echo "inventory file does not exist: $inventory_file"
  exit 1
fi

# Check it is a file && readable
if [[ ! -f "$inventory_file" || ! -r "$inventory_file" ]]; then 
  echo "ERROR: file does not exist or is not readable: $inventory_file"
  exit 1
fi

processed=0
reported=0
skipped=0
line_number=0

while read -r line; do
    ((line_number += 1))

  # skip header && blank lines
  if [[ "$line_number" -eq 1 ]] || [[ -z "$line" ]]; then
    continue
  fi

  ((processed += 1))

  IFS=':' read -r name env port weight <<< "$line"

  # skip if the env is not prod or staging
  if [[ "$env" != "prod" && "$env" != "staging" ]]; then
      ((skipped += 1))
    continue
  fi

  # validate port
  if [[ -z "${port:-}" || ! "$port" =~ ^[0-9]+$ || "$port" -lt 1 || "$port" -gt 65535 ]]; then
    echo "WARNING: line $line_number skipped: invalid TCP port for service '$name': '${port:-<missing>}'"
    skipped=$((skipped + 1))
    continue
  fi

  # validate weight
  if [[ -z "${weight:-}" || ! "$weight" =~ ^[0-9]+$ || "$weight" -lt 1 ]]; then
    echo "WARNING: line $line_number skipped: invalid weight for service '$name': '${weight:-<missing>}'"
    skipped=$((skipped + 1))
    continue
  fi

  if (( weight % 2 == 0 )); then
    parity="even"
  else
    parity="odd"
  fi

  echo "Service $name on port $port has an $parity weight of $weight."
  reported=$((reported + 1))

done < "$inventory_file"

echo "Summary: processed=$processed reported=$reported skipped=$skipped" >&2
