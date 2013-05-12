require "bundler/gem_tasks"

file "lib/abnf/parser.rb" => ["lib/abnf/parser.y"] do |t|
  sh "racc -E -o lib/abnf/parser.rb -v lib/abnf/parser.y"
end

task :build_parser => ["lib/abnf/parser.rb"]

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "lib"
  t.test_files = FileList['test/*_test.rb']
  t.ruby_opts = ['-r./test/test_helper.rb']
  t.verbose = true
end

task :default => [:build_parser, :test]
