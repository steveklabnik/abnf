# RFC 2234
class Parser
rule
  rulelist	:		{ result = ABNF.new(@parent) }
          	| rulelist rule	{ result.add_rule(*val[1]) }

  rule	: defname assign alternation	{ result = [val[0], val[2]] }

  alternation	: concatenation
  		| alternation altop concatenation	{ result = Alternation.create(val[0], val[2]) }

  concatenation	: repetition
  		| concatenation repetition	{ result = Concatenation.create(val[0], val[1]) }

  repetition	: element
		| repeat element	{ result = Repetition.new(val[1], *val[0]) }

  repeat	: repop		{ result = [0, nil] }
		| repop int	{ result = [0, val[1]] }
  		| int		{ result = [val[0], val[0]] }
		| int repop	{ result = [val[0], nil] }
		| int repop int	{ result = [val[0], val[2]] }

  element	: name	{ result = RuleName.new(val[0]) }
  		| lparen alternation rparen	{ result = val[1] }
		| lbracket alternation rbracket	{ result = Repetition.new(val[1], 0, 1) }
		| val
end

---- header

require 'regen'

class ABNF
  def ABNF.regexp(desc, name=nil)
    Parser.new.parse(desc).to_regexp(name)
  end

  def initialize(defs=CoreRules)
    @firstname = nil
    @rule = {}
    defs.each_rule {|name, elements| @rule[name] = elements} if defs
  end

  def add_rule(name, elements)
    @firstname = name unless @firstname
    if @rule.include? name
      @rule[name] = Alternation.create(@rule[name], elements)
    else
      @rule[name] = elements
    end
  end

  def each_rule
    @rule.each {|v|
      yield v
    }
  end

  def to_regexp(name=nil)
    name ||= @firstname
    order_cell = [0]
    order_hash = {}
    node_stack = []
    components = []
    order_hash.default = -1

    collect_defs(name, order_cell, order_hash, node_stack, components)

    rule = []
    components.each {|ns|
      # This condition is too restrictive, I think.
      # A contribution to relax it is welcome.
      if ns.length != 1
	raise ABNF::Error.new("cannot convert mutually recusive rules to regexp: #{ns.join(', ')}")
      end

      n = ns[0]
      e = @rule[n]

      # Convert a recursive rule to non-recursive rule if possible.
      # This conversion is *not* perfect.
      # It may fail even if possible.
      # More work (survey) is needed.
      if Alternation === e
	left = []
	middle = []
	right = []
        e.es.each {|branch|
	  if Concatenation === branch
	    if branch.es.empty?
	      middle << branch
	    else
	      if RuleName === branch.es.first && branch.es.first.name == n
	        right << Concatenation.create(*branch.es[1..-1])
	      elsif RuleName === branch.es.last && branch.es.last.name == n
	        left << Concatenation.create(*branch.es[0...-1])
	      else
	        middle << branch
	      end
	    end
	  else
	    middle << branch
	  end
	}
	es = []
	es << Repetition.create(Alternation.create(*left)) unless left.empty?
	es << Alternation.create(*middle)
	es << Repetition.create(Alternation.create(*right)) unless right.empty?
	e = Concatenation.create(*es)
      end

      if e.refnames.include? n
	raise ABNF::Error.new("too complex to convert to regexp: #{n}")
      end

      rule << [n, e]
    }

    env = {}
    rule.each {|n, e|
      env[n] = e.to_regexp(env)
    }

    env[name].to_s
  end

  class Error < StandardError
  end

  def collect_defs(name, order_cell, order_hash, node_stack, components)
    order = (order_cell[0] += 1)
    reachable_minimum_order = order
    order_hash[name] = order
    stack_length = node_stack.length
    node_stack << name

    elements = @rule[name]
    raise ABNF::Error.new("no rule for #{name}") unless elements
    elements.refnames.each {|nextname|
      nextorder = order_hash[nextname]
      if nextorder != -1
        if nextorder < reachable_minimum_order
          reachable_minimum_order = nextorder
        end
      else
        sub_minimum_order = collect_defs(nextname, order_cell, order_hash, node_stack, components)
        if sub_minimum_order < reachable_minimum_order
          reachable_minimum_order = sub_minimum_order
        end
      end
    }

    if order == reachable_minimum_order
      scc = node_stack[stack_length .. -1]
      node_stack[stack_length .. -1] = []
      components << scc
      scc.each {|n|
        order_hash[n] = @rule.size
      }
    end
    return reachable_minimum_order
  end

  class Alternation
    def Alternation.create(*es)
      es2 = []
      until es.empty?
        if Alternation === es.last
	  es[-1, 1] = es.last.es
	else
	  es2 << es.pop
	end
      end
      es2.reverse!
      if es2.length == 1
        es2[0]
      else
	Alternation.new(*es2)
      end
    end

    def initialize(*es)
      @es = es
    end
    attr_reader :es

    def refnames
      ns = []
      @es.each {|e| ns |= e.refnames}
      ns
    end

    def to_regexp(env)
      r = ReGen::Alt.new
      @es.each {|e| r += e.to_regexp(env)}
      r
    end
  end

  class Concatenation
    def Concatenation.create(*es)
      es2 = []
      until es.empty?
        if Concatenation === es.last
	  es[-1, 1] = es.last.es
	elsif Alternation === es.last && es.last.es.length == 0
	  es.last
	else
	  es2 << es.pop
	end
      end
      es2.reverse!
      if es2.length == 1
        es2[0]
      else
	Concatenation.new(*es2)
      end
    end

    def initialize(*es)
      @es = es
    end
    attr_reader :es

    def refnames
      ns = []
      @es.each {|e| ns |= e.refnames}
      ns
    end

    def to_regexp(env)
      r = ReGen::Con.new
      @es.each {|e| r *= e.to_regexp(env)}
      r
    end
  end

  class Repetition
    def Repetition.create(e, m=0, n=nil)
      if Concatenation === e && e.es.length == 0
        e
      elsif Alternation === e && e.es.length == 0
        Concatenation.new
      else
	Repetition.new(e, m, n)
      end
    end

    def initialize(e, m=0, n=nil)
      @e = e
      @m = m
      @n = n
    end

    def refnames
      @e.refnames
    end

    def to_regexp(env)
      @e.to_regexp(env).closure(@m, @n)
    end
  end

  class RuleName
    def initialize(name)
      @name = name
    end
    attr_reader :name

    def refnames
      [@name]
    end

    def to_regexp(env)
      env[@name]
    end
  end

  class NumRange
    def initialize(m, n=m)
      @m = m
      @n = n
    end

    def refnames
      []
    end

    def to_regexp(env)
      ReGen[@m..@n]
    end
  end

  class ProseVal
    def initialize(prose)
      @prose = prose
    end

    def refnames
      []
    end
  end

