# RFC 2234
class ABNFParser
rule
  rulelist	:		{ result = Grammar.new; result.import(@parent) }
          	| rulelist rule	{ @names << val[1][0]
		                  result[val[1][0]] = val[1][1].simplify }

  rule	: defname assign alt	{ result = [val[0], val[2]] }

  alt	: con
	| alt altop con	{ result = val[0] + val[2] }

  con	: rep
	| con rep	{ result = val[0] * val[1] }

  rep	: element
	| repeat element	{ result = val[1].rep(*val[0]) }

  repeat	: repop		{ result = [0, nil] }
		| repop int	{ result = [0, val[1]] }
  		| int		{ result = [val[0], val[0]] }
		| int repop	{ result = [val[0], nil] }
		| int repop int	{ result = [val[0], val[2]] }

  element	: name	{ result = Grammar::RuleRef.new(val[0]) }
  		| lparen alt rparen	{ result = val[1] }
		| lbracket alt rbracket	{ result = val[1].rep(0, 1) }
		| val
end

---- header

require 'grammar'

module ABNF
  def ABNF.regexp(desc, name=nil)
    parser = ABNFParser.new
    parser.parse(desc).regexp(name || parser.names.first)
  end

---- inner

  def initialize(parent=CoreRules)
    @parent = parent || Grammar.new
    @names = []
  end
  attr_reader :names

  def parse(input)
    @input = input
    yyparse self, :scan
  end

  def scan
    prev = nil
    scan1 {|v|
      if prev
	if prev[0] == :name && v[0] == :assign
	  yield :defname, prev[1]
	else
	  yield prev
	end
      end
      prev = v
    }
    yield prev
  end

  def scan1
    @input.each_line {|line|
      until line.empty?
        case line
	when /\A[ \t\r\n]+/
	  t = $&
	when /\A;/
	  t = line
	when /\A[A-Za-z][A-Za-z0-9\-_]*/ # _ is not permitted by ABNF
	  yield :name, (t = $&).intern
	when /\A=\/?/
	  yield :assign, (t = $&) # | is not permitted by ABNF
	when /\A[\/|]/
	  yield :altop, (t = $&)
	when /\A\*/
	  yield :repop, (t = $&)
	when /\A\(/
	  yield :lparen, (t = $&)
	when /\A\)/
	  yield :rparen, (t = $&)
	when /\A\[/
	  yield :lbracket, (t = $&)
	when /\A\]/
	  yield :rbracket, (t = $&)
	when /\A\d+/
	  yield :int, (t = $&).to_i
	when /\A"([ !#-~]*)"/
	  es = []
	  (t = $&)[1...-1].each_byte {|b|
	    case b
	    when ?A..?Z
	      b2 = b - ?A + ?a
	      es << Grammar::Term.new(NatSet.create(b, b2))
	    when ?a..?z
	      b2 = b - ?a + ?A
	      es << Grammar::Term.new(NatSet.create(b, b2))
	    else
	      es << Grammar::Term.new(NatSet.create(b))
	    end
	  }
	  yield :val, Grammar::Con.new(*es)
	when /\A%b([01]+)-([01]+)/
	  t = $&
	  yield :val, Grammar::Term.new(NatSet.create(binval($1)..binval($2)))
	when /\A%b[01]+(?:\.[01]+)*/
	  es = []
	  (t = $&).scan(/[0-1]+/) {|v|
	    es << Grammar::Term.new(NatSet.create(binval(v)))
	  }
	  yield :val, Grammar::Con.new(*es)
	when /\A%d([0-9]+)-([0-9]+)/
	  t = $&
	  yield :val, Grammar::Term.new(NatSet.create($1.to_i..$2.to_i))
	when /\A%d[0-9]+(?:\.[0-9]+)*/
	  es = []
	  (t = $&).scan(/[0-9]+/) {|v|
	    es << Grammar::Term.new(NatSet.create(v.to_i))
	  }
	  yield :val, Grammar::Con.new(*es)
	when /\A%x([0-9A-Fa-f]+)-([0-9A-Fa-f]+)/
	  t = $&
	  yield :val, Grammar::Term.new(NatSet.create($1.hex..$2.hex))
	when /\A%x[0-9A-Fa-f]+(?:\.[0-9A-Fa-f]+)*/
	  es = []
	  (t = $&).scan(/[0-9A-Fa-f]+/) {|v|
	    es << Grammar::Term.new(NatSet.create(v.hex))
	  }
	  yield :val, Grammar::Con.new(*es)
	when /\A<([\x20-\x3D\x3F-\x7E]*)>/
	  raise ScanError.new "prose-val is not supported: #{$&}"
	else
	  raise ScanError.new line
	end
	line[0, t.length] = ''
      end
    }
    yield false, false
  end

  def binval(bin)
    Integer "0b#{bin}"
  end

  class ScanError < StandardError
  end

