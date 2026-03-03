#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="${SCRIPT_DIR}/install-macmonitor-update.sh"

REPO="oscarlehuu/macmonitor"
TAG=""
ASSET_PATTERN="MacMonitor-*.zip"
RELAUNCH=false
TMP_DIR=""

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") [options]

Options:
  --repo <owner/repo>        Private source repository. Default: ${REPO}
  --tag <vX.Y.Z>             Specific release tag. Default: latest release
  --asset-pattern <glob>     Release asset filename pattern. Default: ${ASSET_PATTERN}
  --relaunch                 Relaunch app after install.
  -h, --help                 Show help.

Example:
  $(basename "$0") --repo oscarlehuu/macmonitor --relaunch
USAGE
}

log() { printf '[INFO] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}
trap cleanup EXIT

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        REPO="${2:-}"; shift 2 ;;
      --tag)
        TAG="${2:-}"; shift 2 ;;
      --asset-pattern)
        ASSET_PATTERN="${2:-}"; shift 2 ;;
      --relaunch)
        RELAUNCH=true; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        fail "Unknown argument: $1" ;;
    esac
  done

  [[ -n "${REPO}" ]] || fail "--repo must not be empty"
  [[ -x "${INSTALL_SCRIPT}" ]] || fail "Install helper not found: ${INSTALL_SCRIPT}"
}

resolve_release_asset() {
  local release_json
  if [[ -n "${TAG}" ]]; then
    release_json="$(gh release view "${TAG}" --repo "${REPO}" --json tagName,assets)"
  else
    release_json="$(gh release view --repo "${REPO}" --json tagName,assets)"
  fi

  local selection
  if ! selection="$(RELEASE_JSON="${release_json}" python3 - "${ASSET_PATTERN}" <<'PY'
import fnmatch
import json
import os
import sys

pattern = sys.argv[1]
payload = json.loads(os.environ["RELEASE_JSON"])

tag = payload.get("tagName", "")
assets = payload.get("assets", [])
if not tag:
    sys.exit(1)

for asset in assets:
    name = asset.get("name", "")
    if fnmatch.fnmatch(name, pattern):
        print(f"{tag}\t{name}")
        sys.exit(0)

sys.exit(2)
PY
)"; then
    fail "No asset matching '${ASSET_PATTERN}' was found in ${REPO} release ${TAG:-latest}."
  fi

  local selected_tag selected_asset
  selected_tag="${selection%%$'\t'*}"
  selected_asset="${selection#*$'\t'}"
  [[ -n "${selected_tag}" ]] || fail "Could not resolve release tag from ${REPO}"
  [[ -n "${selected_asset}" ]] || fail "No asset matching '${ASSET_PATTERN}' in release ${selected_tag}"

  printf '%s\n%s\n' "${selected_tag}" "${selected_asset}"
}

main() {
  require_cmd gh
  require_cmd python3

  parse_args "$@"

  gh auth status >/dev/null 2>&1 || fail "Run 'gh auth login' first."

  local release_selection selected_tag selected_asset
  release_selection="$(resolve_release_asset)"
  selected_tag="${release_selection%%$'\n'*}"
  selected_asset="${release_selection#*$'\n'}"

  TMP_DIR="$(mktemp -d)"
  log "Downloading ${selected_asset} from ${REPO} (${selected_tag})"
  gh release download "${selected_tag}" \
    --repo "${REPO}" \
    --pattern "${selected_asset}" \
    --dir "${TMP_DIR}" \
    --clobber

  local artifact_path="${TMP_DIR}/${selected_asset}"
  [[ -f "${artifact_path}" ]] || fail "Downloaded artifact not found: ${artifact_path}"

  local install_args=(--source "${artifact_path}")
  if [[ "${RELAUNCH}" == true ]]; then
    install_args+=(--relaunch)
  fi

  log "Installing ${selected_asset}"
  "${INSTALL_SCRIPT}" "${install_args[@]}"
  log "Installed from ${REPO} release ${selected_tag}"
}

main "$@"
