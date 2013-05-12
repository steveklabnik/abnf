# Abnf

[![Build Status](https://travis-ci.org/steveklabnik/abnf.png?branch=master)](https://travis-ci.org/steveklabnik/abnf) [![Code Climate](https://codeclimate.com/github/steveklabnik/abnf.png)](https://codeclimate.com/github/steveklabnik/abnf)

This is a library to convert ABNF (Augmented Backus-Naur Form) to Regexp
(Regular Expression) written in Ruby.  It parses a description according to
ABNF defined by RFC2234 and some variants.  Then the parsed grammar is
transformed to recursion free.  Although the transformation is impossible in
general, the library transform left- and right-recursion.  The recursion free
grammar can be printed as Regexp literal which is suitable in Ruby script.  The
literal is pretty readable because parentheses are minimized and properly
indented by the Wadler's pretty printing algebra.  It is also possible to use
the Regexp just in place.

I (@steveklabnik) have gem-ified the code originally located at
[https://github.com/akr/abnf](https://github.com/akr/abnf).

## Installation

Add this line to your application's Gemfile:

    gem 'abnf'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install abnf

## Usage

Following example shows URI-reference defined by RFC 2396 can be converted to
Regexp.
Note that URI-reference has no recursion.
Also note that the example works well without installing the library after make.

```ruby
  require 'pp'
  require 'abnf'

  # URI-reference [RFC2396]
  uri_ref = <<- End
        URI-reference = [ absoluteURI | relativeURI ] [ "#" fragment ]
        absoluteURI   = scheme ":" ( hier_part | opaque_part )
        relativeURI   = ( net_path | abs_path | rel_path ) [ "?" query ]

        (...snip...)

        lowalpha = "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" |
                   "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" |
                   "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
        upalpha  = "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" |
                   "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" |
                   "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z"
        digit    = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" |
                   "8" | "9"
  End

  pp ABNF.regexp_tree(uri_ref)
```

The result is follows:

```ruby
  %r{(?:[a-z][\x2b\x2d\x2e0-9a-z]*:
        (?:(?://
              (?:(?:(?:(?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                          %[0-9a-f][0-9a-f]|
                          [\x24&\x2b,:;=])*@)?
                    (?:(?:(?:[0-9a-z]|[0-9a-z][\x2d0-9a-z]*[0-9a-z])\x2e)*
                       (?:[a-z]|[a-z][\x2d0-9a-z]*[0-9a-z])\x2e?|
                       \d+\x2e\d+\x2e\d+\x2e\d+)(?::\d*)?)?|
                 (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                    %[0-9a-f][0-9a-f]|
                    [\x24&\x2b,:;=@])+)
              (?:/
                 (?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:=@])*
                 (?:;
                    (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                       %[0-9a-f][0-9a-f]|
                       [\x24&\x2b,:=@])*)*
                 (?:/
                    (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                       %[0-9a-f][0-9a-f]|
                       [\x24&\x2b,:=@])*
                    (?:;
                       (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                          %[0-9a-f][0-9a-f]|
                          [\x24&\x2b,:=@])*)*)*)?|
              /(?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:=@])*
              (?:;
                 (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                    %[0-9a-f][0-9a-f]|
                    [\x24&\x2b,:=@])*)*
              (?:/
                 (?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:=@])*
                 (?:;
                    (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                       %[0-9a-f][0-9a-f]|
                       [\x24&\x2b,:=@])*)*)*)
           (?:\x3f(?:[!\x24&-;=\x3f@_a-z~]|%[0-9a-f][0-9a-f])*)?|
           (?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:;=\x3f@])
           (?:[!\x24&-;=\x3f@_a-z~]|%[0-9a-f][0-9a-f])*)|
        (?://
           (?:(?:(?:(?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                       %[0-9a-f][0-9a-f]|
                       [\x24&\x2b,:;=])*@)?
                 (?:(?:(?:[0-9a-z]|[0-9a-z][\x2d0-9a-z]*[0-9a-z])\x2e)*
                    (?:[a-z]|[a-z][\x2d0-9a-z]*[0-9a-z])\x2e?|
                    \d+\x2e\d+\x2e\d+\x2e\d+)(?::\d*)?)?|
              (?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:;=@])+)
           (?:/(?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:=@])*
              (?:;
                 (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                    %[0-9a-f][0-9a-f]|
                    [\x24&\x2b,:=@])*)*
              (?:/
                 (?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:=@])*
                 (?:;
                    (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                       %[0-9a-f][0-9a-f]|
                       [\x24&\x2b,:=@])*)*)*)?|
           /(?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:=@])*
           (?:;(?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:=@])*)*
           (?:/(?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:=@])*
              (?:;
                 (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                    %[0-9a-f][0-9a-f]|
                    [\x24&\x2b,:=@])*)*)*|
           (?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,;=@])+
           (?:/(?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:=@])*
              (?:;
                 (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                    %[0-9a-f][0-9a-f]|
                    [\x24&\x2b,:=@])*)*
              (?:/
                 (?:[!'-\x2a\x2d\x2e0-9_a-z~]|%[0-9a-f][0-9a-f]|[\x24&\x2b,:=@])*
                 (?:;
                    (?:[!'-\x2a\x2d\x2e0-9_a-z~]|
                       %[0-9a-f][0-9a-f]|
                       [\x24&\x2b,:=@])*)*)*)?)
        (?:\x3f(?:[!\x24&-;=\x3f@_a-z~]|%[0-9a-f][0-9a-f])*)?)?
     (?:\x23(?:[!\x24&-;=\x3f@_a-z~]|%[0-9a-f][0-9a-f])*)?}xi
```

Following example contains right-recursion:

```ruby
  decimal = <<- End
    s0 = n0 s0 / n1 s2 / n2 s1 / ""
    s1 = n0 s1 / n1 s0 / n2 s2
    s2 = n0 s2 / n1 s1 / n2 s0
    n0 = "0" / "3" / "6" / "9"
    n1 = "1" / "4" / "7"
    n2 = "2" / "5" / "8"
  End
  pp ABNF.regexp_tree(decimal)
```

The above ABNF description represents decimal numbers
which are multiples of 3 and the result is follows:

```ruby
  %r{(?:[0369]|
        [147](?:[0369]|[147][0369]*[258])*(?:[147][0369]*[147]|[258])|
        [258][0369]*
        (?:[147]|
           [258](?:[0369]|[147][0369]*[258])*(?:[147][0369]*[147]|[258])))*}xi
```

A converted regexp can be used to match in place as:

```ruby
  ipv6 = <<- End
    IPv6address = "::"                  /
          7( hex4 ":" )          hex4   /
        1*8( hex4 ":" )      ":"        /
          7( hex4 ":" )    ( ":" hex4 ) /
          6( hex4 ":" ) 1*2( ":" hex4 ) /
          5( hex4 ":" ) 1*3( ":" hex4 ) /
          4( hex4 ":" ) 1*4( ":" hex4 ) /
          3( hex4 ":" ) 1*5( ":" hex4 ) /
          2( hex4 ":" ) 1*6( ":" hex4 ) /
           ( hex4 ":" ) 1*7( ":" hex4 ) /
                  ":"   1*8( ":" hex4 ) /
          6( hex4 ":" )                     IPv4address /
          6( hex4 ":" ) ":"                 IPv4address /
          5( hex4 ":" ) ":" 0*1( hex4 ":" ) IPv4address /
          4( hex4 ":" ) ":" 0*2( hex4 ":" ) IPv4address /
          3( hex4 ":" ) ":" 0*3( hex4 ":" ) IPv4address /
          2( hex4 ":" ) ":" 0*4( hex4 ":" ) IPv4address /
           ( hex4 ":" ) ":" 0*5( hex4 ":" ) IPv4address /
                  "::"      0*6( hex4 ":" ) IPv4address
    IPv4address = 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT
    hex4    = 1*4HEXDIG
  End
  p /\A#{ABNF.regexp(ipv6)}\z/o =~ "::13.1.68.3"
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
