=begin
= visitor.rb
visitor.rb generates stub of visitor pattern.
Using visitor.rb, you don't need to define `accept' method for each class.

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
      def visit_D(_)
        raise NotImplementedError.new
      end

      def visit_E(_)
        raise NotImplementedError.new
      end
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
=end

def visitor_pattern(&generate_methodname)
  generate_methodname ||= lambda {|subclass|
    ('visit_' + subclass.name.sub(/::/, '_')).intern
  }
  Class.new {|c|
    visitor_class = Class.new
    c.const_set('Visitor', visitor_class)
    class << c
      self
    end.instance_eval {
      define_method(:inherited) {|subclass|
	methodname = generate_methodname.call(subclass)
        subclass.class_eval <<-End
	  def accept(v)
	    v.#{methodname} self
	  end
	End
	visitor_class.class_eval {
	  define_method(methodname) {|d| raise NotImplementedError.new}
	}
      }
    }
  }
end