---- inner

  def initialize(parent=CoreRules)
    @parent = parent
  end

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
	  yield :name, (t = $&)
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
	      es << Alternation.create(NumRange.new(b), NumRange.new(b2))
	    when ?a..?z
	      b2 = b - ?a + ?A
	      es << Alternation.create(NumRange.new(b), NumRange.new(b2))
	    else
	      es << NumRange.new(b)
	    end
	  }
	  yield :val, Concatenation.create(*es)
	when /\A%b([01]+)-([01]+)/
	  t = $&
	  yield :val, NumRange.new(binval($1), binval($2))
	when /\A%b[01]+(?:\.[01]+)*/
	  es = []
	  (t = $&).scan(/[0-1]+/) {|v| es << NumRange.new(binval(v))}
	  yield :val, Concatenation.create(*es)
	when /\A%d([0-9]+)-([0-9]+)/
	  t = $&
	  yield :val, NumRange.new($1.to_i, $2.to_i)
	when /\A%d[0-9]+(?:\.[0-9]+)*/
	  es = []
	  (t = $&).scan(/[0-9]+/) {|v| es << NumRange.new(v.to_i)}
	  yield :val, Concatenation.create(*es)
	when /\A%x([0-9A-Fa-f]+)-([0-9A-Fa-f]+)/
	  t = $&
	  yield :val, NumRange.new($1.hex, $2.hex)
	when /\A%x[0-9A-Fa-f]+(?:\.[0-9A-Fa-f]+)*/
	  es = []
	  (t = $&).scan(/[0-9A-Fa-f]+/) {|v| es << NumRange.new(v.hex)}
	  yield :val, Concatenation.create(*es)
	when /\A<([\x20-\x3D\x3F-\x7E]*)>/
	  yield :val, (t = $&)
	else
	  raise ScanError.new(line)
	end
	line[0, t.length] = ''
      end
    }
    yield false, false
  end

  def binval(bin)
    eval "0b#{bin}" # shouldn't use eval.
  end

  class ScanError < StandardError
  end

---- footer

  CoreRules = Parser.new(nil).parse(<<'End') # taken from RFC 2234
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

=end
