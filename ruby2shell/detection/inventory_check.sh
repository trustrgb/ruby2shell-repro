#!/usr/bin/env bash
# Version-based inventory for GHSA-34m4-m9fh-gqp5. Requires Bash 4+.
# Does not attest vendor backports or running interpreter images.
set -euo pipefail

classify_version() {
    local version="$1" major minor patch
    # Prereleases and unknown formats remain unknown.
    if [[ ! "$version" =~ ^([0-9]{1,6})\.([0-9]{1,6})\.([0-9]{1,6})(p[0-9]+)?$ ]]; then
        printf '%s\n' UNKNOWN
        return 0
    fi
    major=$((10#${BASH_REMATCH[1]}))
    minor=$((10#${BASH_REMATCH[2]}))
    patch=$((10#${BASH_REMATCH[3]}))
    if (( major == 2 || (major == 3 && minor < 3) )); then
        printf '%s\n' AFFECTED_BY_VERSION
    elif (( major == 3 && minor == 3 )); then
        if (( patch < 14 )); then printf '%s\n' AFFECTED_BY_VERSION
        else printf '%s\n' FIXED_BY_VERSION; fi
    elif (( major == 3 && minor == 4 )); then
        if (( patch < 13 )); then printf '%s\n' AFFECTED_BY_VERSION
        else printf '%s\n' FIXED_BY_VERSION; fi
    elif (( major == 4 && minor == 0 )); then
        if (( patch < 10 )); then printf '%s\n' AFFECTED_BY_VERSION
        else printf '%s\n' FIXED_BY_VERSION; fi
    else
        # Do not extrapolate patch status to unreviewed branches.
        printf '%s\n' UNKNOWN
    fi
}

usage() {
    cat <<'USAGE'
Usage: bash detection/inventory_check.sh
       bash detection/inventory_check.sh --binary PATH [PATH ...]
       bash detection/inventory_check.sh --version VERSION [VERSION ...]

No arguments: Linux process observations plus selected bundled/PATH executables.
--binary: execute only specified trusted MRI binaries with -v (5s timeout).
--version: classify version tokens without executing binaries or scanning the host.

Exit codes: 0 = all checked version tokens meet known branch thresholds;
            1 = at least one AFFECTED_BY_VERSION result;
            2 = unknown, failed, empty, or unverified process results;
           64 = invalid invocation.
Version labels do not account for vendor backports or prove process remediation.
USAGE
}

record_status() {
    case "$1" in
        AFFECTED_BY_VERSION) affected_count=$((affected_count + 1)) ;;
        FIXED_BY_VERSION) fixed_count=$((fixed_count + 1)) ;;
        *) unknown_count=$((unknown_count + 1)) ;;
    esac
}

check_binary() {
    local candidate="$1" source="$2" resolved output version status
    resolved=$(readlink -f -- "$candidate" 2>/dev/null) || resolved="$candidate"
    if [[ -n "${seen_binaries[$resolved]+present}" ]]; then return 0; fi
    seen_binaries["$resolved"]=1
    if [[ ! -f "$candidate" || ! -x "$candidate" ]]; then
        printf '%s\t%s\tUNKNOWN (not executable)\n' "$source" "$candidate"
        record_status UNKNOWN
        return 0
    fi
    if ! command -v timeout >/dev/null 2>&1; then
        printf '%s\t%s\tUNKNOWN (timeout utility required)\n' "$source" "$candidate"
        record_status UNKNOWN
        return 0
    fi
    if ! output=$(timeout -k 1s 5s "$candidate" -v 2>/dev/null); then
        printf '%s\t%s\tUNKNOWN (version query failed or timed out)\n' "$source" "$candidate"
        record_status UNKNOWN
        return 0
    fi
    if [[ "$output" =~ ^ruby[[:space:]]+([^[:space:]]+) ]]; then
        version="${BASH_REMATCH[1]}"
        status=$(classify_version "$version")
    else
        version=unrecognized
        status=UNKNOWN
    fi
    printf '%s\t%s\t%s\t%s\n' "$source" "$candidate" "$version" "$status"
    record_status "$status"
}

observe_processes() {
    local proc_dir="$1" pid_dir exe_path exe_name
    if [[ ! -d "$proc_dir" ]]; then
        printf 'PROCESS\tUNKNOWN (proc filesystem unavailable)\n'
        record_status UNKNOWN
        return 0
    fi
    for pid_dir in "$proc_dir"/[0-9]*; do
        [[ -d "$pid_dir" ]] || continue
        exe_path=$(readlink -- "$pid_dir/exe" 2>/dev/null) || continue
        exe_name="${exe_path##*/}"
        if [[ "$exe_name" == ruby* ]]; then
            # Never execute /proc/PID/exe or a path resolved from it. The loaded
            # image may differ from the file now installed at that path.
            printf 'PROCESS(%s)\t%s\tUNVERIFIED_PROCESS\n' "${pid_dir##*/}" "$exe_path"
            record_status UNVERIFIED_PROCESS
        fi
    done
}

main() {
    local mode=scan version candidate runtime_on_path status
    local affected_count=0 fixed_count=0 unknown_count=0
    local -A seen_binaries=()
    if (( $# > 0 )); then
        case "$1" in
            --help|-h) usage; return 0 ;;
            --version) mode=version; shift ;;
            --binary) mode=binary; shift ;;
            *) usage >&2; return 64 ;;
        esac
        if (( $# == 0 )); then usage >&2; return 64; fi
    fi
    printf 'Ruby inventory: GHSA-34m4-m9fh-gqp5\n'
    if [[ "$mode" == version ]]; then
        for version in "$@"; do
            status=$(classify_version "$version")
            printf 'VERSION\t%s\t%s\n' "$version" "$status"
            record_status "$status"
        done
    elif [[ "$mode" == binary ]]; then
        for candidate in "$@"; do check_binary "$candidate" EXPLICIT; done
    else
        if [[ "$(uname -s)" != Linux ]]; then
            printf 'UNKNOWN: automatic inventory requires Linux.\n' >&2
            return 2
        fi
        printf 'Process observations are partial; unreadable or renamed images may be missed.\n'
        observe_processes /proc
        shopt -s nullglob
        for candidate in /opt/gitlab/embedded/bin/ruby /opt/github/embedded/bin/ruby \
            /opt/mastodon/.rbenv/shims/ruby /usr/local/bin/ruby /usr/bin/ruby \
            /home/*/.*env/shims/ruby; do
            if [[ -e "$candidate" ]]; then check_binary "$candidate" BUNDLED; fi
        done
        runtime_on_path=$(type -P ruby) || runtime_on_path=''
        if [[ -n "$runtime_on_path" ]]; then check_binary "$runtime_on_path" PATH; fi
    fi
    printf 'Summary: affected_by_version=%s fixed_by_version=%s unknown_or_unverified=%s\n' \
        "$affected_count" "$fixed_count" "$unknown_count"
    printf 'Version-only assessment: verify package provenance, backports and running workers separately.\n'
    if (( affected_count > 0 )); then return 1; fi
    if (( unknown_count > 0 || fixed_count == 0 )); then return 2; fi
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
