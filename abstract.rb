=begin
= abstract.rb implements abstract methods for Ruby.

--- Module#define_abstract_method name

--- Module#abstract_methods

--- Module#abstract?

=end

class Module
  class AbstractMethodCallError < NotImplementedError
  end

  AbstractMethods = {}

  def define_abstract_method(name)
    name = name.intern if String === name
    AbstractMethods[self] ||= []
    AbstractMethods[self] << name
    self.class_eval {
      define_method(name) {raise AbstractMethodCallError.new(name.to_s)}
    }
  end

  def abstract_methods
    methods = []
    ancestors.reverse_each {|mod|
      methods -= mod.instance_methods.map {|name| name.intern}
      methods |= AbstractMethods[mod] if AbstractMethods.include? mod
    }
    methods
  end

  def abstract?
    !abstract_methods.empty?
  end
end

# Hash で集合を表す set.rb を作って使うか?
