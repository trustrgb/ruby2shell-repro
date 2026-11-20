# Local reproduction and evidence collection

[Back to README](../README.md)

## Scope and prerequisites

Use an isolated local lab with Docker Engine and the Docker Compose plugin.
Run the following commands from the repository root in Bash, WSL, or a Linux shell.
The container definitions enable tracing privileges and relax seccomp filtering
for debugging. Review them before running on a shared host.

The checked-in Compose file selects Ruby 3.4.12 and 3.4.13 for comparison.
Image availability and successful builds have not been verified in this review.

## Build the comparison environments

```bash
docker compose build ruby-vulnerable ruby-fixed
mkdir -p reports
```

Each command below starts a disposable container. No persistent interactive
container or additional `docker compose exec` step is required.

## Boundary control and trigger

```bash
docker compose run --rm -T ruby-vulnerable ruby trigger/control_20.rb
docker compose run --rm -T ruby-vulnerable ruby trigger/poc_trigger.rb
```

Both scripts may finish normally even when a memory error occurs. Use an
instrumented run for evidence; the printed result length is not a safety check.

## Valgrind comparison

```bash
set -o pipefail
docker compose run --rm -T ruby-vulnerable \
  valgrind --error-exitcode=42 ruby trigger/control_20.rb \
  2>&1 | tee reports/control-20.txt
control_status=${PIPESTATUS[0]}
printf 'control exit status: %s\n' "$control_status"

docker compose run --rm -T ruby-vulnerable \
  valgrind --error-exitcode=42 ruby trigger/poc_trigger.rb \
  2>&1 | tee reports/vulnerable-trigger.txt
vulnerable_status=${PIPESTATUS[0]}
printf 'vulnerable exit status: %s\n' "$vulnerable_status"

docker compose run --rm -T ruby-fixed \
  valgrind --error-exitcode=42 ruby trigger/poc_trigger.rb \
  2>&1 | tee reports/fixed-trigger.txt
fixed_status=${PIPESTATUS[0]}
printf 'fixed exit status: %s\n' "$fixed_status"
```

Logs are written by the host shell to `reports/`; the mounted `trigger/` directory
is read-only. Do not overwrite the curated Markdown results with console output.
These commands intentionally avoid `set -e` so an expected diagnostic status does
not stop the comparison before the status can be recorded.

On a reproduction, expect a relevant invalid-write diagnostic in the affected
build and its absence in the corresponding patched build. Exit code 42 indicates
that Valgrind reported errors; inspect the full trace to attribute them to this
issue. `--error-exitcode` does not itself abort on the first error.

## Existing matrix runner

```bash
docker compose run --rm -T ruby-vulnerable \
  valgrind --error-exitcode=42 ruby trigger/matrix_test.rb \
  > reports/matrix-vulnerable.txt 2>&1
matrix_status=$?
printf 'matrix exit status: %s\n' "$matrix_status"
```

The runner covers 14 encodings, `upcase` and `swapcase`, and input sizes 20 and 21:
56 cases in one Ruby process. It does not cover `downcase(:fold)`, `casecmp?`, or
UTF-8. Its `PASS (no immediate crash)` label reports only the absence of a Ruby
exception. Its exception counter and `VALGRIND` environment variable do not
validate memory safety or assign Valgrind errors to individual rows.

Use a separate instrumented process for each case before publishing per-case
error counts. The original [results summary](../trigger/valgrind/matrix_results.md)
records reported observations and the missing evidence.

## AddressSanitizer alternative

```bash
docker compose build ruby-asan
docker compose run --rm -T ruby-asan ruby trigger/poc_trigger.rb \
  > reports/asan-trigger.txt 2>&1
asan_status=$?
printf 'ASan exit status: %s\n' "$asan_status"
```

The root Compose file already includes this service. The standalone
`lab/docker-compose.asan.yml` is an alternative definition; do not start both
under their shared container name. The ASan build has not been executed here.

## Evidence required for publication

Record the run date, host architecture, container image digest, Ruby version and
source revision, instrumentation version, exact command, exit status, and full
diagnostic for both affected and fixed builds. Record unexpected errors too.
Review logs for secrets before adding them to version control.
