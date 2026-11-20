#!/usr/bin/env ruby
# frozen_string_literal: true

# Matrix test for GHSA-34m4-m9fh-gqp5 boundary conditions.
# Validates: encodings × methods × input sizes (20 vs 21)
#
# Run under Valgrind for ground-truth detection:
#   valgrind --error-exitcode=42 ruby trigger/matrix_test.rb

REQUIRE_VALGRIND = ENV["VALGRIND"] == "1"

ENCODINGS = %w[
  ISO-8859-1 ISO-8859-2 ISO-8859-3 ISO-8859-4 ISO-8859-9
  ISO-8859-10 ISO-8859-13 ISO-8859-14 ISO-8859-15 ISO-8859-16
  Windows-1250 Windows-1252 Windows-1254 Windows-1257
].freeze

METHODS = %i[upcase swapcase].freeze
SIZES   = [20, 21].freeze

puts "=" * 60
puts "GHSA-34m4-m9fh-gqp5 Boundary Matrix"
puts "Ruby version: #{RUBY_VERSION}"
puts "=" * 60

failures = 0

ENCODINGS.each do |enc_name|
  METHODS.each do |method|
    SIZES.each do |size|
      label = "#{enc_name} | #{method.to_s.ljust(9)} | n=#{size}"

      begin
        s = ("\xDF" * size).force_encoding(enc_name)
        result = s.public_send(method)

        # Under Valgrind, an invalid write causes immediate abort with code 42.
        # Under normal execution, we cannot detect the overflow directly.
        status = "PASS (no immediate crash)"

      rescue => e
        status = "EXCEPTION: #{e.class}"
        failures += 1
      end

      puts "#{label} => #{status}"
    end
  end
end

puts "=" * 60
puts "Matrix complete. #{failures} exceptions."
puts "Run under Valgrind to detect memory errors:"
puts "  VALGRIND=1 valgrind --error-exitcode=42 ruby trigger/matrix_test.rb"
