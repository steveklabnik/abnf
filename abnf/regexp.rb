require 'abnf/grammar'
require 'rubyregexp'

module ABNF
  class Grammar
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
  end

  class Alt; def regexp() RubyRegexp.alt(*@elts.map {|e| e.regexp}) end end
  class Seq; def regexp() RubyRegexp.seq(*@elts.map {|e| e.regexp}) end end
  class Rep; def regexp() @elt.regexp.repeat(min, max, greedy) end end
  class Term; def regexp() RubyRegexp.charclass(@natset) end end
end
