require 'abnf'
require 'test/unit'

require 'pp'

class TestABNF < Test::Unit::TestCase
  def test_non_recursion_1
    assert_equal('[Aa]', ABNF.ruby_regexp(<<-'End').to_s)
      n = "a"
    End
  end

  def test_left_recursion_1
    assert_equal('[Aa][Bb]*', ABNF.ruby_regexp(<<-'End').to_s)
      n = "a" | n "b"
    End
  end

  def test_left_recursion_2
    assert_equal('[Aa][Bb]*', ABNF.ruby_regexp(<<-'End').to_s)
      n = "a" | n2 "b"
      n2 = n
    End
  end

  def test_right_recursion_1
    assert_equal('[Bb]*[Aa]', ABNF.ruby_regexp(<<-'End').to_s)
      n = "a" | "b" n
    End
  end

end
