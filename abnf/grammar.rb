require 'natset'

class ABNF
  class Elt
    def +(other)
      Seq.new(self, other)
    end

    def |(other)
      Alt.new(self, other)
    end

    def *(n)
      case n
      when Integer
        rep(n, n)
      when Range
        rep(n.first, n.last - (n.exclude_end? ? 0 : 1))
      else
        raise TypeError.new("Integer or Range expected: #{n}")
      end
    end

    def rep(min=0, max=nil, greedy=true)
      Rep.new(self, min, max, greedy)
    end
  end

  class Alt < Elt
    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts

    def each_var(&block) @elts.each {|elt| elt.each_var(&block)} end
    def subst_var(&block) Alt.new(*@elts.map {|elt| elt.subst_var(&block)}) end
  end
  EmptySet = Alt.new

  class Seq < Elt
    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts

    def each_var(&block) @elts.each {|elt| elt.each_var(&block)} end
    def subst_var(&block) Seq.new(*@elts.map {|elt| elt.subst_var(&block)}) end
  end
  EmptySequence = Seq.new

  class Rep < Elt
    def initialize(elt, min=0, max=nil, greedy=true)
      @elt = elt
      @min = min
      @max = max
      @greedy = greedy
    end
    attr_reader :elt, :min, :max, :greedy

    def each_var(&block) @elt.each_var(&block) end
    def subst_var(&block) Rep.new(@elt.subst_var(&block), min, max, greedy) end
  end

  class Var < Elt
    def initialize(name)
      @name = name
    end
    attr_reader :name

    def each_var(&block) yield @name end
    def subst_var(&block) yield(@name) || self end
  end

  class Term < Elt
    def initialize(natset)
      @natset = natset
    end
    attr_reader :natset

    def each_var(&block) end
    def subst_var(&block) self end
  end
end
