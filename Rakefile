require "bundler/gem_tasks"

file "abnf/parser.rb" => ["abnf/parser.y"] do |t|
  sh "racc -E -o abnf/parser.rb -v abnf/parser.y"
end
