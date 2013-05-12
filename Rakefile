require "bundler/gem_tasks"

file "abnf/parser.rb" => ["abnf/parser.y"] do |t|
  sh "racc -E -o abnf/parser.rb -v abnf/parser.y"
end

require 'rake/testtask'


Rake::TestTask.new do |t|
  t.libs << "lib"
  t.test_files = FileList['test/*_test.rb']
  t.ruby_opts = ['-r./test/test_helper.rb']
  t.verbose = true
end

task :default => :test
