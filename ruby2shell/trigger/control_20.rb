#!/usr/bin/env ruby
# frozen_string_literal: true

# Control test: 20 sharp-s characters should NOT trigger overflow.
# Buffer: 20 + 20 = 40 bytes
# Output: 20 * 2 = 40 bytes (SS...SS)
# Result: No overflow — boundary minus one.

s = "\xDF" * 20
s.force_encoding("ISO-8859-1")
s.upcase
puts "done20"