---- footer

  CoreRules = ABNFParser.new(nil).parse(<<'End') # taken from RFC 2234
        ALPHA          =  %x41-5A / %x61-7A   ; A-Z / a-z

        BIT            =  "0" / "1"

        CHAR           =  %x01-7F
                               ; any 7-bit US-ASCII character, excluding NUL

        CR             =  %x0D
                               ; carriage return

        CRLF           =  CR LF
                               ; Internet standard newline

        CTL            =  %x00-1F / %x7F
                               ; controls

        DIGIT          =  %x30-39
                               ; 0-9

        DQUOTE         =  %x22
                               ; " (Double Quote)

        HEXDIG         =  DIGIT / "A" / "B" / "C" / "D" / "E" / "F"

        HTAB           =  %x09
                               ; horizontal tab

        LF             =  %x0A
                               ; linefeed

        LWSP           =  *(WSP / CRLF WSP)
                               ; linear white space (past newline)

        OCTET          =  %x00-FF
                               ; 8 bits of data

        SP             =  %x20

        VCHAR          =  %x21-7E
                               ; visible (printing) characters

        WSP            =  SP / HTAB
                               ; white space
End

end

=begin

= ABNF

== Usage

# IPv6 [RFC2373]
p %r{\A#{ABNF.regexp <<'End'
  IPv6address = hexpart [ ":" IPv4address ]
  IPv4address = 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT
  hexpart = hexseq | hexseq "::" [ hexseq ] | "::" [ hexseq ]
  hexseq  = hex4 *( ":" hex4)
  hex4    = 1*4HEXDIG
End
}\z}o =~ "FEDC:BA98:7654:3210:FEDC:BA98:7654:3210"

Note that this is wrong because it doesn't match to "::13.1.68.3".

# URI-reference [RFC2396]
p %r{\A#{ABNF.regexp <<'End'
      URI-reference = [ absoluteURI | relativeURI ] [ "#" fragment ]
      absoluteURI   = scheme ":" ( hier_part | opaque_part )
      relativeURI   = ( net_path | abs_path | rel_path ) [ "?" query ]

      hier_part     = ( net_path | abs_path ) [ "?" query ]
      opaque_part   = uric_no_slash *uric

      uric_no_slash = escaped | unreserved | ";" | "?" | ":" | "@" |
                      "&" | "=" | "+" | "$" | ","

      net_path      = "//" authority [ abs_path ]
      abs_path      = "/"  path_segments
      rel_path      = rel_segment [ abs_path ]

      rel_segment   = 1*( escaped | unreserved |
                          ";" | "@" | "&" | "=" | "+" | "$" | "," )

      scheme        = alpha *( alpha | digit | "+" | "-" | "." )

      authority     = server | reg_name

      reg_name      = 1*( escaped | unreserved | "$" | "," |
                          ";" | ":" | "@" | "&" | "=" | "+" )

      server        = [ [ userinfo "@" ] hostport ]
      userinfo      = *( escaped | unreserved |
                         ";" | ":" | "&" | "=" | "+" | "$" | "," )

      hostport      = host [ ":" port ]
      host          = hostname | IPv4address
      hostname      = *( domainlabel "." ) toplabel [ "." ]
      domainlabel   = alphanum | alphanum *( alphanum | "-" ) alphanum
      toplabel      = alpha | alpha *( alphanum | "-" ) alphanum
      IPv4address   = 1*digit "." 1*digit "." 1*digit "." 1*digit
      port          = *digit

      path          = [ abs_path | opaque_part ]
      path_segments = segment *( "/" segment )
      segment       = *pchar *( ";" param )
      param         = *pchar
      pchar         = escaped | unreserved |
                      ":" | "@" | "&" | "=" | "+" | "$" | ","

      query         = *uric

      fragment      = *uric

      uric          = reserved | unreserved | escaped
      reserved      = ";" | "/" | "?" | ":" | "@" | "&" | "=" | "+" |
                      "$" | ","
      unreserved    = alphanum | mark
      mark          = "-" | "_" | "." | "!" | "~" | "*" | "'" |
                      "(" | ")"

      escaped       = "%" hex hex
      hex           = digit | "A" | "B" | "C" | "D" | "E" | "F" |
                              "a" | "b" | "c" | "d" | "e" | "f"

      alphanum      = alpha | digit
      alpha         = lowalpha | upalpha

      lowalpha = "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" |
                 "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" |
                 "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
      upalpha  = "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" |
                 "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" |
                 "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z"
      digit    = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" |
                 "8" | "9"
End
}\z}o

== ABNF class

=== class methods

--- regexp(abnf_description[, start_symbol])
    converts ((|abnf_description|)) to a regular expression corresponding with ((|start_symbol|)).

    If ((|start_symbol|)) is not specified, first symbol in ((|abnf_description|)) is used.

=end
