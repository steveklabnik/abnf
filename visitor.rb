=begin
= visitor.rb
visitor.rb generates stub of visitor pattern.
Using visitor.rb, you don't need to define `accept' method for each class.

visitor.rb requires abstract.rb.

== Example
  C = visitor_pattern

  class D < C
  end

  class E < C
  end

  class V < C::Visitor
    def visit_D(d) p d end
  end

  D.new.accept(V.new) #=> #<D:0x8176048>
  E.new.accept(V.new) #=> NotImplementedError (*not* NoMethodError)

The definitions of C, D and E are same as follows without visitor.rb.

  class C
    class Visitor
      define_abstract_method :visit_D
      define_abstract_method :visit_E
    end
  end

  class D < C
    def accept(v)
      v.visit_D self
    end
  end

  class E < C
    def accept(v)
      v.visit_E self
    end
  end

== Kernel
--- visitor_pattern([element_class[, visitor_class]]) [{|subclass| method name generation}]
    returns the element class which is allocated if ((|element_class|)) is
    not specified.

    If ((|visitor_class|)) is not specified, a class is allocated and
    bound to ((|element_class|))::Visitor.

    When a subclass of ((|element_class|)) C is defined,
    ((|element_class|))#accept which calls visit_C
    and
    an abstract method ((|visitor_class|))#visit_C
    are automatically defined.
    If the name of C contains ::, it is substituted by _.

    If a block is given, it is called to generate a method name.

== generated element class

=== class methods
=end

require 'abstract'

module Kernel
  def visitor_pattern(element_class=nil, visitor_class=nil, &gen_methodname)
    element_class ||= Class.new

    unless visitor_class
      visitor_class = Class.new
      element_class.const_set('Visitor', visitor_class)
    end

    gen_methodname ||= lambda {|subclass|
      ('visit_' + subclass.name.sub(/::/, '_')).intern
    }

    class << element_class
      self
    end.instance_eval {
      define_method(:inherited) {|subclass|
	methodname = gen_methodname.call(subclass)
	subclass.class_eval <<-End
	  def accept(v)
	    v.#{methodname} self
	  end
	End
	visitor_class.class_eval {
	  define_abstract_method methodname
	}
      }
    }

    element_class
  end
end
