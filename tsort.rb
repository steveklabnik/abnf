=begin
= tsort.rb

tsort.rb provides a module for topological sorting and
strongly connected components.

== Example

  {1=>[2, 3], 2=>[3], 3=>[], 4=>[]}.tsort
  #=> [3, 2, 1, 4]

  {1=>[2], 2=>[3, 4], 3=>[2], 4=>[]}.strongly_connected_components
  #=> [[4], [2, 3], [1]]


== TSort module
TSort implements topological sorting using Tarjan's algorithm for
strongly connected components.

TSort is designed to be able to use with any object which can be interpreted
as a graph.  TSort requires two methods to interpret a object as a graph:
tsort_each_node and tsort_decendants.

tsort_each_node is used to iterate all nodes over a graph.
tsort_decendants is used to find all decendant nodes of a given node.

The equality of nodes are defined as eql? and hash.
TSort uses Hash internaly.

=== methods
--- tsort 
    returns a topologicaly sorted array of nodes.
    The array is sorted as a leaf to a root:
    I.e. first element of the array has no decendants and
    there is no node which has last element of the array as a decendant.

    If there is a cycle, the exception TSort::Cyclic is raised.

--- tsort_each {|node| ...}
    is the iterater version of tsort method.
    obj.tsort_each is similar to obj.tsort.each but
    modification of obj during the iteration may cause unexpected result.

    tsort_each returns nil.

--- strongly_connected_components
    returns strongly connected components as an array of array of nodes.
    The array is sorted as leafs to roots.
    Each elements of the array represents strongly connected component.

--- each_strongly_connected_component {|nodes| ...}
    is the iterater version of strongly_connected_components method.
    obj.each_strongly_connected_component is similar to
    obj.strongly_connected_components.each but
    modification of obj during the iteration may cause unexpected result.

    each_strongly_connected_component returns nil.

--- tsort_each_node
    should be implemented by a extended class.

--- tsort_decendants
    should be implemented by a extended class.

== Hash
Hash is extended by TSort.

Hash is interpreted as graph as follows:
* key is interpreted as node.
* value should be Array and it is interpreted as decendants of corresponding key.

As a result, tsort_each_node and tsort_decendants is defined as follows:
* tsort_each_node is defined as alias to each_key.
* tsort_decendants is defined as alias to [].

== Array
Array is extended by TSort.

Array is interpreted as graph as follows:
* index is interpreted as node.
* array element should be Array and it is interpreted as decendants of
  corresponding index.

tsort_each_node and tsort_decendants is defined as follows:
* tsort_each_node is defined as alias to each_index.
* tsort_decendants is defined as alias to [].

== Bugs

* (('tsort.rb')) is wrong name.
  Although (('strongly_connected_components.rb')) is correct name,
  it's too long.

== References
R. E. Tarjan, 
Depth First Search and Linear Graph Algorithms,
SIAM Journal on Computing, Vol. 1, No. 2, pp. 146-160, June 1972.

#@Article{Tarjan:1972:DFS,
#  author =       "R. E. Tarjan",
#  key =          "Tarjan",
#  title =        "Depth First Search and Linear Graph Algorithms",
#  journal =      j-SIAM-J-COMPUT,
#  volume =       "1",
#  number =       "2",
#  pages =        "146--160",
#  month =        jun,
#  year =         "1972",
#  CODEN =        "SMJCAT",
#  ISSN =         "0097-5397 (print), 1095-7111 (electronic)",
#  bibdate =      "Thu Jan 23 09:56:44 1997",
#  bibsource =    "Parallel/Multi.bib, Misc/Reverse.eng.bib",
#}
=end

module TSort
  class Cyclic < StandardError
  end

  def tsort
    result = []
    tsort_each {|element| result << element}
    result
  end

  def tsort_each
    each_strongly_connected_component {|component|
      if component.length == 1
        yield component.first
      else
        raise Cyclic.new "topological sort failed: #{component.inspect}"
      end
    }
  end

  def strongly_connected_components
    result = []
    each_strongly_connected_component {|component| result << component}
    result
  end

  def each_strongly_connected_component(&block)
    id_map = {}
    stack = []
    id_map.default = -1
    tsort_each_node {|node|
      if id_map[node] == -1
        strongly_connected_components_rec(node, id_map, stack, &block)
      end
    }
    nil
  end

  def strongly_connected_components_rec(node, id_map, stack, &block)
    reachable_minimum_id = current_id = id_map[node] = id_map.size;
    stack_length = stack.length;
    stack << node

    tsort_decendants(node).each {|next_node|
      next_id = id_map[next_node]
      if next_id != -1
        if !next_id.nil? && next_id < reachable_minimum_id
          reachable_minimum_id = next_id
        end
      else
        sub_minimum_id =
	  strongly_connected_components_rec(next_node, id_map, stack, &block)
        if sub_minimum_id < reachable_minimum_id
          reachable_minimum_id = sub_minimum_id
        end
      end
    }

    if current_id == reachable_minimum_id
      component = stack.slice!(stack_length .. -1)
      yield component
      component.each {|n|
        id_map[n] = nil
      }
    end
    return reachable_minimum_id;
  end

  def tsort_each_node
    raise NotImplementedError.new
  end

  def tsort_decendants(k, &block)
    raise NotImplementedError.new
  end
end

class Hash
  include TSort
  alias tsort_each_node each_key
  alias tsort_decendants []
end

class Array
  include TSort
  alias tsort_each_node each_index
  alias tsort_decendants []
end