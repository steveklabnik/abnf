require 'abnf'
require 'pp'

# IPv6 [RFC2373]
# Note that this ABNF description is wrong: e.g. it doesn't match to "::13.1.68.3".
wrong = ABNF.regexp_tree(<<-'End')
  IPv6address = hexpart [ ":" IPv4address ]
  IPv4address = 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT
  hexpart = hexseq | hexseq "::" [ hexseq ] | "::" [ hexseq ]
  hexseq  = hex4 *( ":" hex4)
  hex4    = 1*4HEXDIG
End

corrected = ABNF.regexp_tree(<<-'End')
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

pp wrong
pp corrected

p /\A#{wrong}\z/o =~ "::13.1.68.3"
p /\A#{corrected}\z/o =~ "::13.1.68.3"
