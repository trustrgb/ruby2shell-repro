# Reported Valgrind matrix results

[Back to README](../../README.md) · [Reproduction procedure](../../docs/reproduction.md)

## Evidence status

The table below preserves observations reported in the supplied archive. It is
not an independently verified test report. The archive contains no raw Valgrind
logs, image digests, complete build metadata, or per-case exit-status records.
No reproduction was executed during the documentation review.

Reported environment: Docker `ruby:3.4.12`, Valgrind 3.24.0.
Reported run date: 2026-11-20. Neither value has been independently confirmed.

## Supplied observations

| Input size | Encoding | Method | Reported invalid-write count | Evidence status |
| --- | --- | --- | --- | --- |
| 20 | ISO-8859-1 | `upcase` | 0 | Raw log absent |
| 21 | ISO-8859-1 | `upcase` | 1 | Raw log absent |
| 21 | ISO-8859-1 | `swapcase` | 1 | Raw log absent |
| 21 | ISO-8859-1 | `downcase(:fold)` | 1 | Command and raw log absent |
| 21 | Windows-1252 | `upcase` | 1 | Raw log absent |
| 21 | UTF-8 | `upcase` | 0 | Input construction, command, and raw log absent |

These numbers are author-reported counts, not established per-case verdicts.
The original notes obtained some counts by searching console text for
`Invalid write`; that counts matching lines rather than a canonical Valgrind
error total and does not preserve the Ruby/Valgrind process status.

## Coverage mismatch

The checked-in [matrix runner](../matrix_test.rb) covers 14 legacy encodings,
two methods (`upcase`, `swapcase`), and two sizes (20, 21). It runs all cases in
one process and reports Ruby exceptions, not per-case Valgrind diagnostics.

`downcase(:fold)` and UTF-8 are absent from that runner. The original archive
also lacks commands for those two table rows. Retain them as reported observations
until a separate reproducible command and full output are provided.

A repeated raw `0xDF` byte string is invalid UTF-8. A UTF-8 control needs valid
UTF-8 input; absence of an invalid-write diagnostic alone would not establish
that the control completed successfully.

## Claims requiring additional evidence

The original notes attributed quiet runs to allocator padding and described a
41-byte logical buffer alongside an excerpt mentioning a 65-byte allocation.
The supplied material does not establish the allocator explanation or reconcile
those sizes. Source line numbers and allocation details must be tied to the
exact build. See [analysis limits](../../docs/root-cause.md).

The archive contains no equivalent raw evidence for the fixed runtime or ASan
build. Expected results must not be presented as observed outcomes.

## Completing the report

Use the [evidence collection procedure](../../docs/reproduction.md) and retain
one instrumented process per case. Add run metadata, exit statuses, full logs,
and matched patched controls before upgrading any row to a verified result.
Keep generated console output in separate log files; do not overwrite this page.
