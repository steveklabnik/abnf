require 'tsort'
require 'abnf/grammar'

class ABNF
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

  include TSort
  def tsort_each_node(&block)
    @names.each(&block)
  end
  def tsort_each_child(name)
    return unless @rules.include? name
    @rules.fetch(name).each_var {|n| yield n}
  end
end
