=begin
= regen.rb - Regexp Generator

== Usage

  /#{ReGen.str("aaa") * ReGen.str("bbb")}/o

  %r{#{
    ReGen.str("0").closure.name(:part) *
    ReGen.ref(:part).positive_closure
  }}o

  # IPv6 [RFC2373]
  %r{#{
    hex4 = ReGen::HEXDIG ** (1..4)
    hexseq = hex4 * (ReGen[":"] * hex4).closure
    hexpart = hexseq |
              hexseq * "::" * [ hexseq ] |
	      ReGen["::"] * [ hexseq ]
    ipv6prefix  = hexpart * "/" * ReGen::Digit ** (1..2)
    ipv4address = ReGen::Digit ** (1..3) * "." *
                  ReGen::Digit ** (1..3) * "." *
		  ReGen::Digit ** (1..3) * "." *
		  ReGen::Digit ** (1..3)
    ipv6address = hexpart * [ ReGen[":"] * ipv4address ]
    ReGen::BOS * ipv6address * ReGen::EOS
  }}o

  Note that this is wrong because it doesn't match to "::13.1.68.3".

  # URI-reference [RFC2396]
  %r{#{
    digit = ReGen::NoElt |
      "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
    upalpha = ReGen::NoElt |
      "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" |
      "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" |
      "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z"
    lowalpha = ReGen::NoElt |
      "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" |
      "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" |
      "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
    alpha = lowalpha | upalpha
    alphanum = alpha | digit
    hex = digit | "A" | "B" | "C" | "D" | "E" | "F" |
		  "a" | "b" | "c" | "d" | "e" | "f"
    escaped = ReGen["%"] * hex * hex
    mark = ReGen::NoElt | "-" | "_" | "." | "!" | "~" | "*" | "'" | "(" | ")"
    unreserved = alphanum | mark
    reserved = ReGen::NoElt |
      ";" | "/" | "?" | ":" | "@" | "&" | "=" | "+" | "$" | ","
    uric = reserved | unreserved | escaped
    fragment = uric.closure
    query = uric.closure
    pchar = escaped | unreserved | ":" | "@" | "&" | "=" | "+" | "$" | ","
    param = pchar.closure
    segment = pchar.closure * (ReGen[";"] * param).closure
    path_segments = segment * (ReGen["/"] * segment).closure
    port = digit.closure
    ipv4address = digit.positive_closure * "." *
		  digit.positive_closure * "." *
		  digit.positive_closure * "." *
		  digit.positive_closure
    toplabel = alpha | alpha * (alphanum | "-").closure * alphanum
    domainlabel = alphanum | alphanum * (alphanum | "-").closure * alphanum
    hostname = (domainlabel * ".").closure * toplabel * [ ReGen["."] ]
    host = hostname | ipv4address
    hostport = host * [ ReGen[":"] * port ]
    userinfo = ( escaped | unreserved |
      ";" | ":" | "&" | "=" | "+" | "$" | "," ).closure
    server = ( ( userinfo * "@" ).optional * hostport ).optional
    reg_name = ( escaped | unreserved |
      "$" | "," | ";" | ":" | "@" | "&" | "=" | "+" ).positive_closure
    authority = server | reg_name
    scheme = alpha * ( alpha | digit | "+" | "-" | "." ).closure
    rel_segment = ( escaped | unreserved |
      ";" | "@" | "&" | "=" | "+" | "$" | "," ).positive_closure
    abs_path = ReGen["/"] * path_segments
    rel_path = rel_segment * [ abs_path ]
    net_path = ReGen["//"] * authority * [ abs_path ]
    uric_no_slash = escaped | unreserved |
      ";" | "?" | ":" | "@" | "&" | "=" | "+" | "$" | ","
    opaque_part = uric_no_slash * uric.closure
    path = ( abs_path | opaque_part ).optional
    hier_part = ( net_path | abs_path ) * [ ReGen["?"] * query ]
    relativeURI = ( net_path | abs_path | rel_path ) * [ ReGen["?"] * query ]
    absoluteURI = scheme * ":" * ( hier_part | opaque_part )
    uri_reference = ( absoluteURI | relativeURI ).optional *
                    [ ReGen["#"] * fragment ]
    ReGen::BOS * uri_reference * ReGen::EOS
  }}o

