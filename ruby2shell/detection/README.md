# Detection artifacts

[Back to README](../README.md)

The artifacts remain experimental. Parser and local regression checks are
included; production log ingestion and SIEM query execution have not been tested.

| Artifact | Purpose | Validation scope |
| --- | --- | --- |
| [Inventory script](inventory_check.sh) | Numeric MRI version classification and limited executable inventory | Boundary, failure, deduplication, and process-observation regression tests |
| [Sigma correlation](sigma_ruby_crash_correlation.yml) | Suspicious request and Ruby error for the same instance within one minute | pySigma parsing/reference resolution and normalized-event fixtures |
| [Network notes](waf_suspect_pattern.md) | Explain suspicious-input hypotheses and inspection buffers | Requires application-specific traffic and false-positive testing |

## Inventory usage

Requires Bash 4+. Automatic inventory requires Linux, `readlink`, and the `timeout`
utility from GNU coreutils. From the repository root:

```bash
# Classify tokens without executing interpreters or scanning the host.
bash detection/inventory_check.sh --version 3.4.12 3.4.13 3.4.100

# Query specific trusted MRI binaries with -v and a five-second timeout.
bash detection/inventory_check.sh --binary /usr/bin/ruby /opt/gitlab/embedded/bin/ruby

# Observe Linux processes and query selected installed/PATH executables.
bash detection/inventory_check.sh
```

The first command deliberately returns status 1 because it includes an affected
version. Run inventory only where the queried executables are trusted: `-v` still
executes a program. A forced kill follows one second after a timeout if necessary.
Repeated paths resolving to the same executable are queried once.

### Version interpretation

Classification compares complete numeric major/minor/patch components rather
than prefixes. Stable `3.3.x`, `3.4.x`, and `4.0.x` releases are compared against
3.3.14, 3.4.13, and 4.0.10 respectively. Older 2.x and 3.0–3.2 versions receive
an affected-by-version label, consistent with the advisory's older-version range.

Stable MRI patchlevel suffixes such as `3.4.13p0` are accepted. Prereleases,
vendor-specific suffixes, unrecognized output, 1.x versions, and unreviewed future
branches remain `UNKNOWN`. The script does not claim a historical introduction
version or extrapolate remediation thresholds to other branches.

| Label | Meaning |
| --- | --- |
| `AFFECTED_BY_VERSION` | Version falls below the upstream threshold; vendor backports need separate review |
| `FIXED_BY_VERSION` | Stable version meets the known branch threshold; package provenance and live processes remain separate checks |
| `UNKNOWN` | Unsupported version/format or unsuccessful executable query |
| `UNVERIFIED_PROCESS` | A Ruby-named process was observed; its loaded interpreter version has not been established |

### Exit status

- `0`: at least one version result, all checked results meet known thresholds.
- `1`: at least one affected-by-version result, including mixed/unknown scans.
- `2`: unknown, failed, empty, or unverified results without an affected result.
- `64`: invalid invocation.

Process observations never execute `/proc/PID/exe` or its resolved target.
Deleted/replaced images remain unverified even if a current installed binary is
fixed. Permissions, namespaces, renaming, and selected paths limit visibility.
An exit status of zero is a version assessment of discovered binaries, not proof
that the host is fully patched. Product-specific paths are discovery hints, not
a list of confirmed affected products.

## Sigma correlation and field mapping

The YAML contains three documents: a Ruby error selector, a suspicious HTTP
request selector, and a `temporal` correlation. Load them together using a backend
that supports Sigma temporal correlation. The grouping key is `service_instance`
and the window is one minute. Either event order is accepted because request
logs may be emitted after the error. Repetition and client-IP attribution are not
claimed by this rule.

Normalize the following fields before evaluation, and map the two log sources to
the corresponding datasets in your backend:

| Field | Required input |
| --- | --- |
| Event timestamp | Actual event time for both datasets, using consistent time zones |
| `service_instance` | Nonempty, globally scoped identifier shared by the proxy's routed upstream and the Ruby instance, e.g. cluster/namespace/pod/service |
| `message` | Ruby application's error message; source category `application`, product `ruby` |
| `request_raw` | Still-percent-encoded HTTP URL/body text from source category `webserver`; not a percent-decoded argument buffer |

Do not substitute a broad service name for an instance identifier on a large
fleet. If the proxy cannot identify the upstream instance, this correlation cannot
be applied as written. Empty or missing grouping keys are excluded. The raw-input
pattern accepts uppercase and lowercase hex; it does not cover decoded bytes,
double encoding, all input layouts, or all delivery channels.

A matching request and a crash in the same instance/window may be coincidental.
The rule is a medium-severity investigation signal, not proof of exploitation.
Tune and validate ingestion, regex handling, clock skew, and window semantics in
the selected backend before deployment. See the
[Sigma correlation specification](https://sigmahq.io/sigma-specification/specification/sigma-correlation-rules-specification.html).

## Validation

From the repository root:

```bash
bash -n detection/inventory_check.sh
bash tests/test_inventory.sh
python -m pip install -r tests/requirements.txt
python tests/test_sigma.py
```

The inventory suite uses executable fixtures and simulated process observations;
it does not scan the host or run the vulnerability trigger. The Sigma suite parses
all documents with pySigma and tests a small reference evaluator for the operators
used here. This verifies intended normalized-event behavior, not a production
backend's implementation. See [validation details](../tests/README.md).
