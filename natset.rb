=begin
= NatSet

NatSet represents a set of naturals - non-negative integers.

== class methods
--- NatSet.empty
--- NatSet.universal
--- NatSet.new(integer_or_range, ...)

== methods
--- empty?
--- universal?
--- open?
--- singleton?
--- self == other
--- self === other
--- eql?(other)
--- hash
--- ~self
--- self + other
--- self - other
--- self & other
=end

class NatSet
  class << NatSet
    alias _new new
  end

  def NatSet.empty
    self._new
  end

  def NatSet.universal
    self._new(0)
  end

  def NatSet.new(*es)
    r = self.empty
    es.each {|e|
      case e
      when Range
	unless Integer === e.begin
	  raise ArgumentError.new("bad value for #{self}.new: #{e}")
	end
        if e.end == -1
	  r += self._new(e.begin)
	elsif e.exclude_end?
	  r += self._new(e.begin, e.end)
	else
	  r += self._new(e.begin, e.end+1)
	end
      when Integer
	r += self._new(e, e+1)
      when NatSet
	r += e
      else
        raise ArgumentError.new("bad value for #{self}.new: #{e}")
      end
    }
    r
  end

  def initialize(*es)
    @es = es
  end
  attr_reader :es

  def empty?
    @es.empty?
  end

  def universal?
    @es == [0]
  end

  def open?
    @es.length & 1 != 0
  end

  def singleton?
    if @es.length == 2 && @es[0] == @es[1] - 1
      @es[0]
    else
      nil
    end
  end

  def ==(other)
    @es == other.es
  end
  alias === ==
  alias eql? ==

  def hash
    @es.hash
  end

  def complement
    if @es.empty?
      self.class.universal
    elsif @es[0] == 0
      self.class._new(*@es[1..-1])
    else
      self.class._new(0, *@es)
    end
  end
  alias ~ complement

  def union(other)
    other.union_natset(self)
  end
  alias + union
  alias | union

  def union_natset(natset)
    return self if natset.empty? || self.universal?
    return natset if self.empty? || natset.universal?
    merge(natset) {|a, b| a || b}
  end

  def intersect(other)
    other.intersect_natset(self)
  end
  alias & intersect

  def intersect_natset(natset)
    return self if self.empty? || natset.universal?
    return natset if natset.empty? || self.universal?
    merge(natset) {|a, b| a && b}
  end

  def subtract(other)
    other.subtract_natset(self)
  end
  alias - subtract

  def subtract_natset(natset) # natset - self
    # Since double dispatch *inverses* a receiver and an argument, 
    # condition should be inversed.
    return natset if self.empty? || natset.empty?
    return NatSet.empty if self.universal?
    return ~self if natset.universal?
    merge(natset) {|a, b| !a && b}
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
    self.class._new(*es0)
  end

  def pretty_print(pp)
    pp.object_group(self) {
      pp.text ':'
      (0...@es.length).step(2) {|i|
	pp.breakable
        e1 = @es[i]
        e2 = @es[i+1]
	if e2 == nil
	  pp.text "#{e1}..inf"
	elsif e1 == e2 - 1
	  pp.text e1.to_s
	else
	  pp.text "#{e1}..#{e2-1}"
	end
      }
    }
  end

  def inspect
    require 'pp'
    PP.singleline_pp(self, '')
  end
end

if __FILE__ == $0
  require 'test/unit'

  class NatSetTest < Test::Unit::TestCase
    def test_empty
      assert(NatSet.empty.empty?)
    end

    def test_universal
      assert(NatSet.universal.universal?)
    end

    def test_open
      assert(!NatSet.empty.open?)
      assert(NatSet.universal.open?)
    end

    def test_singleton
      assert_equal(1, NatSet._new(1, 2).singleton?)
      assert_equal(nil, NatSet._new(1, 3).singleton?)
    end

    def test_complement
      assert_equal(NatSet.empty, ~NatSet.universal)
      assert_equal(NatSet.universal, ~NatSet.empty)
      assert_equal(NatSet._new(1, 2), ~NatSet._new(0, 1, 2))
      assert_equal(NatSet._new(0, 1, 2), ~NatSet._new(1, 2))
    end

    def test_union
      assert_equal(NatSet.empty, NatSet.empty + NatSet.empty)
      assert_equal(NatSet.universal, NatSet.empty + NatSet.universal)
      assert_equal(NatSet.universal, NatSet.universal + NatSet.empty)
      assert_equal(NatSet.universal, NatSet.universal + NatSet.universal)
      assert_equal(NatSet.new(0..2), NatSet.new(0, 2) + NatSet.new(0, 1))
    end

    def test_intersect
      assert_equal(NatSet.empty, NatSet.empty & NatSet.empty)
      assert_equal(NatSet.empty, NatSet.empty & NatSet.universal)
      assert_equal(NatSet.empty, NatSet.universal & NatSet.empty)
      assert_equal(NatSet.universal, NatSet.universal & NatSet.universal)
      assert_equal(NatSet.new(0), NatSet.new(0, 2) & NatSet.new(0, 1))
    end

    def test_subtract
      assert_equal(NatSet.empty, NatSet.empty - NatSet.empty)
      assert_equal(NatSet.empty, NatSet.empty - NatSet.universal)
      assert_equal(NatSet.universal, NatSet.universal - NatSet.empty)
      assert_equal(NatSet.empty, NatSet.universal - NatSet.universal)
      assert_equal(NatSet.new(2), NatSet.new(0, 2) - NatSet.new(0, 1))
    end

    def test_new
      assert_equal([1, 2], NatSet.new(1).es)
      assert_equal([1, 3], NatSet.new(1, 2).es)
      assert_equal([1, 4], NatSet.new(1, 2, 3).es)
      assert_equal([1, 4], NatSet.new(1, 3, 2).es)
      assert_equal([10, 21], NatSet.new(10..20).es)
      assert_equal([10, 20], NatSet.new(10...20).es)
      assert_equal([1, 2, 3, 4, 5, 6], NatSet.new(1, 3, 5).es)
      assert_equal([1, 16], NatSet.new(5..15, 1..10).es)
      assert_equal([1, 16], NatSet.new(11..15, 1..10).es)
      assert_raises(ArgumentError) {NatSet.new("a")}
      assert_raises(ArgumentError) {NatSet.new("a".."b")}
    end

  end
end
