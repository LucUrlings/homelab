#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
compose_root=${COMPOSE_ROOT:-"$repo_root/docker-compose.main.yaml"}
project_name=${COMPOSE_PROJECT_NAME:-homelab}
env_file=
requested_stack=all
list_only=false

usage() {
  cat <<'EOF'
Usage: scripts/deploy-compose-stacks.sh [options]

Options:
  --list                 Print active stack filenames and exit.
  --stack NAME           Deploy one stack (for example gatus.yaml or gatus).
                         Defaults to all active stacks, in Compose include order.
  --env-file PATH        Pass an environment file to Docker Compose.
  -h, --help             Show this help.
EOF
}

while (($# > 0)); do
  case "$1" in
    --list)
      list_only=true
      shift
      ;;
    --stack)
      (($# >= 2)) || { echo "--stack requires a value" >&2; exit 2; }
      requested_stack=$2
      shift 2
      ;;
    --env-file)
      (($# >= 2)) || { echo "--env-file requires a path" >&2; exit 2; }
      env_file=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -f "$compose_root" ]] || { echo "Compose root not found: $compose_root" >&2; exit 1; }

active_stacks=()
while IFS= read -r stack; do
  [[ -n "$stack" ]] && active_stacks+=("$stack")
done < <(
  sed -nE 's/^[[:space:]]*-[[:space:]]+\$USERDIR\/docker\/homelab\/active\/([^[:space:]#]+\.yaml)[[:space:]]*$/\1/p' "$compose_root"
)

((${#active_stacks[@]} > 0)) || {
  echo "No active Compose includes found in $compose_root" >&2
  exit 1
}

if [[ "$list_only" == true ]]; then
  if [[ "$requested_stack" == all ]]; then
    printf '%s\n' "${active_stacks[@]}"
  else
    requested_stack=${requested_stack##*/}
    [[ "$requested_stack" == *.yaml ]] || requested_stack+='.yaml'
    if [[ ! " ${active_stacks[*]} " == *" $requested_stack "* ]]; then
      echo "Stack is not included by $compose_root: $requested_stack" >&2
      exit 2
    fi
    printf '%s\n' "$requested_stack"
  fi
  exit 0
fi

if [[ "$requested_stack" == all ]]; then
  stacks=("${active_stacks[@]}")
else
  requested_stack=${requested_stack##*/}
  [[ "$requested_stack" == *.yaml ]] || requested_stack+='.yaml'
  stacks=("$requested_stack")
fi

for stack in "${stacks[@]}"; do
  if [[ ! " ${active_stacks[*]} " == *" $stack "* ]]; then
    echo "Stack is not included by $compose_root: $stack" >&2
    echo "Available stacks:" >&2
    printf '  %s\n' "${active_stacks[@]}" >&2
    exit 2
  fi
  [[ -f "$repo_root/active/$stack" ]] || {
    echo "Included Compose file not found: $repo_root/active/$stack" >&2
    exit 1
  }
done

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/homelab-compose.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT

for stack in "${stacks[@]}"; do
  single_compose_file="$temp_dir/$stack"

  # Keep the shared networks and secrets from the root, but include only one
  # active file. The absolute include path keeps Compose resolution independent
  # of the temporary file's location.
  sed '/^include:/,$d' "$compose_root" > "$single_compose_file"
  {
    printf 'include:\n'
    printf '  - %s\n' "$repo_root/active/$stack"
  } >> "$single_compose_file"

  compose=(docker compose --project-name "$project_name")
  [[ -n "$env_file" ]] && compose+=(--env-file "$env_file")
  compose+=(-f "$single_compose_file")

  echo "=== $stack ==="
  "${compose[@]}" config --quiet
  "${compose[@]}" pull
  "${compose[@]}" up -d
done
