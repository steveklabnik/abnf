require 'abnf'

p /\A#{ABNF.regexp <<'End'}\z/o =~ "::13.1.68.3"
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

