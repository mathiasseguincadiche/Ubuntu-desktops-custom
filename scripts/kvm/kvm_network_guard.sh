#!/usr/bin/env bash
set -Eeuo pipefail

TABLE_FAMILY='inet'
TABLE_NAME='ubuntu_desktops_custom_kvm'
BRIDGE_NAME="${KVM_BRIDGE_NAME:-virbr50}"
KVM_CIDR="${KVM_NETWORK_CIDR:-192.168.50.0/24}"

remove_table() {
  if nft list table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1; then
    nft delete table "$TABLE_FAMILY" "$TABLE_NAME"
  fi
}

validate_cidrs() {
  python3 - "$@" <<'PY'
import ipaddress
import sys
for item in sys.argv[1:]:
    network = ipaddress.ip_network(item, strict=False)
    if network.version != 4:
        raise SystemExit(1)
PY
}

discover_local_ipv4() {
  ip -4 route show scope link | awk '{print $1}' | while read -r prefix; do
    [[ "$prefix" == */* ]] || continue
    [[ "$prefix" == "$KVM_CIDR" ]] && continue
    [[ "$prefix" == 127.0.0.0/8 ]] && continue
    printf '%s\n' "$prefix"
  done | sort -u
}

apply_guard() {
  command -v nft >/dev/null 2>&1
  command -v ip >/dev/null 2>&1
  command -v python3 >/dev/null 2>&1

  mapfile -t local_cidrs < <(discover_local_ipv4)
  (( ${#local_cidrs[@]} > 0 )) || {
    printf '%s\n' 'ERROR: no host-connected local IPv4 networks discovered; fail-closed.' >&2
    exit 10
  }
  validate_cidrs "$KVM_CIDR" "${local_cidrs[@]}"

  python3 - "$KVM_CIDR" "${local_cidrs[@]}" <<'PY'
import ipaddress
import sys
kvm = ipaddress.ip_network(sys.argv[1], strict=False)
for value in sys.argv[2:]:
    network = ipaddress.ip_network(value, strict=False)
    if kvm.overlaps(network):
        print(f'ERROR: KVM subnet overlaps connected network {network}', file=sys.stderr)
        raise SystemExit(10)
PY

  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  if nft list table "$TABLE_FAMILY" "$TABLE_NAME" >/dev/null 2>&1; then
    printf 'delete table %s %s\n' "$TABLE_FAMILY" "$TABLE_NAME" >> "$tmp"
  fi

  {
    printf 'table inet %s {\n' "$TABLE_NAME"
    printf '  set blocked_local_ipv4 {\n'
    printf '    type ipv4_addr\n'
    printf '    flags interval\n'
    printf '    elements = { '
    local first=true cidr
    for cidr in "${local_cidrs[@]}"; do
      if [[ "$first" == true ]]; then first=false; else printf ', '; fi
      printf '%s' "$cidr"
    done
    printf ' }\n'
    printf '  }\n'
    printf '  chain forward_guard {\n'
    printf '    type filter hook forward priority -50; policy accept;\n'
    printf '    iifname "%s" ip daddr @blocked_local_ipv4 drop comment "ubuntu-desktops-custom VM to host-local networks block"\n' "$BRIDGE_NAME"
    printf '    oifname "%s" ip saddr @blocked_local_ipv4 drop comment "ubuntu-desktops-custom host-local networks to VM block"\n' "$BRIDGE_NAME"
    printf '  }\n'
    printf '}\n'
  } >> "$tmp"

  nft -c -f "$tmp"
  nft -f "$tmp"
}

case "${1:-apply}" in
  apply|reload) apply_guard ;;
  remove) remove_table ;;
  *) printf 'Usage: %s [apply|reload|remove]\n' "$0" >&2; exit 2 ;;
esac
