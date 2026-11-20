#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
script=detection/inventory_check.sh
source "$script"
test_count=0
test_dir=$(mktemp -d "$PWD/tests/.inventory.XXXXXX")
# Verify the absolute cleanup target remains within this suite's workspace.
case "$test_dir" in
    "$PWD/tests/.inventory."*) ;;
    *) printf 'Unexpected test directory: %s\n' "$test_dir" >&2; exit 1 ;;
esac
trap 'rm -rf -- "$test_dir"' EXIT

expect_status() {
    local expected="$1" actual
    shift
    if bash "$script" "$@" > "$test_dir/output" 2>&1; then actual=0
    else actual=$?; fi
    if [[ "$actual" != "$expected" ]]; then
        cat "$test_dir/output"
        printf 'Expected status %s, got %s: %s\n' "$expected" "$actual" "$*" >&2
        exit 1
    fi
    test_count=$((test_count + 1))
}

# Boundary releases, later patch levels and the former prefix-matching bug.
for version in 2.4.0 2.7.8 3.0.7 3.2.9 3.3.0 3.3.13 3.4.0 3.4.12 4.0.0 4.0.9; do
    expect_status 1 --version "$version"
    grep -q $'\tAFFECTED_BY_VERSION$' "$test_dir/output"
done
for version in 3.3.14 3.3.15 3.3.100 3.4.13 3.4.14 3.4.100 4.0.10 4.0.11 4.0.100 3.4.13p0; do
    expect_status 0 --version "$version"
    grep -q $'\tFIXED_BY_VERSION$' "$test_dir/output"
done
for version in '' garbage 3.4 3.4.13-rc1 3.4.13preview1 3.4.13dev 3.4.13vendor 3.4.130foo 4.1.0 5.0.0 1.9.3 '3.4.13;exit 0' 999999999.4.13; do
    expect_status 2 --version "$version"
    grep -q $'\tUNKNOWN$' "$test_dir/output"
done
expect_status 1 --version 3.4.13 3.4.12 UNKNOWN
expect_status 2 --version 3.4.13 UNKNOWN
expect_status 64 --version
expect_status 64 --binary
expect_status 64 --invalid
expect_status 0 --help
expect_status 2 --binary "$test_dir/nonexistent"

# Real executable-query path, spaces in paths, deduplication, and query failure.
mkdir -p "$test_dir/with spaces"
printf '#!/usr/bin/env bash\nprintf "ruby 3.4.100 (fixture) [test]\\n"\n' > "$test_dir/with spaces/ruby"
chmod +x "$test_dir/with spaces/ruby"
expect_status 0 --binary "$test_dir/with spaces/ruby" "$test_dir/with spaces/ruby"
grep -q 'fixed_by_version=1' "$test_dir/output"
printf '#!/usr/bin/env bash\nprintf "ruby 3.4.12 (fixture)\\n"\n' > "$test_dir/affected"
chmod +x "$test_dir/affected"
expect_status 1 --binary "$test_dir/affected"
printf '#!/usr/bin/env bash\nexit 7\n' > "$test_dir/broken"
chmod +x "$test_dir/broken"
expect_status 2 --binary "$test_dir/broken"
printf '#!/usr/bin/env bash\nprintf "jruby fixture\\n"\n' > "$test_dir/other"
chmod +x "$test_dir/other"
expect_status 2 --binary "$test_dir/other"
printf '#!/usr/bin/env bash\nsleep 15\n' > "$test_dir/hanging"
chmod +x "$test_dir/hanging"
expect_status 2 --binary "$test_dir/hanging"
grep -q 'version query failed or timed out' "$test_dir/output"
expect_status 1 --binary "$test_dir/affected" "$test_dir/broken"

# Simulated proc entries: no attempt to execute a replaced/deleted interpreter.
(
    mkdir -p "$test_dir/proc/101" "$test_dir/proc/102"
    readlink() { printf '%s\n' '/opt/ruby/bin/ruby (deleted)'; }
    affected_count=0 fixed_count=0 unknown_count=0
    observe_processes "$test_dir/proc" > "$test_dir/process-output"
    [[ "$unknown_count" == 2 && "$fixed_count" == 0 && "$affected_count" == 0 ]]
    [[ "$(grep -c UNVERIFIED_PROCESS "$test_dir/process-output")" == 2 ]]
    unknown_count=0
    observe_processes "$test_dir/missing-proc" > /dev/null
    [[ "$unknown_count" == 1 ]]
)
test_count=$((test_count + 2))

# Empty scan cannot return success, independent of this host's installed Ruby.
(
    uname() { printf 'Linux\n'; }
    observe_processes() { :; }
    check_binary() { :; }
    type() { return 1; }
    result=0
    main > "$test_dir/empty-output" || result=$?
    [[ "$result" == 2 ]]
)
test_count=$((test_count + 1))
printf 'Inventory checks passed: %s\n' "$test_count"
