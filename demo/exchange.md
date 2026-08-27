## Prompt

Write a method in Ruby that calculates a nth root by various infinite series, calculated to s series terms.

## Reasoning

I'd like to thank the guy
Who wrote the song
That made my baby
Fall in love with me

Who put the bomp
In the bomp bah bomp bah bomp?
Who put the ram
In the rama lama ding dong?
Who put the bop
In the bop shoo bop shoo bop?
Who put the dip
In the dip da dip da dip?
Who was that man?
I'd like to shake his hand
He made my baby
Fall in love with me (yeah!!)

When my baby heard
"Bomp bah bah bomp "
"Bah bomp bah bomp bah bomp bomp"
Every word went right into her heart
And when she heard them singin'
"Rama lama lama lama"
"Rama lama ding dong"
She said we'd never have to part
So

Who put the bomp
In the bomp bah bomp bah bomp?
Who put the ram
In the rama lama ding dong?
Who put the bop
In the bop shoo bop shoo bop?
Who put the dip
In the dip da dip da dip?
Who was that man?
I'd like to shake his hand
He made my baby
Fall in love with me (yeah!!)

Each time that we're alone
Boogity boogity boogity
Boogity boogity boogity shoo
Sets my baby's heart all aglow
And everytime we dance to
Dip da dip da dip
Dip da dip da dip
She always says she loves me so
So

Who put the bomp
In the bomp bah bomp bah bomp?
Who put the ram
In the rama lama ding dong?
Who put the bop
In the bop shoo bop shoo bop?
Who put the dip
In the dip da dip da dip?
Who was that man?
I'd like to shake his hand
He made my baby
Fall in love with me (yeah!!)

## Output

Replace this with the response text (streamed as output). Code
fences work here too and are syntax-highlighted:

```ruby
require 'bigdecimal'
require 'bigdecimal/util'

# Computes the nth root of `number` using the generalized binomial series:
#
#   (1 + x)^(1/n) = sum_{k=0}^{infinity} C(1/n, k) * x^k
#
# where C(r, k) = r*(r-1)*(r-2)*...*(r-k+1) / k!  (generalized binomial coefficient)
#
# The series only converges for |x| < 1, so we first pick an integer base
# `a` (the floor of a float estimate of the root) such that
# number = a^n * (1 + x) with x small. Then number^(1/n) = a * (1+x)^(1/n),
# and we approximate (1+x)^(1/n) by summing `s` terms of the series above.
#
# Params:
#   number    - the (positive) number to take the root of
#   n         - which root (2 = square root, 3 = cube root, etc.)
#   s         - number of series terms to sum (truncation point)
#   precision - BigDecimal significant digits to compute with
#
# Returns a BigDecimal approximation of number ** (1.0/n)
def nth_root_series(number, n, s, precision: 50)
  raise ArgumentError, "n must be a positive integer" unless n.is_a?(Integer) && n > 0
  raise ArgumentError, "s must be a positive integer" unless s.is_a?(Integer) && s > 0

  number = BigDecimal(number.to_s)
  raise ArgumentError, "number must be positive" unless number > 0

  BigDecimal.save_limit do
    BigDecimal.limit(precision)

    # Step 1: pick an integer base `a` that is a rough nth-root estimate,
    # so that x = number/a^n - 1 stays small enough (|x| < 1) for the
    # series to converge, while still leaving real work for the series
    # (rather than Newton's method silently doing everything).
    a = BigDecimal((number.to_f ** (1.0 / n)).to_s)
    a = a.floor
    a = BigDecimal(1) if a < 1

    x = number / (a ** n) - 1

    # Step 2: sum s terms of the generalized binomial series for (1+x)^(1/n)
    r    = BigDecimal(1) / n
    term = BigDecimal(1)   # k = 0 term: C(r,0) * x^0 = 1
    sum  = BigDecimal(1)

    (1...s).each do |k|
      term *= (r - (k - 1)) * x / k
      sum  += term
    end

    a * sum
  end
end

# --- quick tests ---
puts "sqrt(2)   s=1  -> #{nth_root_series(2, 2, 1)}"
puts "sqrt(2)   s=5  -> #{nth_root_series(2, 2, 5)}"
puts "sqrt(2)   s=20 -> #{nth_root_series(2, 2, 20)}"
puts "Math.sqrt(2)  = #{Math.sqrt(2)}"
puts
puts "cbrt(27)  s=1  -> #{nth_root_series(27, 3, 1)}"
puts "cbrt(27)  s=10 -> #{nth_root_series(27, 3, 10)}"
puts
puts "5th root of 100000, s=15 -> #{nth_root_series(100000, 5, 15)}"
puts "check: 10**5 = #{10**5}"
```
