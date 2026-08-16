#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%s\n' 'ERROR: root privileges required.' >&2; exit 1; }
for cmd in jq install mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: %s is required.\n' "$cmd" >&2; exit 1; }
done

FIREFOX_POLICY='/etc/firefox/policies/policies.json'
BRAVE_POLICY='/etc/brave/policies/managed/20-duckduckgo.json'
DDG_FIREFOX_ID='jid1-ZAdIEUB7XOzOJw@jetpack'
DDG_FIREFOX_XPI='https://addons.mozilla.org/firefox/downloads/latest/duckduckgo-for-firefox/latest.xpi'

install -d -m 0755 /etc/firefox/policies /etc/brave/policies/managed

tmp_firefox="$(mktemp)"
trap 'rm -f -- "$tmp_firefox"' EXIT

if [[ -s "$FIREFOX_POLICY" ]]; then
  jq --arg addon_id "$DDG_FIREFOX_ID" --arg xpi "$DDG_FIREFOX_XPI" '
    .policies = (.policies // {}) |
    .policies.SearchEngines = (.policies.SearchEngines // {}) |
    .policies.SearchEngines.Default = "DuckDuckGo" |
    .policies.ExtensionSettings = (.policies.ExtensionSettings // {}) |
    .policies.ExtensionSettings[$addon_id] = {
      "installation_mode": "normal_installed",
      "install_url": $xpi
    }
  ' "$FIREFOX_POLICY" > "$tmp_firefox"
else
  jq -n --arg addon_id "$DDG_FIREFOX_ID" --arg xpi "$DDG_FIREFOX_XPI" '{
    policies: {
      SearchEngines: {Default: "DuckDuckGo"},
      ExtensionSettings: {
        ($addon_id): {
          installation_mode: "normal_installed",
          install_url: $xpi
        }
      }
    }
  }' > "$tmp_firefox"
fi
install -m 0644 "$tmp_firefox" "$FIREFOX_POLICY"

cat > "$BRAVE_POLICY" <<'EOF'
{
  "DefaultSearchProviderEnabled": true,
  "DefaultSearchProviderName": "DuckDuckGo",
  "DefaultSearchProviderKeyword": "duckduckgo.com",
  "DefaultSearchProviderSearchURL": "https://duckduckgo.com/?q={searchTerms}"
}
EOF
chmod 0644 "$BRAVE_POLICY"

printf '%s\n' 'DuckDuckGo configured as the default search provider in Firefox and Brave.'
printf '%s\n' 'The official DuckDuckGo Search & Tracker Protection Firefox extension will be installed by Firefox policy.'
printf '%s\n' 'No unofficial DuckDuckGo Linux browser package was installed.'
