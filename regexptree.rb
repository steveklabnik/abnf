=begin
= RegexpTree

RegexpTree represents regular expression.
It can be converted to Regexp.

== class methods
--- RegexpTree.str(string)
    returns an instance of RegexpTree which only matches ((|string|))
--- RegexpTree.alt(*regexp_trees)
    returns an instance of RegexpTree which is alternation of ((|regexp_trees|)).
--- RegexpTree.seq(*regexp_trees)
    returns an instance of RegexpTree which is concatination of ((|regexp_trees|)).
--- RegexpTree.rep(regexp_tree, min=0, max=nil, greedy=true)
    returns an instance of RegexpTree which is reptation of ((|regexp_tree|)).
--- RegexpTree.charclass(natset)
    returns an instance of RegexpTree which matches characters in ((|natset|)).
#--- RegexpTree.linebeg
#--- RegexpTree.lineend
#--- RegexpTree.strbeg
#--- RegexpTree.strend
#--- RegexpTree.strlineend
#--- RegexpTree.word_boundary
#--- RegexpTree.non_word_boundary
#--- RegexpTree.previous_match
#--- RegexpTree.backref(n)

== methods
--- regexp
    convert to Regexp.
--- to_s
    convert to String.
--- empty_set?
    returns true iff self never matches. 
--- empty_sequence?
    returns true iff self only matches empty string.
--- self | other
    returns alternation of ((|self|)) and ((|other|)).
--- self + other
    returns concatination of ((|self|)) and ((|other|)).
--- self * n
    returns ((|n|)) times repetation of ((|self|)).
--- rep(min=0, max=nil, greedy=true)
    returns ((|min|)) to ((|max|)) times repetation of ((|self|)).
#--- closure(greedy=true)
#--- positive_closure(greedy=true)
#--- optional(greedy=true)
#--- ntimes(min, max=min, greedy=true)
#--- nongreedy_rep(min=0, max=nil)
#--- nongreedy_closure
#--- nongreedy_positive_closure
#--- nongreedy_optional
#--- nongreedy_ntimes(min, max=min)
=end

require 'prettyprint'
require 'natset'

