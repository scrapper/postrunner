require "bundler/gem_tasks"
require "rspec/core/rake_task"

# Add the include path for the fit4ruby library. We assume it is located in
# the same directory as the postrunner directory.
fit4ruby = File.realpath(File.join(File.dirname(__FILE__), '..',
                                                'fit4ruby', 'lib'))
if ENV['RUBYLIB']
  ENV['RUBYLIB'] += ":#{fit4ruby}"
else
  ENV['RUBYLIB'] = fit4ruby
end

RSpec::Core::RakeTask.new

task :default => :spec
task :test => :spec

