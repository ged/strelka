source "https://rubygems.org/"

gem 'configurability', '~> 3.1'
gem 'foreman', '~> 0.62'
gem 'highline', '~> 1.6'
gem 'inversion', '~> 1.0'
gem 'loggability', '~> 0.9'
gem 'mongrel2', '~> 0.53'
gem 'pluggability', '~> 0.4'
gem 'sysexits', '~> 1.1'
gem 'uuidtools', '~> 2.1'
gem 'safe_yaml', '~> 1.0'
gem 'gli', '~> 2.14'

group( :development ) do
	gem 'rake-deveiate', '~> 0.4'
	gem 'rspec', '~> 3.8'
	gem 'simplecov', '~> 0.7'
	gem 'rdoc-generator-fivefish', '~> 0.1'
end

