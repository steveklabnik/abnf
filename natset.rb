=begin
= NatSet

NatSet represents a set of naturals - non-negative integers.

== class methods
--- NatSet.empty
--- NatSet.all
--- NatSet.create(integer_or_range, ...)

== methods
--- empty?
--- all?
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
  def NatSet.empty
    self.new
  end

  def NatSet.all
    self.new(0)
  end

  def NatSet.create(*es)
    r = self.empty
    es.each {|e|
      case e
      when Range
	unless Integer === e.begin
	  raise ArgumentError.new "bad value for #{self}.create: #{e}"
	end
	if e.exclude_end?
	  r += self.new(e.begin, e.end)
	else
	  r += self.new(e.begin, e.end+1)
	end
      when Integer
	r += self.new(e, e+1)
      when NatSet
	r += e
      else
        raise ArgumentError.new "bad value for #{self}.create: #{e}"
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

  def all?
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

  def tilde
    if @es.empty?
      type.all
    elsif @es[0] == 0
      type.new(*@es[1..-1])
    else
      type.new(0, *@es)
    end
  end
  alias ~ tilde

  def plus(other)
    other.plus_natset(self)
  end
  alias + plus
  alias | plus

  def plus_natset(natset)
    merge(natset) {|a, b| a || b}
  end

  def ampersand(other)
    other.ampersand_natset(self)
  end
  alias & ampersand

  def ampersand_natset(natset)
    merge(natset) {|a, b| a && b}
  end

  def minus(other)
    other.minus_natset(self)
  end
  alias - minus

  def minus_natset(natset) # natset - self
    # Since double dispatch *inverses* a receiver and an argument, 
    # condition should be inversed.
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
    type.new(*es0)
  end

end

if __FILE__ == $0
  require 'runit/testcase'
  require 'runit/cui/testrunner'

  class NatSetTest < RUNIT::TestCase
    def test_empty
      assert(NatSet.empty.empty?)
    end

    def test_all
      assert(NatSet.all.all?)
    end

    def test_open
      assert(!NatSet.empty.open?)
      assert(NatSet.all.open?)
    end

    def test_singleton
      assert_equal(1, NatSet.new(1, 2).singleton?)
      assert_equal(nil, NatSet.new(1, 3).singleton?)
    end

    def test_tilde
      assert_equal(NatSet.empty, ~NatSet.all)
      assert_equal(NatSet.all, ~NatSet.empty)
      assert_equal(NatSet.new(1, 2), ~NatSet.new(0, 1, 2))
      assert_equal(NatSet.new(0, 1, 2), ~NatSet.new(1, 2))
    end

    def test_plus
      assert_equal(NatSet.empty, NatSet.empty + NatSet.empty)
      assert_equal(NatSet.all, NatSet.empty + NatSet.all)
      assert_equal(NatSet.all, NatSet.all + NatSet.empty)
      assert_equal(NatSet.all, NatSet.all + NatSet.all)
      assert_equal(NatSet.create(0..2), NatSet.create(0, 2) + NatSet.create(0, 1))
    end

    def test_ampersand
      assert_equal(NatSet.empty, NatSet.empty & NatSet.empty)
      assert_equal(NatSet.empty, NatSet.empty & NatSet.all)
      assert_equal(NatSet.empty, NatSet.all & NatSet.empty)
      assert_equal(NatSet.all, NatSet.all & NatSet.all)
      assert_equal(NatSet.create(0), NatSet.create(0, 2) & NatSet.create(0, 1))
    end

    def test_minus
      assert_equal(NatSet.empty, NatSet.empty - NatSet.empty)
      assert_equal(NatSet.empty, NatSet.empty - NatSet.all)
      assert_equal(NatSet.all, NatSet.all - NatSet.empty)
      assert_equal(NatSet.empty, NatSet.all - NatSet.all)
      assert_equal(NatSet.create(2), NatSet.create(0, 2) - NatSet.create(0, 1))
    end

    def test_create
      assert_equal([1, 2], NatSet.create(1).es)
      assert_equal([1, 3], NatSet.create(1, 2).es)
      assert_equal([1, 4], NatSet.create(1, 2, 3).es)
      assert_equal([1, 4], NatSet.create(1, 3, 2).es)
      assert_equal([10, 21], NatSet.create(10..20).es)
      assert_equal([10, 20], NatSet.create(10...20).es)
      assert_equal([1, 2, 3, 4, 5, 6], NatSet.create(1, 3, 5).es)
      assert_equal([1, 16], NatSet.create(5..15, 1..10).es)
      assert_equal([1, 16], NatSet.create(11..15, 1..10).es)
      assert_exception(ArgumentError) {NatSet.create("a")}
      assert_exception(ArgumentError) {NatSet.create("a".."b")}
    end

  end

  RUNIT::CUI::TestRunner.run(NatSetTest.suite)
end
