require 'natset'

class ABNF
  class Elt
    # A variable is assumed as not empty set. 
    def empty_set?
      false
    end

    # A variable is assumed as not empty sequence. 
    def empty_sequence?
      false
    end

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
    class << Alt
      alias _new new
    end

    def Alt.new(*elts)
      elts2 = []
      elts.each {|e|
	if e.empty_set?
	  next
        elsif Alt === e
	  elts2.concat e.elts
	elsif Term === e
	  if Term === elts2.last
	    elts2[-1] = Term.new(elts2.last.natset + e.natset)
	  else
	    elts2 << e
	  end
	else
	  elts2 << e
	end
      }
      case elts2.length
      when 0; EmptySet
      when 1; elts2.first
      else; Alt._new(*elts2)
      end
    end

    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts

    def empty_set?
      @elts.empty?
    end

    def each_var(&block) @elts.each {|elt| elt.each_var(&block)} end
    def subst_var(&block) Alt.new(*@elts.map {|elt| elt.subst_var(&block)}) end
  end
  EmptySet = Alt._new

  class Seq < Elt
    class << Seq
      alias _new new
    end

    def Seq.new(*elts)
      elts2 = []
      elts.each {|e|
	if e.empty_sequence?
	  next
        elsif Seq === e
	  elts2.concat e.elts
	elsif e.empty_set?
	  return EmptySet
	else
	  elts2 << e
	end
      }
      case elts2.length
      when 0; EmptySequence
      when 1; elts2.first
      else; Seq._new(*elts2)
      end
    end

    def initialize(*elts)
      @elts = elts
    end
    attr_reader :elts

    def empty_sequence?
      @elts.empty?
    end

    def each_var(&block) @elts.each {|elt| elt.each_var(&block)} end
    def subst_var(&block) Seq.new(*@elts.map {|elt| elt.subst_var(&block)}) end
  end
  EmptySequence = Seq._new

  class Rep < Elt
    class << Rep
      alias _new new
    end

    def Rep.new(elt, min=0, max=nil, greedy=true)
      return EmptySequence if min == 0 && max == 0
      return elt if min == 1 && max == 1
      return EmptySequence if elt.empty_sequence?
      if elt.empty_set?
        return min == 0 ? EmptySequence : EmptySet
      end
      Rep._new(elt, min, max, greedy)
    end

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
    class << Term
      alias _new new
    end

    def Term.new(natset)
      if natset.empty?
        EmptySet
      else
        Term._new(natset)
      end
    end

    def initialize(natset)
      @natset = natset
    end
    attr_reader :natset

    def empty_set?
      @natset.empty?
    end

    def each_var(&block) end
    def subst_var(&block) self end
  end
end
