require 'natset'
require 'tsort'
require 'visitor'

class Grammar
  def initialize
    @rules = {}
  end

  def import(g)
    g.each {|name, rhs|
      @rules[name] = rhs
    }
  end

  def [](name)
    @rules[name]
  end

  def []=(name, rhs)
    @rules[name] = rhs
  end

  def include?(name)
    @rules.include? name
  end

  def each(&block)
    @rules.each(&block)
  end

  def regexp(name)
    env = {}
    each_strongly_connected_component_from(name) {|ns|
      # This condition is too restrictive.
      # Simple expantion should be supported, at least.
      if ns.length != 1
        raise StandardError.new "cannot convert mutually recusive rules to regexp: #{ns.join(', ')}"
      end
      n = ns.first
      e = @rules[n]
      # Convert a recursive rule to non-recursive rule if possible.
      # This conversion is *not* perfect.
      # It may fail even if possible.
      # More work (survey) is needed.
      #
      # X = a X | b | X c
      #  =>
      # X = a* b c*
      if Alt === e
        left = []
        middle = []
        right = []
        e.elts.each {|branch|
          if Con === branch
            if branch.elts.empty?
              middle << branch
            else
              if RuleRef === branch.elts.first && branch.elts.first.name == n
                right << Con.new(*branch.elts[1..-1])
              elsif RuleRef === branch.elts.last && branch.elts.last.name == n
                left << Con.new(*branch.elts[0...-1])
              else
                middle << branch
              end
            end
          else
            middle << branch
          end
        }
        e = Con.new(Alt.new(*left).rep, Alt.new(*middle), Alt.new(*right).rep)
      end

      e.each_ruleref {|n2|
        if n == n2
	  raise StandardError.new "too complex to convert to regexp: #{n}"
	end
      }

      env[n] = e.accept(SubstRuleRef.new(env))
    }
    r = env[name].simplify
    r.accept(ScanBackref.new(env = {}))
    r.accept(RegexpConv.new(env))
  end

  include TSort
  def tsort_each_node(&block)
    @rules.each_key(&block)
  end
  def tsort_each_child(name)
    unless @rules.include? name
      raise StandardError.new "grammar symbol undefined: #{name}"
    end
    @rules.fetch(name).each_ruleref {|e| yield e.name}
  end

### Abstract Class
  Elt = visitor_pattern {|c| 'visit' + c.name.sub(/\AGrammar::/, '')}
  class Elt
    def *(other)
      Con.new(self, other)
    end

    def +(other)
      Alt.new(self, other)
    end

    def **(n)
      case n
      when Integer
        rep(n, n)
      when Range
        rep(n.first, n.first + n.size - 1)
      else
        raise TypeError.new "not Integer nor Range: #{n}"
      end
    end

    def rep(min=0, max=nil, greedy=true)
      Rep.new(self, min, max, greedy)
    end

    def simplify
      self.accept(Simplify.new)
    end

    def each_ruleref(&block)
      self.accept(TraverseRuleRef.new(&block))
    end
  end

### Terminal
  class Term < Elt
    def initialize(natset)
      @natset = natset
    end
    attr_reader :natset

  end

### Basic Combinator
  class Con < Elt
    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts
  end
  EmptySequence = Con.new

  class Alt < Elt
    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts
  end
  EmptySet = Alt.new

  class Rep < Elt
    def initialize(elt, min=0, max=nil, greedy=true)
      @elt = elt
      @min = min
      @max = max
      @greedy = greedy
    end
    attr_reader :elt, :min, :max, :greedy
  end

### Rule Reference
  class RuleRef < Elt
    def initialize(name)
      @name = name
    end
    attr_reader :name
  end

### Backward Reference
  class BackrefDef < Elt
    def initialize(name, elt)
      @name = name
      @elt = elt
    end
    attr_reader :name, :elt
  end

  class Backref < Elt
    def initialize(name)
      @name = name
    end
    attr_reader :name
  end

### Zero-Width Assertions
  class LookAhead < Elt
    def initialize(elt, neg=false)
      @elt = elt
      @neg = neg
    end
    attr_reader :elt, :neg
  end

  class BOL < Elt; def to_regexp; '^'; end; end
  class EOL < Elt; def to_regexp; '$'; end; end
  class BOS < Elt; def to_regexp; '\A'; end; end
  class EOS < Elt; def to_regexp; '\z'; end; end
  class EOSNL < Elt; def to_regexp; '\Z'; end; end
  class WordBoundary < Elt; def to_regexp; '\b'; end; end
  class NonWordBoundary < Elt; def to_regexp; '\B'; end; end
  class PrevMatchEnd < Elt; def to_regexp; '\G'; end; end

