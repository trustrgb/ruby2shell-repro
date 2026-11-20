# Case-mapping boundary error

[Back to README](../README.md)

## Upstream evidence

Ruby's [security advisory](https://github.com/ruby/ruby/security/advisories/GHSA-34m4-m9fh-gqp5)
describes a one-byte write beyond a heap buffer during case conversion in certain
single-byte encodings. The [upstream fix](https://github.com/ruby/ruby/commit/d582f8f)
changes the output-space check in the affected encoding implementations.

Simplified guard before the fix:

```c
while (*pp < end && to < to_end) {
    /* Some mappings expand one input byte into two output bytes. */
}
```

Guard after the fix:

```c
while (*pp < end && to_end - to > 1) {
```

The old condition permits an iteration with one byte remaining. Expanding sharp s
into two bytes can then cross the output boundary. The new condition requires
room for both bytes.

## Local test hypothesis

The supplied scripts compare strings containing 20 and 21 `0xDF` bytes in legacy
encodings. The original notes explain this boundary using an initial output
capacity of `input_length + 20`: 21 input bytes would require 42 output bytes
against a capacity of 41. Treat that allocation model as a hypothesis to verify
against the exact Ruby source revision and instrumentation used for each run.

Do not infer allocator chunk sizes from this arithmetic. The original excerpt
mentions a 65-byte allocation, but no complete trace or allocation metadata is
included to reconcile it with the proposed 41-byte output capacity.

## Interpretation limits

- Successful output or a zero Ruby exit status does not prove memory safety.
- A diagnostic's source line and allocation size depend on the build.
- `force_encoding` relabels bytes; it does not transcode UTF-8 into a legacy encoding.
- The same repeated `0xDF` bytes are invalid UTF-8. A meaningful UTF-8 control
  needs valid UTF-8 text and a separately recorded result.
- The HTTP example explicitly applies a legacy encoding and case conversion.
  It does not establish that default Rails or Sinatra applications are exposed.

The repository contains a memory-error reproduction, not a demonstrated RCE chain.
