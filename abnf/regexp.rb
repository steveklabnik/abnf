require 'abnf/abnf'
require 'regexptree'

class ABNF
  def ABNF.regexp(desc, name=nil)
    ABNF.regexp_tree(desc, name).regexp
  end

  def ABNF.regexp_tree(desc, name=nil)
    ABNF.parse(desc).regexp_tree(name)
  end

  def regexp(name=start_symbol)
    regexp_tree(name).regexp
  end

  # Convert a recursive rule to non-recursive rule if possible.
  # This conversion is *not* perfect.
  # It may fail even if possible.
  # More work (survey) is needed.
  def regexp_tree(name=nil)
    name ||= start_symbol
    env = {}
    each_strongly_connected_component_from(name) {|ns|
      rules = {}
      ns.each {|n|
	rules[n] = @rules[n]
      }

      resolved_rules = {}
      updated = true
      while updated
	updated = false
	ns.reject! {|n| !rules.include?(n)}

	rs = {}
	ns.reverse_each {|n|
	  e = rules[n]
	  rs[n] = e.recursion(ns, n)
	  if rs[n] & OtherRecursion != 0
	    raise StandardError.new("too complex to convert to regexp: #{n} (#{ns.join(', ')})")
	  end
	}

	ns.reverse_each {|n|
	  e = rules[n]
	  r = rs[n]
	  if r & SelfRecursion == 0
	    resolved_rules[n] = e
	    rules.delete n
	    rules.each {|n2, e2| rules[n2] = e2.subst_var {|n3| n3 == n ? e : nil}}
	    updated = true
	    break
	  end
	}
	next if updated

	# X = Y | a
	# Y = X | b
	# => 
	# Y = Y | a | b
	ns.reverse_each {|n|
	  e = rules[n]
	  r = rs[n]
	  if r & JustRecursion != 0 && r & ~(NonRecursion|JustRecursion) == 0
	    e = e.remove_just_recursion(n)
	    resolved_rules[n] = e
	    rules.delete n
	    rules.each {|n2, e2| rules[n2] = e2.subst_var {|n3| n3 == n ? e : nil}}
	    updated = true
	    break
	  end
	}
	next if updated

	# X = X a | b
	# =>
	# X = b a*
	ns.reverse_each {|n|
	  e = rules[n]
	  r = rs[n]
	  if r & LeftRecursion != 0 && r & ~(NonRecursion|JustRecursion|LeftRecursion|SelfRecursion) == 0
	    e = e.remove_left_recursion(n)
	    resolved_rules[n] = e
	    rules.delete n
	    rules.each {|n2, e2| rules[n2] = e2.subst_var {|n3| n3 == n ? e : nil}}
	    updated = true
	    break
	  end
	}
	next if updated

	# X = a X | b
	# =>
	# X = a* b
	ns.reverse_each {|n|
	  e = rules[n]
	  r = rs[n]
	  if r & RightRecursion != 0 && r & ~(NonRecursion|JustRecursion|RightRecursion|SelfRecursion) == 0
	    e = e.remove_right_recursion(n)
	    resolved_rules[n] = e
	    rules.delete n
	    rules.each {|n2, e2| rules[n2] = e2.subst_var {|n3| n3 == n ? e : nil}}
	    updated = true
	    break
	  end
	}
	next if updated
      end

      if 1 < rules.length
	raise StandardError.new("too complex to convert to regexp: (#{ns.join(', ')})")
      end

      if rules.length == 1
	n, e = rules.shift
	r = e.recursion(ns, n)
	if r & OtherRecursion != 0
	  raise StandardError.new("too complex to convert to regexp: #{n} (#{ns.join(', ')})")
	end
	if r == NonRecursion
	  resolved_rules[n] = e
	else
	  # X = a X | b | X c
	  # =>
	  # X = a* b c*
	  left, middle, right = e.split_recursion(n)
	  resolved_rules[n] = Seq.new(Alt.new(left).rep, Alt.new(middle), Alt.new(right).rep)
	end
      end

      class << resolved_rules
        include TSort
	alias tsort_each_node each_key
	def tsort_each_child(n, &block)
	  self[n].each_var {|n2|
	    yield n2 if self.include? n2
	  }
	end
      end

      resolved_rules.tsort_each {|n|
        env[n] = resolved_rules[n].subst_var {|n2|
	  unless env[n2]
	    raise StandardError.new("unresolved nonterminal: #{n}") # bug
	  end
	  env[n2]
	}
      }
    }
    env[name].regexp_tree
  end

  NonRecursion = 1	# X = a
  JustRecursion = 2	# X = Y
  LeftRecursion = 4	# X = Y a
  RightRecursion = 8	# X = a Y
  SelfRecursion = 16	# Y is X in JustRecursion, LeftRecursion and RightRecursion
  OtherRecursion = 32	# otherwise

  class Elt
    def remove_left_recursion(n)
      nonrec, rest = split_left_recursion(n)
      Seq.new(nonrec, rest.rep)
    end

    def remove_right_recursion(n)
      nonrec, rest = split_right_recursion(n)
      Seq.new(rest.rep, nonrec)
    end
  end

  class Alt
    def recursion(syms, lhs)
      @elts.inject(0) {|r, e| r | e.recursion(syms, lhs)}
    end

    def remove_just_recursion(n)
      Alt.new(*@elts.map {|e| e.remove_just_recursion(n)})
    end

    def split_left_recursion(n)
      nonrec = EmptySet
      rest = EmptySet
      @elts.each {|e|
        nonrec1, rest1 = e.split_left_recursion(n)
	nonrec |= nonrec1
	rest |= rest1
      }
      [nonrec, rest]
    end

    def split_right_recursion(n)
      nonrec = EmptySet
      rest = EmptySet
      @elts.each {|e|
        nonrec1, rest1 = e.split_right_recursion(n)
	nonrec |= nonrec1
	rest |= rest1
      }
      [nonrec, rest]
    end

    def split_recursion(n)
      rest_left = EmptySet
      nonrec = EmptySet
      rest_right = EmptySet
      @elts.each {|e|
        rest_left1, nonrec1, rest_right1 = e.split_recursion(n)
	rest_left |= rest_left1
	nonrec |= nonrec1
	rest_right |= rest_right1
      }
      [rest_left, nonrec, rest_right]
    end
  end

  class Seq
    def recursion(syms, lhs)
      case @elts.length
      when 0
        NonRecursion
      when 1
        @elts.first.recursion(syms, lhs)  
      else
	(1...(@elts.length-1)).each {|i|
	  return OtherRecursion if @elts[i].recursion(syms, lhs) != NonRecursion
	}

        r_left = @elts.first.recursion(syms, lhs)
	return OtherRecursion if r_left & ~(NonRecursion|JustRecursion|LeftRecursion|SelfRecursion) != 0
	r_left = (r_left & ~JustRecursion) | LeftRecursion if r_left & JustRecursion != 0

        r_right = @elts.last.recursion(syms, lhs)
	return OtherRecursion if r_right & ~(NonRecursion|JustRecursion|RightRecursion|SelfRecursion) != 0
	r_right = (r_right & ~JustRecursion) | RightRecursion if r_right & JustRecursion != 0

	if r_left == NonRecursion
	  r_right
	elsif r_right == NonRecursion
	  r_left
	else
	  OtherRecursion
	end
      end
    end

    def remove_just_recursion(n)
      self
    end

    def split_left_recursion(n)
      case @elts.length
      when 0
        [self, EmptySet]
      when 1
        @elts.first.split_left_recursion(n)
      else
        nonrec, rest = @elts.first.split_left_recursion(n)
	rest1 = Seq.new(*@elts[1..-1])
	nonrec += rest1
	rest += rest1
	[nonrec, rest]
      end
    end

    def split_right_recursion(n)
      case @elts.length
      when 0
        [self, EmptySet]
      when 1
        @elts.first.split_right_recursion(n)
      else
        nonrec, rest = @elts.last.split_right_recursion(n)
	rest1 = Seq.new(*@elts[0...-1])
	nonrec = rest1 + nonrec
	rest = rest1 + rest
	[nonrec, rest]
      end
    end

    def split_recursion(n)
      case @elts.length
      when 0
        [EmptySet, self, EmptySet]
      when 1
        @elts.first.split_recursion(n)
      else
        leftmost_nonrec, leftmost_rest_right = @elts.first.split_left_recursion(n)
        rightmost_nonrec, rightmost_rest_left = @elts.last.split_right_recursion(n)
	rest_middle = Seq.new(*@elts[1...-1])

	if leftmost_rest_right.empty_set?
	  [leftmost_nonrec + rest_middle + rightmost_rest_left,
	   leftmost_nonrec + rest_middle + rightmost_nonrec,
	   EmptySet]
	elsif rightmost_rest_left.empty_set?
	  [EmptySet,
	   leftmost_nonrec + rest_middle + rightmost_nonrec,
	   leftmost_rest_right + rest_middle + rightmost_nonrec]
	else
	  raise StandardError.new("non left/right recursion") # bug
	end
      end
    end

  end

  class Rep
    def recursion(syms, lhs)
      @elt.recursion(syms, lhs) == NonRecursion ? NonRecursion : OtherRecursion
    end

    def remove_just_recursion(n)
      self
    end

    def split_left_recursion(n)
      [self, EmptySet]
    end
    alias split_right_recursion split_left_recursion

    def split_recursion(n)
      [EmptySet, self, EmptySet]
    end
  end

  class Term
    def recursion(syms, lhs)
      NonRecursion
    end

    def remove_just_recursion(n)
      self
    end

    def split_left_recursion(n)
      [self, EmptySet]
    end
    alias split_right_recursion split_left_recursion

    def split_recursion(n)
      [EmptySet, self, EmptySet]
    end
  end

  class Var
    def recursion(syms, lhs)
      if lhs == self.name
	JustRecursion | SelfRecursion
      elsif syms.include? self.name
	JustRecursion
      else
        NonRecursion
      end
    end

    def remove_just_recursion(n)
      if n == self.name
        EmptySet
      else
	self
      end
    end

    def split_left_recursion(n)
      if n == self.name
	[EmptySet, EmptySequence]
      else
	[self, EmptySet]
      end
    end
    alias split_right_recursion split_left_recursion

    def split_recursion(n)
      if n == self.name
	[EmptySet, EmptySet, EmptySet]
      else
	[EmptySet, self, EmptySet]
      end
    end
  end

  class Alt; def regexp_tree() RegexpTree.alt(*@elts.map {|e| e.regexp_tree}) end end
  class Seq; def regexp_tree() RegexpTree.seq(*@elts.map {|e| e.regexp_tree}) end end
  class Rep; def regexp_tree() @elt.regexp_tree.rep(min, max, greedy) end end
  class Term; def regexp_tree() RegexpTree.charclass(@natset) end end
end