=end

module ReGen
  def ReGen.create(arg)
    ReGen[arg]
  end

  def ReGen.[](*args)
    if args.length == 1 && ReGen === args[0]
      args[0]
    elsif args.length == 1 && String === args[0]
      ReGen.str(*args)
    elsif args.length == 1 && Array === args[0] && args[0].length == 1
      ReGen[args[0][0]].optional
    else
      ReGen.elt(*args)
    end
  end

  def ReGen.str(str)
    r = Con.new
    str.each_byte {|e|
      r = r * Elt.create(e)
    }
    r
  end

  def ReGen.elt(*es)
    Elt.create(*es)
  end

  def ReGen.ref(n)
    Ref.new(n)
  end

  def to_regexp
    Regexp.new(self.to_s)
  end

  def to_s
    construct(create_env({}))
  end

  def elt?
    false
  end

  def alt(other)
    other = ReGen.create(other)
    Alt.new(self, other)
  end

  def +(other)
    other = ReGen.create(other)
    alt(other)
  end
  alias | +

  # Once / is aliased to + because ABNF but it is removed later
  # because operator precedence problem.
  # In ABNF, a b / c d is interpreted as (a b) / (c d).
  # But a * b / c * d is interpreted as ((a * b) / c) * d in Ruby expression.
  # This inconsistency confuse programmers.  Use | or + instead of /.
  #
  #alias / +

  def con(other)
    other = ReGen.create(other)
    Con.new(self, other)
  end

  def *(other)
    other = ReGen.create(other)
    con(other)
  end

  def **(n)
    if Range === n
      if n.exclude_end?
	Rep.new(self, n.begin, n.end-1)
      else
	Rep.new(self, n.begin, n.end)
      end
    else
      Rep.new(self, n, n)
    end
  end


  def closure(m=0, n=nil, nongreedy=false)
    Rep.new(self, m, n, nongreedy)
  end

  def closure_nongreedy
    Rep.new(self, 0, nil, true)
  end

  def positive_closure
    Rep.new(self, 1, nil)
  end

  def positive_closure_nongreedy
    Rep.new(self, 1, nil, true)
  end

  def optional
    Rep.new(self, 0, 1)
  end

  def optional_nongreedy
    Rep.new(self, 0, 1, true)
  end

  def name(n)
    Name.new(self, n)
  end

  def lookahead(r, neg=false)
    LookAhead.new(r, neg)
  end

  def case_insensitive
    Option.new(self, ?i)
  end

  class Alt
    include ReGen

    def initialize(*rs)
      @rs = rs
    end
    attr_reader :rs

    def alt(other)
      other = ReGen.create(other)
      if @rs.empty?
        other
      elsif Alt === other
        Alt.new(*(@rs + other.rs))
      elsif Elt === other && !@rs.empty? && Elt === @rs[-1]
        Alt.new(*(@rs[0...-1] + [@rs[-1] + other]))
      else
        Alt.new(*(@rs + [other]))
      end
    end

    def create_env(env)
      rs.each {|r| env = r.create_env(env)}
      env
    end

    def construct(env)
      "(?:#{@rs.map {|r| r.construct(env)}.join '|'})"
    end
  end

  class Con
    include ReGen

    def initialize(*rs)
      @rs = rs
    end
    attr_reader :rs

    def con(other)
      other = ReGen.create(other)
      if @rs.empty?
        other
      elsif Con === other
        Con.new(*(@rs + other.rs))
      else
        Con.new(*(@rs + [other]))
      end
    end

    def create_env(env)
      rs.each {|r| env = r.create_env(env)}
      env
    end

    def construct(env)
      "(?:#{@rs.map {|r| r.construct(env)}.join})"
    end
  end

  class Rep
    include ReGen

    def initialize(r, m=0, n=nil, nongreedy=false)
      @r = r
      @m = m
      @n = n
      @nongreedy = nongreedy
    end

    def suffix
      nongreedy_mark = @nongreedy ? '?' : ''
      if @m == 0 && @n == nil
        "*#{nongreedy_mark}"
      elsif @m == 1 && @n == nil
        "+#{nongreedy_mark}"
      elsif @m == 0 && @n == 1
        "?#{nongreedy_mark}"
      elsif @m == @n
        "{#{@m}}#{nongreedy_mark}"
      else
        "{#{@m},#{@n}}#{nongreedy_mark}"
      end
    end

    def create_env(env)
      @r.create_env(env)
    end

    def construct(env)
      "(?:#{@r.construct(env)}#{suffix})"
    end
  end

  class Special
    include ReGen

    def initialize(r)
      @r = r
    end

    def create_env(env)
      env
    end

    def construct(env)
      @r
    end
  end

  BOL = Special.new '^'
  EOL = Special.new '$'
  BOS = Special.new '\A'
  EOS = Special.new '\z'
  EOSNL = Special.new '\Z'
  WordBoundary = Special.new '\b'
  NonWordBoundary = Special.new '\B'
  PrevMatchEnd = Special.new '\G'

  class Elt
    def Elt.create(*es)
      r = NoElt
      es.each {|e|
	if Range === e
	  if e.exclude_end?
	    r += Elt.new(e.begin, e.end)
	  else
	    r += Elt.new(e.begin, e.end+1)
	  end
	else
	  r += Elt.new(e, e+1)
	end
      }
      r
    end

    include ReGen

    def initialize(*es)
      @es = es
    end
    attr_reader :es

    def empty?
      @es.empty?
    end

    def full?
      @es == [0]
    end

    def open?
      @es.length & 1 != 0
    end

    def single?
      if @es.length == 2 && @es[0] == @es[1] - 1
        @es[0]
      else
        nil
      end
    end

    def elt?
      true
    end

    def to_elt
      self
    end

    def merge(other)
      es1 = @es.dup
      es2 = other.es.dup
      es0 = []
      bool1 = bool2 = bool0 = false
      s = 0
      while !es1.empty? || !es2.empty?
	if es2.empty? || !es1.empty? && es1[0] < es2[0]
	  e = es1.shift
	  if s < e && bool0 != yield(bool1, bool2)
	    es0 << s
	    bool0 = !bool0
	  end
	  s = e
	  bool1 = !bool1
	elsif es1.empty? || !es2.empty? && es1[0] > es2[0]
	  e = es2.shift
	  if s < e && bool0 != yield(bool1, bool2)
	    es0 << s
	    bool0 = !bool0
	  end
	  s = e
	  bool2 = !bool2
	else
	  e = es1.shift
	  es2.shift
	  if s < e && bool0 != yield(bool1, bool2)
	    es0 << s
	    bool0 = !bool0
	  end
	  s = e
	  bool1 = !bool1
	  bool2 = !bool2
	end
      end
      if bool0 != yield(bool1, bool2)
	es0 << s
      end
      es0
    end

    def alt(other)
      other = ReGen.create(other)
      if empty?
        other
      elsif other.elt?
        Elt.new(*merge(other.to_elt) {|a, b| a || b})
      else
        super
      end
    end

    def -(other)
      other = ReGen.create(other)
      Elt.new(*merge(other.to_elt) {|a, b| a && !b})
    end

    def -@
      if @es.empty?
        AnyElt
      elsif @es[0] == 0
        Elt.new(*@es[1..-1])
      else
        Elt.new(0, *@es)
      end
    end

    def &(other)
      other = ReGen.create(other)
      Elt.new(*merge(other.to_elt) {|a, b| a && b})
    end

    module ES
      Empty = []
      Full = [0]
      NL = [?\n, ?\n+1]
      NonNL = [0] + NL
      Word = [?0, ?9+1, ?A, ?Z+1, ?_, ?_+1, ?a, ?z+1]
      NonWord = [0] + Word
      Space = [?t, ?\t+1, ?\n, ?\n+1, ?\f, ?\r+1, ?\ , ?\ +1]
      NonSpace = [0] + Space
      Digit = [?0, ?9+1]
      NonDigit = [0] + Digit
    end

    def create_env(env)
      env
    end

    def construct(env)
      if e = single?
	return Regexp.quote sprintf("%c", e)
      end

      case @es
      when ES::Empty
        '[^\0-\377]'
      when ES::Full
        '[\0-\377]'
      when ES::NL
        '\n'
      when ES::NonNL
        '.'
      when ES::Word
        '\w'
      when ES::NonWord
        '\W'
      when ES::Space
        '\s'
      when ES::NonSpace
        '\S'
      when ES::Digit
        '\d'
      when ES::NonDigit
        '\D'
      else
	es = @es.dup
	if open?
	  neg_mark = '^'
	  if es[0] == 0
	    es.shift
	  else
	    es.unshift 0
	  end
	else
	  neg_mark = ''
	end

	r = ''
	until es.empty?
	  if es[0] + 1 == es[1]
	    r << encode_elt(es[0])
	  elsif es[0] + 2 == es[1]
	    r << encode_elt(es[0]) << encode_elt(es[1] - 1)
	  else
	    r << encode_elt(es[0]) << '-' << encode_elt(es[1] - 1)
	  end
	  es.shift
	  es.shift
	end

	"[#{neg_mark}#{r}]"
      end
    end

    def encode_elt(e)
      case e
      when ?0..?9, ?A..?Z, ?a..?z, ?_
	sprintf("%c", e)
      else
	sprintf("\\x%02x", e)
      end
    end
  end

  NoElt = Elt.new(*Elt::ES::Empty)
  AnyElt = Elt.new(*Elt::ES::Full)
  NL = Elt.new(*Elt::ES::NL)
  NonNL = Elt.new(*Elt::ES::NonNL)
  Word = Elt.new(*Elt::ES::Word)
  NonWord = Elt.new(*Elt::ES::NonWord)
  Space = Elt.new(*Elt::ES::Space)
  NonSpace = Elt.new(*Elt::ES::NonSpace)
  Digit = Elt.new(*Elt::ES::Digit)
  NonDigit = Elt.new(*Elt::ES::NonDigit)

  class Name
    include ReGen

    def initialize(r, n)
      @r = r
      @name = n
    end

    def create_env(env)
      if env.include? @name
        raise StandardError.new("backref name conflict: #{@name}")
      else
	env[@name] = env.size + 1
	env = @r.create_env(env)
      end
      env
    end

    def construct(env)
      "(#{@r.construct(env)})"
    end
  end

  class Ref
    include ReGen

    def initialize(n)
      @name = n
    end

    def create_env(env)
      env
    end

    def construct(env)
      if env.include? @name
        "\\#{env[@name]}"
      else
        raise StandardError.new("backref name not defined: #{@name}")
      end
    end

  end

  class LookAhead
    include ReGen

    def initialize(r, neg=false)
      @r = r
      @neg = neg
    end

    def create_env(env)
      @r.create_env(env)
    end

    def construct(env)
      "(?#{neg ? '!' : '='}#{@r.construct(env)})"
    end
  end

  class SuppressBacktrack
    include ReGen

    def initialize(r)
      @r = r
    end

    def create_env(env)
      @r.create_env(env)
    end

    def construct(env)
      "(?>#{@r.construct(env)})"
    end
  end

  class Option
    include ReGen

    def initialize(r, *opts)
      @r = r
      @opts = opts
    end

    def create_env(env)
      @r.create_env(env)
    end

    def construct(env)
      opt = ''
      @opts.each {|o| opt << sprintf("%c", o) if 0 < o}
      opt << '-'
      @opts.each {|o| opt << sprintf("%c", o) if 0 > o}
      opt.sub!(/-\z/, '')
      "(?#{opt}:#{@r.construct(env)})"
    end
  end

  # RFC2234 (ABNF) core rules
  ALPHA = ReGen[?A..?Z, ?a..?z]
  BIT = ReGen[?0, ?1]
  CHAR = ReGen[?\x01..?\x7f]
  CR = ReGen[?\x0d]
  CRLF = ReGen["\x0d\x0a"]
  CTL = ReGen[?\x00..?\x1f, ?\x7f]
  DIGIT = ReGen[?0..?9]
  HEXDIG = ReGen[?0..?9, ?A..?F, ?a..?f] # Note that "..." is case insensitive in ABNF.
  HTAB = ReGen[?\x09]
  LF = ReGen[?\x0a]
  SP = ReGen[?\x20]
  WSP = SP | HTAB
  LWSP = (WSP | CRLF * WSP).closure
  OCTET = AnyElt
  VCHAR = ReGen[?\x21..?\x7e]
end
