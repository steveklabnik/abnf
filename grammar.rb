require 'natset'
require 'tsort'
require 'visitor'

class Grammar
  def initialize
    @rules = {}
  end

  def [](name)
    @rules[name]
  end

  def []=(name, rhs)
    @rules[name] = rhs
  end

  def regexp(name)
    @rules[name].to_regexp
  end

  include TSort
  def tsort_each_node(&block)
    @rules.each_key(&block)
  end
  def tsort_each_child(name)
    @rules[name].each_ref {|e| yield e.name}
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

    def each_ref(&block)
      self.accept(TraverseRef.new(&block))
    end

    def to_regexp(env={})
      raise TypeError.new("cannot convert to regexp.")
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
  class Ref < Elt
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
  class Traverse < Elt::Visitor
    def visitTerm(e) end
    def visitCon(e) e.elts.each {|d| d.accept(self)} end
    def visitAlt(e) e.elts.each {|d| d.accept(self)} end
    def visitRep(e) e.elt.accept(self) end
    def visitRef(e) end
    def visitBackrefDef(e) e.elt.accept(self) end
    def visitBackref(e) end
    def visitLookAhead(e) e.elt.accept(self) end
    def visitNoBacktrack(e) e.elt.accept(self) end
    def visitRegexpOption(e) e.elt.accept(self) end
  end

  class TraverseRef < Traverse
    def initialize(&block)
      @block = block
    end

    def visitRef(e)
      @block.call(e)
    end
  end

  class Copy < Elt::Visitor
    def visitTerm(e) Term.new(e.natset) end
    def visitCon(e) Con.new(*e.elts.map {|d| d.accept(self)}) end
    def visitAlt(e) Alt.new(*e.elts.map {|d| d.accept(self)}) end
    def visitRep(e) Rep.new(e.elt.accept(self), e.min, e.max, e.greedy) end
    def visitRef(e) Ref.new(e.name) end
    def visitBackrefDef(e) BackrefDef.new(e.name, e.elt.accept(self)) end
    def visitBackref(e) Backref.new(e.name) end
    def visitLookAhead(e) LookAhead.new(e.elt.accept(self), e.neg) end
    def visitNoBacktrack(e) NoBacktrack.new(e.elt.accept(self)) end
    def visitRegexpOption(e) RegexpOption.new(e.elt.accept(self), *e.opts) end
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
  end
end

if __FILE__ == $0
  require 'runit/testcase'
  require 'runit/cui/testrunner'

  class EltTest < RUNIT::TestCase
    def test_each_ref
      a = Grammar::Term.new(NatSet.new(1)) *
	  Grammar::Ref.new(:a) *
	  Grammar::Term.new(NatSet.new(2)) *
	  Grammar::Ref.new(:b) *
	  Grammar::Term.new(NatSet.new(3)) *
	  Grammar::Ref.new(:c) *
	  Grammar::Term.new(NatSet.new(4)) *
	  Grammar::Ref.new(:d) *
	  Grammar::Term.new(NatSet.new(5)) *
	  Grammar::Ref.new(:e)
      result = []
      a.each_ref {|e| result << e.name}
      assert_equal([:a, :b, :c, :d, :e], result)
    end
  end

  RUNIT::CUI::TestRunner.run(EltTest.suite)
end
