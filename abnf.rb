=begin
= ABNF

== Example

  # IPv6 [RFC2373]
  p %r{\A#{ABNF.regexp <<'End'}\z}o =~ "FEDC:BA98:7654:3210:FEDC:BA98:7654:3210"
    IPv6address = hexpart [ ":" IPv4address ]
    IPv4address = 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT
    hexpart = hexseq | hexseq "::" [ hexseq ] | "::" [ hexseq ]
    hexseq  = hex4 *( ":" hex4)
    hex4    = 1*4HEXDIG
  End

Note that this is wrong because it doesn't match to "::13.1.68.3".

  # URI-reference [RFC2396]
  p %r{\A#{ABNF.regexp <<'End'}\z}o
        URI-reference = [ absoluteURI | relativeURI ] [ "#" fragment ]
        ...
        digit    = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" |
                   "8" | "9"
  End

== ABNF class

=== class methods

--- regexp(abnf_description[, start_symbol])
    converts ((|abnf_description|)) to a regular expression corresponding with
    ((|start_symbol|)).

    If ((|start_symbol|)) is not specified, first symbol in
    ((|abnf_description|)) is used.

= Note

* Wrong ABNF description produces wrong regexp.

=end

require 'tsort'

class ABNF
  def ABNF.regexp(desc, name=nil)
    ABNF.ruby_regexp(desc, name).regexp
  end

  def ABNF.ruby_regexp(desc, name=nil)
    grammar = ABNF.parse(desc)
    grammar.ruby_regexp(name || grammar.start_symbol)
  end

  def ABNF.parse(desc, dont_merge_core_rules=false)
    grammar = ABNF.new
    Parser.new(grammar).parse(desc)
    grammar.merge(CoreRules) unless dont_merge_core_rules
    grammar
  end

  def initialize
    @names = []
    @rules = {}
    @start = nil
  end

  def start_symbol=(name)
    @start = name
  end

  def start_symbol
    return @start if @start
    raise StandardError.new("no symbol defined") if @names.empty?
    @names.first
  end

  def names
    @names.dup
  end

  def merge(g)
    g.each {|name, rhs|
      self.add(name, rhs)
    }
  end

  def [](name)
    @rules[name]
  end

  def []=(name, rhs)
    @names << name unless @rules.include? name
    @rules[name] = rhs
  end

  def add(name, rhs)
    if @rules.include? name
      @rules[name] |= rhs
    else
      @names << name
      @rules[name] = rhs
    end
  end

  def include?(name)
    @rules.include? name
  end

  def each(&block)
    @names.each {|name|
      yield name, @rules[name]
    }
  end

  def delete_unreachable!(starts)
    rules = {}
    id_map = {}
    stack = []
    starts.each {|name|
      next if id_map.include? name
      each_strongly_connected_component_from(name, id_map, stack) {|syms|
        syms.each {|sym|
	  rules[sym] = @rules[sym] if @rules.include? sym
	}
      }
    }
    @rules = rules
    @names.reject! {|name| !@rules.include?(name)}
    self
  end

  include TSort
  def tsort_each_node(&block)
    @names.each(&block)
  end
  def tsort_each_child(name)
    return unless @rules.include? name
    @rules.fetch(name).each_var {|n| yield n}
  end
end

require 'abnf/grammar'
require 'abnf/parser'
require 'abnf/corerules'
require 'abnf/regexp'

class ABNF
  def delete_useless!(starts=nil)
    if starts
      starts = [starts] if Symbol === starts
      delete_unreachable!(starts)
    end

    useful_names = {}
    using_names = {}

    @rules.each {|name, rhs|
      useful_names[name] = true if rhs.useful?(useful_names)
      rhs.each_var {|n|
	(using_names[n] ||= {})[name] = true
      }
    }

    queue = useful_names.keys
    until queue.empty?
      n = queue.pop
      next unless using_names[n]
      using_names[n].keys.each {|name|
	if useful_names[name]
	  using_names[n].delete name
	elsif @rules[name].useful?(useful_names)
	  using_names[n].delete name
	  useful_names[name] = true
	  queue << name
	end
      }
    end

    rules = {}
    @rules.each {|name, rhs|
      rhs = rhs.subst_var {|n| useful_names[n] ? nil : EmptySet}
      rules[name] = rhs unless rhs.empty_set?
    }

    #xxx: raise if some of start symbol becomes empty set?

    @rules = rules
    @names.reject! {|name| !@rules.include?(name)}
    self
  end

  class Alt; def useful?(useful_names) @elts.any? {|e| e.useful?(useful_names)} end end
  class Seq; def useful?(useful_names) @elts.all? {|e| e.useful?(useful_names)} end end
  class Rep; def useful?(useful_names) @min == 0 ? true : @elt.useful?(useful_names) end end
  class Var; def useful?(useful_names) useful_names[@name] end end
  class Term; def useful?(useful_names) true end end
end

if $0 == __FILE__
  # IPv6 [RFC2373]
  # Note that this ABNF description is wrong: e.g. it doesn't match to "::13.1.68.3".
  p %r{\A#{ABNF.regexp <<-'End'}\z}o =~ "FEDC:BA98:7654:3210:FEDC:BA98:7654:3210"
    IPv6address = hexpart [ ":" IPv4address ]
    IPv4address = 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT "." 1*3DIGIT
    hexpart = hexseq | hexseq "::" [ hexseq ] | "::" [ hexseq ]
    hexseq  = hex4 *( ":" hex4)
    hex4    = 1*4HEXDIG
  End

  # URI-reference [RFC2396]
  ABNF.ruby_regexp(<<-'End').pretty_display
        URI-reference = [ absoluteURI | relativeURI ] [ "#" fragment ]
        absoluteURI   = scheme ":" ( hier_part | opaque_part )
        relativeURI   = ( net_path | abs_path | rel_path ) [ "?" query ]

        hier_part     = ( net_path | abs_path ) [ "?" query ]
        opaque_part   = uric_no_slash *uric

        uric_no_slash = escaped | unreserved | ";" | "?" | ":" | "@" |
                        "&" | "=" | "+" | "$" | ","

        net_path      = "//" authority [ abs_path ]
        abs_path      = "/"  path_segments
        rel_path      = rel_segment [ abs_path ]

        rel_segment   = 1*( escaped | unreserved |
                            ";" | "@" | "&" | "=" | "+" | "$" | "," )

        scheme        = alpha *( alpha | digit | "+" | "-" | "." )

        authority     = server | reg_name

        reg_name      = 1*( escaped | unreserved | "$" | "," |
                            ";" | ":" | "@" | "&" | "=" | "+" )

        server        = [ [ userinfo "@" ] hostport ]
        userinfo      = *( escaped | unreserved |
                           ";" | ":" | "&" | "=" | "+" | "$" | "," )

        hostport      = host [ ":" port ]
        host          = hostname | IPv4address
        hostname      = *( domainlabel "." ) toplabel [ "." ]
        domainlabel   = alphanum | alphanum *( alphanum | "-" ) alphanum
        toplabel      = alpha | alpha *( alphanum | "-" ) alphanum
        IPv4address   = 1*digit "." 1*digit "." 1*digit "." 1*digit
        port          = *digit

        path          = [ abs_path | opaque_part ]
        path_segments = segment *( "/" segment )
        segment       = *pchar *( ";" param )
        param         = *pchar
        pchar         = escaped | unreserved |
                        ":" | "@" | "&" | "=" | "+" | "$" | ","

        query         = *uric

        fragment      = *uric

        uric          = reserved | unreserved | escaped
        reserved      = ";" | "/" | "?" | ":" | "@" | "&" | "=" | "+" |
                        "$" | ","
        unreserved    = alphanum | mark
        mark          = "-" | "_" | "." | "!" | "~" | "*" | "'" |
                        "(" | ")"

        escaped       = "%" hex hex
        hex           = digit | "A" | "B" | "C" | "D" | "E" | "F" |
                                "a" | "b" | "c" | "d" | "e" | "f"

        alphanum      = alpha | digit
        alpha         = lowalpha | upalpha

        lowalpha = "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" |
                   "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" |
                   "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
        upalpha  = "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" |
                   "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" |
                   "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z"
        digit    = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" |
                   "8" | "9"
  End
end
