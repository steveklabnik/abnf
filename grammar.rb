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

  class Elt
    def *(other)
      Con.new(self, other)
    end

    def +(other)
      Alt.new(self, other)
    end

    def rep(min=0, max=nil, greedy=true)
      Rep.new(self, min, max, greedy)
    end

    def simplify
      self.conv(Simplify.new)
    end
  end

### Terminal
  class Term < Elt
    def initialize(elt)
      @elt = elt
    end

    def conv(c)
      c.term(@elt)
    end
  end

### Basic Combinator
  class Con < Elt
    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts

    def conv(c)
      c.con(*@elts)
    end
  end

  class Alt < Elt
    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts

    def conv(c)
      c.alt(*@elts)
    end
  end

  class Rep < Elt
    def initialize(elt, min=0, max=nil, greedy=true)
      @elt = elt
      @min = min
      @max = max
      @greedy = greedy
    end

    def conv(c)
      c.rep(@elt, @min, @max, @greedy)
    end
  end

### Rule Reference
  class Ref < Elt
    def initialize(name)
      @name = name
    end

    def conv(c)
      c.ref(@name)
    end
  end

### Backward Reference
  class BackrefDef < Elt
    def initialize(name, elt)
      @name = name
      @elt = elt
    end

    def conv(c)
      c.backrefdef(@name, @elt)
    end
  end

  class Backref < Elt
    def initialize(name)
      @name = name
    end

    def conv(c)
      c.backref(@name)
    end
  end

### Zero-Width Assertions
  class LookAhead < Elt
    def initialize(elt, neg=false)
      @elt = elt
      @neg = neg
    end

    def conv(c)
      c.lookahead(@elt, @neg)
    end
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

    def conv(c)
      c.nobacktrack(@elt)
    end
  end

### Converter
  class Copy
    def term(elt) Term.new(elt) end
    def con(*elts) Con.new(*elts.map {|e| e.conv(self)}) end
    def alt(*elts) Alt.new(*elts.map {|e| e.conv(self)}) end
    def rep(elt, min, max, greedy) Rep.new(elt.conv(self), min, max, greedy) end
    def backrefdef(name, elt) BackrefDef.new(name, elt.conv(self)) end
    def backref(name) Backref.new(name) end
    def lookahead(elt, neg) LookAhead.new(elt.conv(self), neg) end
    def nobacktrack(elt) NoBacktrack.new(elt.conv(self)) end
  end

  class Simplify < Copy
    def con(*elts)
      result = []
      super.elts.each {|e|
	if e.kind_of? Alt && e.elts.empty?
	  return e
        elsif e.kind_of? Con
	  result.concat e.elts
	else
	  result << e
	end
      }
      Con.new(*result)
    end

    def alt(*elts)
      result = []
      super.elts.each {|e|
        if e.kind_of? Alt
	  result.concat e.elts
	else
	  result << e
	end
      }
      Alt.new(*result)
    end
  end
end
