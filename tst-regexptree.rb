require 'regexptree'
require 'test/unit'

require 'pp'

class TestRegexpTree < Test::Unit::TestCase
  def test_whitespace
    assert_equal('(?-mi:\x20\t\n\x23)', RegexpTree.str("\s\t\n#").to_s)
  end
end
