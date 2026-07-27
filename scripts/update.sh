#!/usr/bin/env bash
set -euo pipefail

base_url="https://dl.polytoken.dev"
repo_root="${POLYTOKEN_FLAKE_ROOT:-$PWD}"
release_file="$repo_root/release.json"
artifact_path="linux-amd64/polytoken"
system="x86_64-linux"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "missing required tool '$1'"
}

fetch() {
    local url="$1"
    local output="$2"

    curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --proto '=https' \
        --proto-redir '=https' \
        --tlsv1.2 \
        --retry 3 \
        --retry-delay 1 \
        --output "$output" \
        "$url"
}

for tool in awk curl jq mktemp mv nix; do
    require_tool "$tool"
done

[[ -f "$repo_root/flake.nix" ]] || fail "run from the flake repository root"
[[ -f "$release_file" ]] || fail "missing $release_file"

channel="$(jq -er '.channel | select(. == "latest" or . == "stable")' "$release_file")"
current_version="$(jq -er '.version | select(type == "string")' "$release_file")"
[[ "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "release.json contains an invalid version: $current_version"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

channels_file="$tmp_dir/channels.json"
fetch "$base_url/channels.json" "$channels_file"

jq -e '
    .schema == 1
    and .product == "polytoken"
    and (.channels | type == "object")
' "$channels_file" >/dev/null \
    || fail "channels.json has an unexpected schema or product"

upstream_version="$(
    jq -er --arg channel "$channel" '
        .channels[$channel] | select(type == "string")
    ' "$channels_file"
)"
[[ "$upstream_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "channels.json contains an invalid $channel version: $upstream_version"

if [[ "$upstream_version" == "$current_version" ]]; then
    printf 'Polytoken %s is already current on the %s channel.\n' \
        "$current_version" "$channel"
    exit 0
fi

jq -e -n \
    --arg current "$current_version" \
    --arg upstream "$upstream_version" '
        def parts: split(".") | map(tonumber);
        ($upstream | parts) > ($current | parts)
    ' >/dev/null \
    || fail "refusing to downgrade Polytoken from $current_version to $upstream_version"

checksums_file="$tmp_dir/SHA256SUMS.linux"
fetch "$base_url/$upstream_version/SHA256SUMS.linux" "$checksums_file"

expected_hex="$(
    awk -v artifact="$artifact_path" \
        '$2 == artifact { print $1 }' \
        "$checksums_file"
)"
[[ "$expected_hex" =~ ^[0-9a-f]{64}$ ]] \
    || fail "checksum manifest has no valid SHA-256 for $artifact_path"

artifact_url="$base_url/$upstream_version/$artifact_path"
prefetch_json="$(nix store prefetch-file --json "$artifact_url")"
actual_sri="$(jq -er '.hash | select(type == "string")' <<<"$prefetch_json")"
expected_sri="$(
    nix hash convert --hash-algo sha256 --to sri "$expected_hex"
)"

[[ "$actual_sri" == "$expected_sri" ]] \
    || fail "downloaded artifact does not match the published SHA-256"

next_release="$tmp_dir/release.json"
jq -n \
    --arg channel "$channel" \
    --arg version "$upstream_version" \
    --arg system "$system" \
    --arg path "$artifact_path" \
    --arg hash "$actual_sri" '
        {
            channel: $channel,
            version: $version,
            platforms: {
                ($system): {
                    path: $path,
                    hash: $hash
                }
            }
        }
    ' >"$next_release"

mv "$next_release" "$release_file"
printf 'Updated Polytoken from %s to %s.\n' \
    "$current_version" "$upstream_version"
