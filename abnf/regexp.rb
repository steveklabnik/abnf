require 'abnf/grammar'
require 'rubyregexp'

class ABNF
  def regexp(name)
    env = {}
    each_strongly_connected_component_from(name) {|ns|
      # This condition is too restrictive.
      # Simple expantion should be supported, at least.
      if ns.length != 1
	raise StandardError.new("cannot convert mutually recusive rules to regexp: #{ns.join(', ')}")
      end
      n = ns.first
      e = @rules[n]
      # Convert a recursive rule to non-recursive rule if possible.
      # This conversion is *not* perfect.
      # It may fail even if easily possible.
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
	  if Seq === branch
	    if branch.elts.empty?
	      middle << branch
	    else
	      if Var === branch.elts.first && branch.elts.first.name == n
		right << Seq.new(*branch.elts[1..-1])
	      elsif Var === branch.elts.last && branch.elts.last.name == n
		left << Seq.new(*branch.elts[0...-1])
	      else
		middle << branch
	      end
	    end
	  else
	    middle << branch
	  end
	}
	e = Seq.new(Alt.new(*left).rep, Alt.new(*middle), Alt.new(*right).rep)
      end

      e.each_var {|n2|
	if n == n2
	  raise StandardError.new("too complex to convert to regexp: #{n}")
	end
      }

      env[n] = e.subst_var {|n2| env[n2] }
    }
    env[name].regexp
  end

  # very heuristic method
  def regexp(name)
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
	rs = {}
	rules.each {|n, e|
	  rs[n] = e.recursion(ns)
	  if rs[n] & OtherRecursion != 0
	    raise StandardError.new("too complex to convert to regexp: #{n} (#{ns.join(', ')})")
	  end
	}

	rules.each {|n, e|
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

	rules.each {|n, e|
	  r = rs[n]
	  if r & LeftRecursion != 0 && r & ~(NonRecursion|JustRecursion|LeftRecursion) == 0
	    e = e.remove_left_recursion(n)
	    resolved_rules[n] = e
	    rules.delete n
	    rules.each {|n2, e2| rules[n2] = e2.subst_var {|n3| n3 == n ? e : nil}}
	    updated = true
	    break
	  end
	}
	next if updated

	rules.each {|n, e|
	  r = rs[n]
	  if r & RightRecursion != 0 && r & ~(NonRecursion|JustRecursion|RightRecursion) == 0
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
	r = e.recursion(ns)
	if r & OtherRecursion != 0
	  raise StandardError.new("too complex to convert to regexp: #{n} (#{ns.join(', ')})")
	end
	if r == NonRecursion
	  resolved_rules[n] = e
	else
	  left, middle, right = e.split_recursion(n)
	  resolved_rules[n] = Seq.new(Alt.new(*left).rep, Alt.new(*middle), Alt.new(*right).rep)
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
    env[name].regexp
  end

  NonRecursion = 1	# X = a
  JustRecursion = 2	# X = Y
  LeftRecursion = 4	# X = Y a
  RightRecursion = 8	# X = a Y
  OtherRecursion = 16	# otherwise

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
    def recursion(syms)
      @elts.inject(0) {|r, e| r | e.recursion(syms)}
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
  end

  class Seq
    def recursion(syms)
      case @elts.length
      when 0
        NonRecursion
      when 1
        @elts.first.recursion(syms)  
      else
	(1...(@elts.length-1)).each {|i|
	  return OtherRecursion if @elts[i].recursion(syms) != NonRecursion
	}

        r_left = @elts.first.recursion(syms)
	return OtherRecursion if r_left & ~(NonRecursion|JustRecursion|LeftRecursion) != 0
	r_left = (r_left & ~JustRecursion) | LeftRecursion if r_left & JustRecursion != 0

        r_right = @elts.last.recursion(syms)
	return OtherRecursion if r_right & ~(NonRecursion|JustRecursion|RightRecursion) != 0
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
  end

  class Rep
    def recursion(syms)
      @elt.recursion(syms) == NonRecursion ? NonRecursion : OtherRecursion
    end

    def remove_just_recursion(n)
      self
    end

    def split_left_recursion(n)
      [self, EmptySet]
    end
    alias split_right_recursion split_left_recursion
  end

  class Term
    def recursion(syms)
      NonRecursion
    end

    def remove_just_recursion(n)
      self
    end

    def split_left_recursion(n)
      [self, EmptySet]
    end
    alias split_right_recursion split_left_recursion
  end

  class Var
    def recursion(syms)
      if syms.include? self.name
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
  end

  class Alt; def regexp() RubyRegexp.alt(*@elts.map {|e| e.regexp}) end end
  class Seq; def regexp() RubyRegexp.seq(*@elts.map {|e| e.regexp}) end end
  class Rep; def regexp() @elt.regexp.repeat(min, max, greedy) end end
  class Term; def regexp() RubyRegexp.charclass(@natset) end end
end
