require 'regexptree'
require 'test/unit'

require 'pp'

class TestRegexpTree < Test::Unit::TestCase
  def test_whitespace
    assert_equal('(?i-m:\x20\t\n\x23)', RegexpTree.str("\s\t\n#").to_s)
  end

  def test_case_insensitive
    assert_equal(true, (RegexpTree.str("a")|RegexpTree.str("A")).case_insensitive?)
    assert_equal(false, (RegexpTree.str("a")|RegexpTree.str("b")).case_insensitive?)
  end
end
