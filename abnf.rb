=begin
= ABNF

convert ABNF to Regexp.

== Example

  # IPv6 [RFC2373]
  p %r{\A#{ABNF.regexp <<'End'}\z}o =~ "FEDC:BA98:7654:3210:FEDC:BA98:7654:3210"
    IPv6address = hexpart [ ":" IPv4address ]
    IPv4address = 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT
    hexpart = hexseq | hexseq "::" [ hexseq ] | "::" [ hexseq ]
    hexseq  = hex4 *( ":" hex4)
    hex4    = 1*4HEXDIG
  End

Note that this is wrong because it doesn't match to "::13.1.68.3".

  # URI-reference [RFC2396]
  p %r{\A#{ABNF.regexp <<'End'}\z}o
        URI-reference = [ absoluteURI | relativeURI ] [ "#" fragment ]
        ...
        digit    = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" |
                   "8" | "9"
  End

== ABNF

=== class methods

--- ABNF.regexp(abnf_description, start_symbol=nil)
    converts ((|abnf_description|)) to a Regexp object corresponding with
    ((|start_symbol|)).

    If ((|start_symbol|)) is not specified, first symbol in
    ((|abnf_description|)) is used.

--- ABNF.regexp_tree(abnf_description, start_symbol=nil)
    converts ((|abnf_description|)) to a ((<RegexpTree|URL:regexptree.html>)) object corresponding with
    ((|start_symbol|)).

= Note

* Wrong ABNF description produces wrong regexp.

=end

require 'abnf/abnf'
require 'abnf/parser'
require 'abnf/corerules'
require 'abnf/regexp'
