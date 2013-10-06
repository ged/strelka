#!/usr/bin/env rake

require 'rake/clean'

begin
	require 'hoe'
rescue LoadError
	abort "This Rakefile requires 'hoe' (gem install hoe)"
end

Hoe.plugin :mercurial
Hoe.plugin :signing
Hoe.plugin :deveiate
Hoe.plugin :bundler

Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec 'strelka' do
	self.readme_file = 'README.rdoc'
	self.history_file = 'History.rdoc'
	self.extra_rdoc_files = FileList[ '*.rdoc' ]

	self.developer 'Mahlon E. Smith', 'mahlon@martini.nu'
	self.developer 'Michael Granger', 'ged@FaerieMUD.org'

	self.dependency 'configurability', '~> 2.0'
	self.dependency 'foreman',         '~> 0.62'
	self.dependency 'highline',        '~> 1.6'
	self.dependency 'inversion',       '~> 0.12'
	self.dependency 'loggability',     '~> 0.6'
	self.dependency 'mongrel2',        '~> 0.36'
	self.dependency 'pluggability',    '~> 0.2'
	self.dependency 'sysexits',        '~> 1.1'
	self.dependency 'trollop',         '~> 2.0'
	self.dependency 'uuidtools',       '~> 2.1'
	self.dependency 'safe_yaml',       '~> 0.9'

	self.dependency 'hoe-deveiate',            '~> 0.1',  :developer
	self.dependency 'hoe-bundler',             '~> 1.2',  :developer
	self.dependency 'rspec',                   '~> 0.14', :developer
	self.dependency 'simplecov',               '~> 0.7',  :developer
	self.dependency 'rdoc-generator-fivefish', '~> 0.2',  :developer

	self.license "BSD"
	self.spec_extras[:rdoc_options] = [
		'-t', 'Strelka Web Application Toolkit',
		'-w', '4',
	]

	# Use the Fivefish formatter if run in development
	self.spec_extras[:rdoc_options] += [ '-f', 'fivefish' ] if File.directory?( '.hg' )

	self.require_ruby_version( '>=1.9.3' )
	self.hg_sign_tags = true if self.respond_to?( :hg_sign_tags= )
	self.check_history_on_release = true if self.respond_to?( :check_history_on_release= )

	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end



ENV['VERSION'] ||= hoespec.spec.version.to_s

# Ensure the specs pass before checking in
task 'hg:precheckin' => [ :check_history, :check_manifest, :spec ]


desc "Build a coverage report"
task :coverage do
	ENV["COVERAGE"] = 'yes'
	Rake::Task[:spec].invoke
end

if Rake::Task.task_defined?( '.gemtest' )
	Rake::Task['.gemtest'].clear
	task '.gemtest' do
		$stderr.puts "Not including a .gemtest until I'm confident the test suite is idempotent."
	end
end


# Add admin app testing directories to the clobber list
CLOBBER.include( 'static', 'run', 'log', 'strelka.sqlite' )