class RegexpTree
  @curr_prec = 1
  def RegexpTree.inherited(c)
    return if c.superclass != RegexpTree
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

  def pretty_print(pp)
    case_insensitive = case_insensitive?
    pp.group(3, '%r{', '}x') {
      (case_insensitive ? self.downcase : self).pretty_format(pp)
    }
    pp.text 'i' if case_insensitive
  end

  def inspect
    case_insensitive = case_insensitive? && "i"
    r = PrettyPrint.singleline_format('') {|out|
	  (case_insensitive ? self.downcase : self).pretty_format(out)
	}
    if %r{/} =~ r
      "%r{#{r}}#{case_insensitive}"
    else
      "%r/#{r}/#{case_insensitive}"
    end
  end

  def regexp
    Regexp.compile(
      PrettyPrint.singleline_format('') {|out|
	pretty_format(out)
      })
  end

  def to_s
    PrettyPrint.singleline_format('') {|out|
      # x flag is not required because all whitespaces are escaped.
      if case_insensitive?
	out.text '(?i-m:'
	downcase.pretty_format(out)
	out.text ')'
      else
	out.text '(?-im:'
	pretty_format(out)
	out.text ')'
      end
    }
  end

  def empty_set?
    false
  end

  def empty_sequence?
    false
  end

  def |(other)
    RegexpTree.alt(self, other)
  end
  def RegexpTree.alt(*rs)
    rs2 = []
    rs.each {|r|
      if r.empty_set?
        next
      elsif Alt === r
        rs2.concat r.rs
      elsif CharClass === r
        if CharClass === rs2.last
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
  class Alt < RegexpTree
    def initialize(rs)
      @rs = rs
    end
    attr_reader :rs

    def empty_set?
      @rs.empty?
    end

    def case_insensitive?
      @rs.all? {|r| r.case_insensitive?}
    end

    def downcase
      Alt.new(@rs.map {|r| r.downcase})
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
    RegexpTree.seq(self, other)
  end
  def RegexpTree.seq(*rs)
    rs2 = []
    rs.each {|r|
      if r.empty_sequence?
	next
      elsif Seq === r
	rs2.concat r.rs
      elsif r.empty_set?
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
  class Seq < RegexpTree
    def initialize(rs)
      @rs = rs
    end
    attr_reader :rs

    def empty_sequence?
      @rs.empty?
    end

    def case_insensitive?
      @rs.all? {|r| r.case_insensitive?}
    end

    def downcase
      Seq.new(@rs.map {|r| r.downcase})
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

  def *(n)
    case n
    when Integer
      RegexpTree.rep(self, n, n)
    when Range
      RegexpTree.rep(self, n.first, n.last - (n.exclude_end? ? 1 : 0))
    else
      raise TypeError.new("Integer or Range expected: #{n}")
    end
  end
  def nongreedy_closure() RegexpTree.rep(self, 0, nil, false) end
  def nongreedy_positive_closure() RegexpTree.rep(self, 1, nil, false) end
  def nongreedy_optional() RegexpTree.rep(self, 0, 1, false) end
  def nongreedy_ntimes(m, n=m) RegexpTree.rep(self, m, n, false) end
  def nongreedy_rep(m=0, n=nil) RegexpTree.rep(self, m, n, false) end
  def closure(greedy=true) RegexpTree.rep(self, 0, nil, greedy) end
  def positive_closure(greedy=true) RegexpTree.rep(self, 1, nil, greedy) end
  def optional(greedy=true) RegexpTree.rep(self, 0, 1, greedy) end
  def ntimes(m, n=m, greedy=true) RegexpTree.rep(self, m, n, greedy) end
  def rep(m=0, n=nil, greedy=true) RegexpTree.rep(self, m, n, greedy) end

  def RegexpTree.rep(r, m=0, n=nil, greedy=true)
    return EmptySequence if m == 0 && n == 0
    return r if m == 1 && n == 1
    return EmptySequence if r.empty_sequence?
    if r.empty_set?
      return m == 0 ? EmptySequence : EmptySet
    end
    Rep.new(r, m, n, greedy)
  end

  class Rep < RegexpTree
    def initialize(r, m=0, n=nil, greedy=true)
      @r = r
      @m = m
      @n = n
      @greedy = greedy
    end

    def case_insensitive?
      @r.case_insensitive?
    end

    def downcase
      Rep.new(@r.downcase, @m, @n, @greedy)
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

  class Elt < RegexpTree
  end

  def RegexpTree.charclass(natset)
    if natset.empty?
      EmptySet
    else
      CharClass.new(natset)
    end
  end
  class CharClass < Elt
    None = NatSet.empty
    Any = NatSet.universal
    NL = NatSet.new(?\n)
    NonNL = ~NL
    Word = NatSet.new(?0..?9, ?A..?Z, ?_, ?a..?z)
    NonWord = ~Word
    Space = NatSet.new(?t, ?\n, ?\f, ?\r, ?\s)
    NonSpace = ~Space
    Digit = NatSet.new(?0..?9)
    NonDigit = ~Digit

    UpAlpha = NatSet.new(?A..?Z)
    LowAlpha = NatSet.new(?a..?z)

    def initialize(natset)
      @natset = natset
    end
    attr_reader :natset

    def empty_set?
      @natset.empty?
    end

    def case_insensitive?
      up = @natset & UpAlpha
      low = @natset & LowAlpha
      return false if up.es.length != low.es.length
      up.es.map! {|ch| ch - ?A + ?a}
      up == low
    end

    def downcase
      up = @natset & UpAlpha
      up.es.map! {|ch| ch - ?A + ?a}
      CharClass.new((@natset - UpAlpha) | up)
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

  def RegexpTree.linebeg() Special.new('^') end
  def RegexpTree.lineend() Special.new('$') end
  def RegexpTree.strbeg() Special.new('\A') end
  def RegexpTree.strend() Special.new('\z') end
  def RegexpTree.strlineend() Special.new('\Z') end
  def RegexpTree.word_boundary() Special.new('\b') end
  def RegexpTree.non_word_boundary() Special.new('\B') end
  def RegexpTree.previous_match() Special.new('\G') end
  def RegexpTree.backref(n) Special.new("\\#{n}") end
  class Special < Elt
    def initialize(str)
      @str = str
    end

    def case_insensitive?
      true
    end

    def downcase
      self
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

    def case_insensitive?
      @r.case_insensitive?
    end

    def downcase
      Paren.new(@r.downcase, @mark)
    end

    def pretty_format(out)
      out.group(1 + @mark.length, "(#@mark", ')') {
	@r.pretty_format(out)
      }
    end
  end

  # def RegexpTree.comment(str) ... end # (?#...)

  def RegexpTree.str(str)
    ccs = []
    str.each_byte {|ch|
      ccs << CharClass.new(NatSet.new(ch))
    }
    seq(*ccs)
  end
end
