# Network detection hypotheses

[Back to README](../README.md) · [Detection overview](README.md)

These notes describe possible investigation signals for
[GHSA-34m4-m9fh-gqp5](https://github.com/ruby/ruby/security/advisories/GHSA-34m4-m9fh-gqp5).
They are not validated ModSecurity or Suricata rules. No production blocking
recommendation follows from a pattern match alone.

## Application prerequisites

A request is relevant only if its bytes reach affected case-mapping behavior in
a susceptible Ruby build. A long byte sequence in network traffic does not show
which encoding or conversion the application will use.

The lab uses repeated `0xDF` bytes and explicitly sets a legacy encoding. This
is a test construction, not a complete specification of all possible inputs.
A client charset declaration does not prove how the server handles those bytes.

## Encoded input signal

For a buffer that still contains percent-encoded text, this conceptual expression
matches 21 or more adjacent percent-encoded `0xDF` bytes, with either hex case:

```regex
(?:%[dD][fF]){21,}
```

Select the inspection buffer before implementing a rule. A decoded argument
buffer may contain raw bytes rather than literal `%DF`; a pattern for one
representation cannot be assumed to work on the other. Double encoding, body
formats, parameter parsing, and normalization can change what the engine sees.

The original example inspected ModSecurity `ARGS` for literal `%DF` without
accounting for argument decoding. It is intentionally omitted from this revision
until a tested buffer and transformation policy are supplied. The original
Suricata example likewise has not been syntax- or behavior-validated.

## Crash correlation

Correlate request and process events using an application or service identifier,
a defined time window, and request or trace identifiers where available. A crash
log often has no trustworthy client IP; a shared source IP is not a reliable join
key on its own.

A proposed analytic should require both:

1. A request with the selected suspicious-input signal.
2. A matching Ruby process error for the same service within a bounded window.

Count joined request/error pairs after deduplication if repetition is part of
the analytic. Define the threshold from baseline traffic. The original `UNION ALL`
query merely counted a mixture of events and did not enforce a temporal join or
require both event types, so it did not implement the claimed correlation.

The [Sigma correlation](sigma_ruby_crash_correlation.yml) now implements a
same-instance, one-minute temporal join. See its
[field mapping and limitations](README.md#sigma-correlation-and-field-mapping).

## Triage and limitations

- Inspect the relevant application path and deployed Ruby build before attributing
  a match to this issue.
- Check for native-extension faults and other causes of memory diagnostics.
- Absence of crashes does not exclude a memory error.
- Repeated `ß` text and repeated raw `0xDF` bytes are not equivalent in UTF-8.
  `force_encoding` relabels bytes and does not perform the necessary transcoding.
- Encrypted traffic, unparsed bodies, and non-HTTP protocols require different
  telemetry. Network inspection alone cannot establish exploitability.

Begin with observation and false-positive testing. Add response actions only after
the analytic has been validated in the intended environment.
