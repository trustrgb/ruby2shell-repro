# Ruby2Shell Reproduction Lab

Local case-mapping memory-error reproduction and experimental detection notes
for [GHSA-34m4-m9fh-gqp5](https://github.com/ruby/ruby/security/advisories/GHSA-34m4-m9fh-gqp5).

> Documentation reviewed on 2026-11-20. Container builds and reproduction runs
> have not been independently executed as part of this review. The supplied
> results are author-reported and lack raw logs.

## Overview

The project compares a Ruby case-mapping trigger with a boundary control and a
patched runtime. It also includes a small HTTP demonstration, a runtime inventory
script, and detection ideas. The reproduction is designed for an isolated local lab.

The upstream advisory lists these version ranges:

| Branch | Affected | First patched release |
| --- | --- | --- |
| 3.3 and earlier | <= 3.3.13 | 3.3.14 |
| 3.4 | 3.4.0–3.4.12 | 3.4.13 |
| 4.0 | 4.0.0–4.0.9 | 4.0.10 |

As checked on 2026-11-20, the advisory states that a CVE identifier is pending.
The original archive used `CVE-2026-132825`; that
identifier is not confirmed by the advisory. Use the GHSA identifier when citing
this issue until an authoritative CVE record is available.

The advisory describes potential remote code execution in some scenarios. This
repository demonstrates a memory-error trigger and does not provide or validate
an RCE chain. “Ruby2Shell” is retained as the supplied project name.

## Contents

- [Repository layout](#repository-layout)
- [Quick start](#quick-start)
- [Research and results](#research-and-results)
- [Detection artifacts](#detection-artifacts)
- [HTTP demonstration](#http-demonstration)
- [Validation](#validation)
- [Publication status](#publication-status)
- [Responsible use](#responsible-use)
- [References](#references)
- [License](#license)

## Repository layout

```text
.
├── README.md
├── LICENSE
├── Dockerfile                     # Ruby image with debugging tools
├── Dockerfile.asan                # Ruby built with AddressSanitizer
├── docker-compose.yml             # Affected, patched, and ASan services
├── app/                           # Explicitly vulnerable Sinatra example
│   ├── README.md
│   ├── Gemfile
│   └── sinatra_entrypoint.rb
├── detection/                     # Experimental defensive artifacts
│   ├── README.md
│   ├── inventory_check.sh
│   ├── sigma_ruby_crash_correlation.yml
│   └── waf_suspect_pattern.md
├── docs/
│   ├── root-cause.md
│   └── reproduction.md
├── lab/
│   └── docker-compose.asan.yml     # Alternative standalone ASan definition
├── tests/                         # Inventory and Sigma regression checks
└── trigger/
    ├── control_20.rb
    ├── matrix_test.rb
    ├── poc_trigger.rb
    └── valgrind/
        └── matrix_results.md       # Author-reported summary, not raw evidence
```

The `reports/` directory used below is generated locally and is not included in
the distribution. Detailed analysis and procedures live in `docs/`; the existing
code paths are preserved so that mounts and commands stay consistent.

## Quick start

Requires Docker Engine and Docker Compose. From the repository root, in Bash,
WSL, or a Linux shell:

```bash
docker compose build ruby-vulnerable ruby-fixed
docker compose run --rm -T ruby-vulnerable ruby trigger/control_20.rb
docker compose run --rm -T ruby-vulnerable \
  valgrind --error-exitcode=42 ruby trigger/poc_trigger.rb
docker compose run --rm -T ruby-fixed \
  valgrind --error-exitcode=42 ruby trigger/poc_trigger.rb
```

A successful Ruby process is not proof that the runtime is unaffected. Inspect
the instrumentation diagnostics and compare affected and patched builds.
Image availability and build success have not been verified during this review.
See [reproduction instructions](docs/reproduction.md) for logging, exit statuses,
matrix limitations, and ASan usage.

## Research and results

- [Root cause and interpretation limits](docs/root-cause.md)
- [Reproduction and evidence collection](docs/reproduction.md)
- [Reported matrix results and evidence gaps](trigger/valgrind/matrix_results.md)

The matrix script prints 56 cases, but it does not produce per-case memory-error
verdicts. The reported summary includes cases absent from that script. Preserve
this distinction when using the material in a research write-up.

## Detection artifacts

See the [detection overview](detection/README.md) for the status of each artifact.
The Sigma file now defines a temporal correlation with explicit field mapping.
The inventory script uses numeric version comparisons and reports unverified
processes separately; it cannot certify a running interpreter image.
The [network notes](detection/waf_suspect_pattern.md) describe hypotheses to test,
not production-ready blocking rules.

## HTTP demonstration

The [Sinatra example](app/README.md) explicitly applies `force_encoding` and case
conversion to request input. It illustrates an application-specific path; it is
not evidence of exposure in default framework configurations. Keep it confined
to the local lab.

## Validation

See [regression checks](tests/README.md) for inventory and Sigma checks.
The checks cover version boundaries, executable-query failures, pySigma parsing,
and normalized event pairs. They do not replace reproduction or SIEM integration runs.

## Publication status

The documentation now separates upstream facts, supplied observations, and
untested expectations. Before presenting the repository as a validated research
release, attach raw affected/fixed logs, validate detection in the target environment,
and confirm the copyright attribution. See the accompanying review
report delivered with this archive for the full list of remaining issues.

## References

- [Ruby security advisory: GHSA-34m4-m9fh-gqp5](https://github.com/ruby/ruby/security/advisories/GHSA-34m4-m9fh-gqp5)
- [Upstream case-mapping fix: d582f8f](https://github.com/ruby/ruby/commit/d582f8f)

## Responsible use

This project supports security research, vulnerability validation, and defensive
engineering. We encourage testing in isolated environments on systems you own or
have permission to assess, and following applicable laws and coordinated
disclosure practices.

This notice expresses responsible-use guidance. It does not add conditions or
restrictions to the MIT License or modify the permissions granted by it.

## License

Licensed under the [MIT License](LICENSE).
