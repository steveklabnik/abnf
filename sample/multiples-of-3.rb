require 'abnf'
require 'pp'

rt = ABNF.regexp_tree(<<'End')
s0 = n0 s0 / n1 s2 / n2 s1 / ""
s1 = n0 s1 / n1 s0 / n2 s2
s2 = n0 s2 / n1 s1 / n2 s0
n0 = "0" / "3" / "6" / "9"
n1 = "1" / "4" / "7"
n2 = "2" / "5" / "8"
End

pp rt

r = rt.regexp(true)

100.times {|i|
  p (r !~ i.to_s) == (i%3 != 0)
}
