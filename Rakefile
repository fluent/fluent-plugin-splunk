require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new do |test|
  test.libs << 'test'
  test.pattern = 'test/test_*.rb'
  test.verbose = true
end

task default: :test

task :coverage do |t|
  ENV['SIMPLE_COV'] = '1'
  Rake::Task['test'].invoke
end
