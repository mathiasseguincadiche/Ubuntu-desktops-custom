#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${OS_CATALOG_MANIFEST:-$REPO_ROOT/manifests/virtualization/os-catalog.yml}"
STATE_DIR="${OS_CATALOG_STATE_DIR:-$REPO_ROOT/state/kvm}"
OUTPUT="${OS_CATALOG_OUTPUT:-$STATE_DIR/os-catalog.resolved}"

command -v curl >/dev/null 2>&1 || { printf '%s\n' 'curl is required.' >&2; exit 1; }
command -v awk >/dev/null 2>&1 || { printf '%s\n' 'awk is required.' >&2; exit 1; }
[[ -r "$MANIFEST" ]] || { printf 'OS catalog manifest not readable: %s\n' "$MANIFEST" >&2; exit 1; }

mapfile -t filenames < <(awk '$1 == "filename:" {print $2}' "$MANIFEST")
mapfile -t checksum_urls < <(awk '$1 == "checksums:" {print $2}' "$MANIFEST" | sort -u)

((${#filenames[@]} > 0)) || { printf '%s\n' 'No artifact filename found in OS catalog manifest.' >&2; exit 1; }
((${#checksum_urls[@]} > 0)) || { printf '%s\n' 'No checksum source found in OS catalog manifest.' >&2; exit 1; }

mkdir -p "$STATE_DIR"
tmp="$(mktemp "$STATE_DIR/.os-catalog.resolved.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

printf 'schema=1\n' >"$tmp"
printf 'status=verifying\n' >>"$tmp"
printf 'refreshed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$tmp"
printf 'source_manifest=%s\n' "$MANIFEST" >>"$tmp"

for filename in "${filenames[@]}"; do
  found=false
  for url in "${checksum_urls[@]}"; do
    body="$(curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 60 "$url")" || {
      printf 'Unable to fetch official checksum manifest: %s\n' "$url" >&2
      exit 1
    }
    sha="$(printf '%s\n' "$body" | awk -v target="$filename" '
      $1 ~ /^[[:xdigit:]]{64}$/ {
        name=$2
        sub(/^\*/, "", name)
        if (name == target) { print tolower($1); exit }
      }
    ')"
    if [[ "$sha" =~ ^[0-9a-f]{64}$ ]]; then
      printf 'artifact=%s|sha256=%s|checksums=%s\n' "$filename" "$sha" "$url" >>"$tmp"
      found=true
      break
    fi
  done
  if [[ "$found" != true ]]; then
    printf 'Artifact is absent from all configured official checksum manifests: %s\n' "$filename" >&2
    exit 1
  fi
done

# Mark success only after every configured artifact has been resolved from an
# official Canonical SHA256SUMS document. Keep the tracked manifest immutable;
# this runtime file is the current verified view used as operational evidence.
sed -i 's/^status=verifying$/status=verified/' "$tmp"
chmod 0644 "$tmp"
mv -f "$tmp" "$OUTPUT"
trap - EXIT
printf 'OS catalog refreshed and verified: %s\n' "$OUTPUT"
