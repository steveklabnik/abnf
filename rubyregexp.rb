require 'prettyprint'
require 'natset'

class RubyRegexp
  @curr_prec = 1
  def RubyRegexp.inherited(c)
    return if c.superclass != RubyRegexp
    c.const_set(:Prec, @curr_prec)
    @curr_prec += 1
  end

  def parenthesize(target)
    if target::Prec <= self.class::Prec
      self
    else
      Paren.new(self)
    end
  end

  def pretty_display(output=$>)
    PrettyPrint.format(output) {|out|
      out.group(3, '%r{', '}x') {
	pretty_format(out)
      }
    }
    output << "\n"
  end

  def inspect
    r = PrettyPrint.singleline_format('') {|out|
	  pretty_format(out)
	}
    if %r{/} =~ r
      "%r{#{r}}"
    else
      "/#{r}/"
    end
  end

  def to_s
    PrettyPrint.singleline_format('') {|out|
      pretty_format(out)
    }
  end

  def |(other)
    RubyRegexp.alt(self, other)
  end
  def RubyRegexp.alt(*rs)
    rs2 = []
    rs.each {|r|
      if Alt === r
	next if r.empty_set?
        rs2.concat r.rs
      elsif CharClass === r
	if r.empty_set?
	  next
        elsif CharClass === rs2.last
	  rs2[-1] = CharClass.new(rs2.last.natset + r.natset)
	else
	  rs2 << r
	end
      else
        rs2 << r
      end
    }
    case rs2.length
    when 0; EmptySet
    when 1; rs2.first
    else; Alt.new(rs2)
    end
  end
  class Alt < RubyRegexp
    def initialize(rs)
      @rs = rs
    end
    attr_reader :rs

    def empty_set?
      @rs.empty?
    end

    def pretty_format(out)
      if @rs.empty?
        out.text '(?!)'
      else
	out.group {
	  @rs.each_with_index {|r, i|
	    unless i == 0
	      out.text '|'
	      out.breakable ''
	    end
	    r.parenthesize(Alt).pretty_format(out)
	  }
	}
      end
    end
  end
  EmptySet = Alt.new([])

  def +(other)
    RubyRegexp.seq(self, other)
  end
  def RubyRegexp.seq(*rs)
    rs2 = []
    rs.each {|r|
      if Seq === r
	if r.empty_sequence?
	  next
	else
	  rs2.concat r.rs
	end
      elsif (Alt === r || CharClass === r) && r.empty_set?
        return EmptySet
      else
        rs2 << r
      end
    }
    case rs2.length
    when 0; EmptySequence
    when 1; rs2.first
    else; Seq.new(rs2)
    end
  end
  class Seq < RubyRegexp
    def initialize(rs)
      @rs = rs
    end
    attr_reader :rs

    def empty_sequence?
      @rs.empty?
    end

    def pretty_format(out)
      out.group {
	@rs.each_with_index {|r, i|
	  unless i == 0
	    out.group {out.breakable ''}
	  end
	  r.parenthesize(Seq).pretty_format(out)
	}
      }
    end
  end
  EmptySequence = Seq.new([])

  def nongreedy_closure() Rep.create(self, 0, nil, false) end
  def nongreedy_positive_closure() Rep.create(self, 1, nil, false) end
  def nongreedy_optional() Rep.create(self, 0, 1, false) end
  def nongreedy_repeat(m, n=m) Rep.create(self, m, n, false) end
  def closure() Rep.create(self, 0, nil) end
  def positive_closure() Rep.create(self, 1, nil) end
  def optional() Rep.create(self, 0, 1) end
  def repeat(m, n=m, greedy=true) Rep.create(self, m, n, greedy) end
  class Rep < RubyRegexp
    def Rep.create(r, m=0, n=nil, greedy=true)
      return EmptySequence if m == 0 && n == 0
      return r if m == 1 && n == 1
      return EmptySequence if Seq === r && r.empty_sequence?
      if (Alt === r || CharClass === r) && r.empty_set?
	return m == 0 ? EmptySequence : EmptySet
      end

      Rep.new(r, m, n, greedy)
    end

    def initialize(r, m=0, n=nil, greedy=true)
      @r = r
      @m = m
      @n = n
      @greedy = greedy
    end

    def pretty_format(out)
      @r.parenthesize(Elt).pretty_format(out)
      case @m
      when 0
        case @n
	when 0
	  out.text '{0}'
	when 1
	  out.text '?'
	when nil
	  out.text '*'
	else
	  out.text "{#{@m},#{@n}}"
	end
      when 1
        case @n
	when 1
	when nil
	  out.text '+'
	else
	  out.text "{#{@m},#{@n}}"
	end
      else
	if @m == @n
	  out.text "{#{@m}}"
	else
	  out.text "{#{@m},#{@n}}"
	end
      end
      out.text '?' unless @greedy
    end
  end

  class Elt < RubyRegexp
  end

  def RubyRegexp.charclass(natset)
    if natset.empty?
      EmptySet
    else
      CharClass.new(natset)
    end
  end
  class CharClass < Elt
    None = NatSet.empty
    Any = NatSet.whole
    NL = NatSet.create(?\n)
    NonNL = ~NL
    Word = NatSet.create(?0..?9, ?A..?Z, ?_, ?a..?z)
    NonWord = ~Word
    Space = NatSet.create(?t, ?\n, ?\f, ?\r, ?\s)
    NonSpace = ~Space
    Digit = NatSet.create(?0..?9)
    NonDigit = ~Digit

    def initialize(natset)
      @natset = natset
    end
    attr_reader :natset

    def empty_set?
      @natset.empty?
    end

    def pretty_format(out)
      case @natset
      when None; out.text '(?!)'
      when Any; out.text '[\s\S]'
      when NL; out.text '\n'
      when NonNL; out.text '.'
      when Word; out.text '\w'
      when NonWord; out.text '\W'
      when Space; out.text '\s'
      when NonSpace; out.text '\S'
      when Digit; out.text '\d'
      when NonDigit; out.text '\D'
      else
        if val = @natset.singleton?
          out.text encode_elt(val)
	else
	  if @natset.open?
	    neg_mark = '^'
	    es = (~@natset.natset).es
	  else
	    neg_mark = ''
	    es = @natset.es.dup
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
	  out.text "[#{neg_mark}#{r}]"
        end
      end
    end

    def encode_elt(e)
      case e
      when ?\t; '\t'
      when ?\n; '\n'
      when ?\r; '\r'
      when ?\f; '\f'
      when ?\v; '\v'
      when ?\a; '\a'
      when ?\e; '\e'
      when ?!, ?", ?%, ?&, ?', ?,, ?:, ?;, ?<, ?=, ?>, ?/, ?0..?9, ?@, ?A..?Z, ?_, ?`, ?a..?z, ?~
        sprintf("%c", e)
      else
        sprintf("\\x%02x", e)
      end
    end
  end

  def RubyRegexp.linebeg() Special.new('^') end
  def RubyRegexp.lineend() Special.new('$') end
  def RubyRegexp.strbeg() Special.new('\A') end
  def RubyRegexp.strend() Special.new('\z') end
  def RubyRegexp.strlineend() Special.new('\Z') end
  def RubyRegexp.strlineend() Special.new('\Z') end
  def RubyRegexp.word_boundary() Special.new('\b') end
  def RubyRegexp.non_word_boundary() Special.new('\B') end
  def RubyRegexp.previous_match() Special.new('\G') end
  def RubyRegexp.backref(n) Special.new("\\#{n}") end
  class Special < Elt
    def initialize(str)
      @str = str
    end

    def pretty_format(out)
      out.text @str
    end
  end

  def group() Paren.new(self, '') end
  def paren() Paren.new(self) end
  def lookahead() Paren.new(self, '?=') end
  def negative_lookahead() Paren.new(self, '?!') end
  # (?ixm-ixm:...)
  # (?>...)
  class Paren < Elt
    def initialize(r, mark='?:')
      @mark = mark
      @r = r
    end

    def pretty_format(out)
      out.group(1 + @mark.length, "(#@mark", ')') {
	@r.pretty_format(out)
      }
    end
  end

  # def RubyRegexp.comment(str) ... end # (?#...)

  def RubyRegexp.str(str)
    ccs = []
    str.each_byte {|ch|
      ccs << CharClass.new(NatSet.create(ch))
    }
    seq(*ccs)
  end
end