### Special Regexp Element
  class NoBacktrack < Elt
    def initialize(elt)
      @elt = elt
    end
    attr_reader :elt
  end

  class RegexpOption < Elt
    def initialize(elt, *opts)
      @elt = elt
      @opts = opts
    end
    attr_reader :elt, :opts
  end

### Visitor
  class Copy < Elt::Visitor
    def visitTerm(e) Term.new(e.natset) end
    def visitCon(e) Con.new(*e.elts.map {|d| d.accept(self)}) end
    def visitAlt(e) Alt.new(*e.elts.map {|d| d.accept(self)}) end
    def visitRep(e) Rep.new(e.elt.accept(self), e.min, e.max, e.greedy) end
    def visitRuleRef(e) RuleRef.new(e.name) end
    def visitBackrefDef(e) BackrefDef.new(e.name, e.elt.accept(self)) end
    def visitBackref(e) Backref.new(e.name) end
    def visitLookAhead(e) LookAhead.new(e.elt.accept(self), e.neg) end
    def visitNoBacktrack(e) NoBacktrack.new(e.elt.accept(self)) end
    def visitRegexpOption(e) RegexpOption.new(e.elt.accept(self), *e.opts) end
    def visitBOL(e) BOL.new end
    def visitEOL(e) EOL.new end
    def visitBOS(e) BOS.new end
    def visitEOS(e) EOS.new end
    def visitEOSNL(e) EOSNL.new end
    def visitWordBoundary(e) WordBoundary.new end
    def visitNonWordBoundary(e) NonWordBoundary.new end
    def visitPrevMatchEnd(e) PrevMatchEnd.new end
  end

  class SubstRuleRef < Copy
    def initialize(env)
      @env = env
    end

    def visitRuleRef(e)
      if @env.include? e.name
        @env[e.name]
      else
        e
      end
    end
  end

  class Simplify < Copy
    def visitCon(_)
      result = []
      super.elts.each {|e|
	if Alt === e && e.elts.empty?
	  return EmptySet
	elsif Term === e && e.natset.empty?
	  return EmptySet
        elsif e.kind_of? Con
	  result.concat e.elts
	else
	  result << e
	end
      }
      if result.length == 1
        result.first
      else
	Con.new(*result)
      end
    end

    def visitAlt(_)
      result = []
      super.elts.each {|e|
        if Alt === e
	  result.concat e.elts
	elsif Term === e && !result.empty? && Term === result[-1]
	  result[-1] = Term.new(result[-1].natset + e.natset)
	else
	  result << e
	end
      }
      if result.length == 1
        result.first
      else
	Alt.new(*result)
      end
    end

    def visitRep(_)
      e = super
      if Alt === e.elt && e.elt.elts.empty?
	EmptySequence
      elsif Term === e.elt && e.elt.natset.empty?
	EmptySequence
      else
        e
      end
    end
  end

  class Traverse < Elt::Visitor
    def visitTerm(e) end
    def visitCon(e) e.elts.each {|d| d.accept(self)} end
    def visitAlt(e) e.elts.each {|d| d.accept(self)} end
    def visitRep(e) e.elt.accept(self) end
    def visitRuleRef(e) end
    def visitBackrefDef(e) e.elt.accept(self) end
    def visitBackref(e) end
    def visitLookAhead(e) e.elt.accept(self) end
    def visitNoBacktrack(e) e.elt.accept(self) end
    def visitRegexpOption(e) e.elt.accept(self) end
    def visitBOL(e) end
    def visitEOL(e) end
    def visitBOS(e) end
    def visitEOS(e) end
    def visitEOSNL(e) end
    def visitWordBoundary(e) end
    def visitNonWordBoundary(e) end
    def visitPrevMatchEnd(e) end
  end

  class TraverseRuleRef < Traverse
    def initialize(&block)
      @block = block
    end

    def visitRuleRef(e)
      @block.call(e)
    end
  end

  class ScanBackref < Traverse
    def initialize(env)
      @env = env
    end

    def visitBackrefDef(e)
      @env[e.name] = @env.size + 1
      super
    end
  end

  class RegexpConv < Elt::Visitor
    def initialize(env)
      @env = env
    end

    None = NatSet.empty
    Any = NatSet.whole
    NL = NatSet.create(?\n)
    NonNL = ~NL
    Word = NatSet.create(?0..?9, ?A..?Z, ?_, ?a..?z)
    NonWord = ~Word
    Space = NatSet.create(?t, ?\n, ?\f, ?\r, ?\ )
    NonSpace = ~Space
    Digit = NatSet.create(?0..?9)
    NonDigit = ~Digit

    def visitTerm(e)
      case e.natset
      when None; '(?!)'
      when Any; '[\s\S]'
      when NL; '\n'
      when NonNL; '.'
      when Word; '\w'
      when NonWord; '\W'
      when Space; '\s'
      when NonSpace; '\S'
      when Digit; '\d'
      when NonDigit; '\D'
      else
	if val = e.natset.singleton?
	  return encode_elt(val)
	end
        if e.natset.open?
	  neg_mark = '^'
	  es = (~e.natset).es
	else
	  neg_mark = ''
	  es = e.natset.es.dup
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
      when ?\t; '\t'
      when ?\n; '\n'
      when ?\r; '\r'
      when ?\f; '\f'
      when ?\v; '\v'
      when ?\a; '\a'
      when ?\e; '\e'
      when ?0..?9, ?A..?Z, ?a..?z, ?_
        sprintf("%c", e)
      else
        sprintf("\\x%02x", e)
      end
    end

    def visitCon(e)
      "(?:#{e.elts.map {|d| d.accept(self)}.join ''})"
    end

    def visitAlt(e)
      if e.elts.empty?
        '(?!)'
      else
	"(?:#{e.elts.map {|d| d.accept(self)}.join '|'})"
      end
    end

    def visitRep(e)
      r = e.elt.accept(self)
      greedy_mark = e.greedy ? '' : '?'
      if e.min == 0
	if e.max == 1
	  return "(?:#{r}?#{greedy_mark})"
        elsif e.max == nil
	  return "(?:#{r}*#{greedy_mark})"
	end
      elsif e.min == 1
        if e.max == nil
	  return "(?:#{r}+#{greedy_mark})"
	end
      end

      if e.max == nil
	"(?:#{r}{#{e.min},}#{greedy_mark})"
      elsif e.min == e.max
	"(?:#{r}{#{e.min}}#{greedy_mark})"
      else
	"(?:#{r}{#{e.min},#{e.max}}#{greedy_mark})"
      end
    end

    def visitRuleRef(e)
      raise StandardError "cannot convert rule reference to regexp: #{e.name}"
    end

    def visitBackrefDef(e)
      "(#{e.elt.accept(self)})"
    end

    def visitBackref(e)
      "\\#{@env[e.name]}"
    end

    def visitLookAhead(e)
      "(?#{e.neg ? '!' : '='}#{e.elt.accept(self)})"
    end

    def visitNoBacktrack(e)
      "(?>#{e.elt.accept(self)})"
    end

    def visitRegexpOption(e)
      opt = ''
      e.opts.each {|o| opt << sprintf("%c", o) if 0 < o}
      opt << '-'
      e.opts.each {|o| opt << sprintf("%c", o) if 0 > o}
      opt.sub!(/-\z/, '')
      "(?#{opt}:#{e.elt.accept(self)})"
    end

    def visitBOL(e) '^' end
    def visitEOL(e) '$' end
    def visitBOS(e) '\A' end
    def visitEOS(e) '\z' end
    def visitEOSNL(e) '\Z' end
    def visitWordBoundary(e) '\b' end
    def visitNonWordBoundary(e) '\B' end
    def visitPrevMatchEnd(e) '\G' end
  end

