# Regression checks

[Back to README](../README.md) · [Detection documentation](../detection/README.md)

## Run

Use Bash 4+, GNU coreutils, and Python 3.12+ in a local test environment.
Python 3.12 was used for this review. Install into a virtual environment if
required by your system.
From the repository root:

```bash
bash -n detection/inventory_check.sh
bash tests/test_inventory.sh
python -m pip install -r tests/requirements.txt
python tests/test_sigma.py
```

## Coverage

The shell suite exercises the actual inventory script, including branch thresholds,
later patch versions that previously matched affected prefixes, prereleases,
unknown formats, mixed-result exit statuses, missing binaries, executable paths
containing spaces, deduplication, unsuccessful/timed-out queries, unsupported interpreter
output, unverified/deleted process observations, and empty discovery.

The Python suite uses pySigma to parse the multi-document YAML and resolve its
rule references. Normalized-event fixtures cover matching pairs, reversed order,
events outside the time window, differing service instances, missing grouping
keys, insufficient byte sequences, double encoding, and unrelated messages.

The fixture evaluator deliberately supports only the field operators and condition
used in these rules. It is not a Sigma runtime and is not a replacement for query
conversion and integration tests against your SIEM.

## Review run

On 2026-11-20, inventory tests ran in Git Bash 5.3 on Windows; Sigma checks ran
with Python 3.12, pySigma 2.1.0, and PyYAML 6.0.3. Linux automatic discovery,
production SIEM queries, and the vulnerability reproduction itself were not run.
