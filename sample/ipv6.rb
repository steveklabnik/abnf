require 'abnf'

# IPv6 [RFC2373]
# Note that this ABNF description is wrong: e.g. it doesn't match to "::13.1.68.3".
p ABNF.regexp(<<-'End')
  IPv6address = hexpart [ ":" IPv4address ]
  IPv4address = 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT
  hexpart = hexseq | hexseq "::" [ hexseq ] | "::" [ hexseq ]
  hexseq  = hex4 *( ":" hex4)
  hex4    = 1*4HEXDIG
End
