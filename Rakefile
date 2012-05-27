#!/usr/bin/env rake

require 'rake/clean'

begin
	require 'hoe'
rescue LoadError
	abort "This Rakefile requires 'hoe' (gem install hoe)"
end

Hoe.plugin :mercurial
Hoe.plugin :signing
Hoe.plugin :manualgen
Hoe.plugin :deveiate

Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec 'strelka' do
	self.readme_file = 'README.rdoc'
	self.history_file = 'History.rdoc'
	self.extra_rdoc_files = FileList[ '*.rdoc' ]

	self.developer 'Michael Granger', 'ged@FaerieMUD.org'

	self.dependency 'trollop',         '~> 1.16'
	self.dependency 'highline',        '~> 1.6'
	self.dependency 'sysexits',        '~> 1.0'
	self.dependency 'formvalidator',   '~> 0.1'
	self.dependency 'inversion',       '~> 0.8'
	self.dependency 'mongrel2',        '~> 0.22'
	self.dependency 'uuidtools',       '~> 2.1'
	self.dependency 'configurability', '~> 1.0'
	self.dependency 'pluginfactory',   '~> 1.0'
	self.dependency 'loggability',     '~> 0.3'
	self.dependency 'foreman',         '~> 0.46'

	self.dependency 'hoe-deveiate',    '~> 0.1', :developer
	self.dependency 'hoe-manualgen',   '~> 0.3', :developer
	self.dependency 'simplecov',       '~> 0.6', :developer

	self.spec_extras[:licenses] = ["BSD"]
	self.spec_extras[:rdoc_options] = ['-f', 'fivefish', '-t', 'Strelka Web Application Toolkit']
	self.require_ruby_version( '>=1.9.2' )
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


