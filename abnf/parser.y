# RFC 2234
class Parser
rule
  rulelist	:		{ result = nil }
          	| rulelist rule	{ 
				  name = val[1][0]
				  rhs = val[1][1]
				  @grammar.add(name, rhs)
		                  result ||= name
				}

  rule	: defname assign alt	{ result = [val[0], val[2]] }

  alt	: seq
	| alt altop seq	{ result = val[0] | val[2] }

  seq	: rep
	| seq rep	{ result = val[0] + val[1] }

  rep	: element
	| repeat element	{ result = val[1].rep(*val[0]) }

  repeat	: repop		{ result = [0, nil] }
		| repop int	{ result = [0, val[1]] }
  		| int		{ result = [val[0], val[0]] }
		| int repop	{ result = [val[0], nil] }
		| int repop int	{ result = [val[0], val[2]] }

  element	: name	{ result = Var.new(val[0]) }
  		| lparen alt rparen	{ result = val[1] }
		| lbracket alt rbracket	{ result = val[1].rep(0, 1) }
		| val
end

---- header

require 'abnf/grammar'

class ABNF
  def ABNF.parse(desc, dont_merge_core_rules=false)
    grammar = ABNF.new
    Parser.new(grammar).parse(desc)
    grammar.merge(CoreRules) unless dont_merge_core_rules
    grammar
  end

---- inner

  def initialize(grammar)
    @grammar = grammar
  end

  def parse(input)
    @input = input
    yyparse self, :scan
  end

  def scan
    prev = nil
    scan1 {|v|
      if prev
	if prev[0] == :name && v[0] == :assign
	  yield :defname, prev[1]
	else
	  yield prev
	end
      end
      prev = v
    }
    yield prev
  end

  def scan1
    @input.each_line {|line|
      until line.empty?
        case line
	when /\A[ \t\r\n]+/
	  t = $&
	when /\A;/
	  t = line
	when /\A[A-Za-z][A-Za-z0-9\-_]*/ # _ is not permitted by ABNF
	  yield :name, (t = $&).intern
	when /\A=\/?/
	  yield :assign, (t = $&) # | is not permitted by ABNF
	when /\A[\/|]/
	  yield :altop, (t = $&)
	when /\A\*/
	  yield :repop, (t = $&)
	when /\A\(/
	  yield :lparen, (t = $&)
	when /\A\)/
	  yield :rparen, (t = $&)
	when /\A\[/
	  yield :lbracket, (t = $&)
	when /\A\]/
	  yield :rbracket, (t = $&)
	when /\A\d+/
	  yield :int, (t = $&).to_i
	when /\A"([ !#-~]*)"/
	  es = []
	  (t = $&)[1...-1].each_byte {|b|
	    case b
	    when ?A..?Z
	      b2 = b - ?A + ?a
	      es << Term.new(NatSet.new(b, b2))
	    when ?a..?z
	      b2 = b - ?a + ?A
	      es << Term.new(NatSet.new(b, b2))
	    else
	      es << Term.new(NatSet.new(b))
	    end
	  }
	  yield :val, Seq.new(*es)
	when /\A%b([01]+)-([01]+)/
	  t = $&
	  yield :val, Term.new(NatSet.new($1.to_i(2)..$2.to_i(2)))
	when /\A%b[01]+(?:\.[01]+)*/
	  es = []
	  (t = $&).scan(/[0-1]+/) {|v|
	    es << Term.new(NatSet.new(v.to_i(2)))
	  }
	  yield :val, Seq.new(*es)
	when /\A%d([0-9]+)-([0-9]+)/
	  t = $&
	  yield :val, Term.new(NatSet.new($1.to_i..$2.to_i))
	when /\A%d[0-9]+(?:\.[0-9]+)*/
	  es = []
	  (t = $&).scan(/[0-9]+/) {|v|
	    es << Term.new(NatSet.new(v.to_i))
	  }
	  yield :val, Seq.new(*es)
	when /\A%x([0-9A-Fa-f]+)-([0-9A-Fa-f]+)/
	  t = $&
	  yield :val, Term.new(NatSet.new($1.hex..$2.hex))
	when /\A%x[0-9A-Fa-f]+(?:\.[0-9A-Fa-f]+)*/
	  es = []
	  (t = $&).scan(/[0-9A-Fa-f]+/) {|v|
	    es << Term.new(NatSet.new(v.hex))
	  }
	  yield :val, Seq.new(*es)
	when /\A<([\x20-\x3D\x3F-\x7E]*)>/
	  raise ScanError.new("prose-val is not supported: #{$&}")
	else
	  raise ScanError.new(line)
	end
	line[0, t.length] = ''
      end
    }
    yield false, false
  end

  class ScanError < StandardError
  end

---- footer
end
