# HTTP demonstration

[Back to README](../README.md)

This Sinatra application explicitly relabels request bytes as ISO-8859-1 and
calls `upcase`. It illustrates one application-specific route into case mapping;
it does not establish that default Sinatra or Rails configurations are vulnerable.

## Run locally

Use a disposable lab environment with Ruby and Bundler. From the repository root:

```bash
cd app
bundle install
bundle exec ruby sinatra_entrypoint.rb -o 127.0.0.1
```

The source defaults to `0.0.0.0`; the command above requests a loopback binding.
Confirm the listening address in the startup output. The Compose file does not
publish an HTTP port or install this application's gems automatically. The Gemfile
has no lockfile, so dependency resolution can change between runs. The startup
command and dependencies have not been runtime-tested during this review.

Use a separate local terminal for a basic route check:

```bash
curl 'http://127.0.0.1:4567/health'
curl 'http://127.0.0.1:4567/test?input=hello'
```

An HTTP response does not validate memory safety. Follow the
[instrumented CLI procedure](../docs/reproduction.md) for the boundary control
and trigger comparison. Request parsing and host authorization may affect HTTP
behavior independently of the Ruby case-mapping issue.

## Interpretation

`force_encoding` changes the encoding label without transcoding input. A UTF-8
sharp-s character and a raw `0xDF` byte therefore are different inputs. Document
the actual bytes and parser behavior in any HTTP-specific research results.

The original archive cited an unverified CVE identifier; this edition uses
the [GHSA advisory](https://github.com/ruby/ruby/security/advisories/GHSA-34m4-m9fh-gqp5)
as the reference until the identifier is confirmed.