end

if __FILE__ == $0
  require 'runit/testcase'
  require 'runit/cui/testrunner'

  class GrammarTest < RUNIT::TestCase
    def test_each_ruleref
      a = Grammar::Term.new(NatSet.new(1)) *
	  Grammar::RuleRef.new(:a) *
	  Grammar::Term.new(NatSet.new(2)) *
	  Grammar::RuleRef.new(:b) *
	  Grammar::Term.new(NatSet.new(3)) *
	  Grammar::RuleRef.new(:c) *
	  Grammar::Term.new(NatSet.new(4)) *
	  Grammar::RuleRef.new(:d) *
	  Grammar::Term.new(NatSet.new(5)) *
	  Grammar::RuleRef.new(:e)
      result = []
      a.each_ruleref {|e| result << e.name}
      assert_equal([:a, :b, :c, :d, :e], result)
    end

    def test_astar
      g = Grammar.new
       g[:a] = Grammar::Alt.new(
         Grammar::EmptySequence,
	 Grammar::Con.new(
	   Grammar::Term.new(NatSet.create(?a)),
	   Grammar::RuleRef.new(:a)))
       assert_equal("(?:a*)", g.regexp(:a))
    end

    def test_visitor_methods
      assert_equal([], Grammar::Copy.abstract_methods)
      assert_equal([], Grammar::SubstRuleRef.abstract_methods)
      assert_equal([], Grammar::Simplify.abstract_methods)
      assert_equal([], Grammar::Traverse.abstract_methods)
      assert_equal([], Grammar::TraverseRuleRef.abstract_methods)
      assert_equal([], Grammar::ScanBackref.abstract_methods)
      assert_equal([], Grammar::RegexpConv.abstract_methods)
    end
  end

  RUNIT::CUI::TestRunner.run(GrammarTest.suite)
end
