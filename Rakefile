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

Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec 'strelka' do
	self.readme_file = 'README.rdoc'
	self.history_file = 'History.rdoc'
	self.extra_rdoc_files = FileList[ '*.rdoc' ]

	self.developer 'Michael Granger', 'ged@FaerieMUD.org'

	self.dependency 'mongrel2',        '~> 0.9.2'
	self.dependency 'configurability', '~> 1.0'
	self.dependency 'inversion',       '~> 0.2'
	self.dependency 'trollop',         '~> 1.16'
	self.dependency 'highline',        '~> 1.6'
	self.dependency 'formvalidator',   '~> 0.1.5'
	self.dependency 'uuidtools',       '~> 2.1.2'

	self.dependency 'rspec',           '~> 2.6', :developer

	self.spec_extras[:licenses] = ["BSD"]
	self.require_ruby_version( '>=1.9.2' )

	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end

ENV['VERSION'] ||= hoespec.spec.version.to_s

# Ensure the specs pass before checking in
task 'hg:precheckin' => :spec

### Make the ChangeLog update if the repo has changed since it was last built
file '.hg/branch'
file 'ChangeLog' => '.hg/branch' do |task|
	$stderr.puts "Updating the changelog..."
	content = make_changelog()
	File.open( task.name, 'w', 0644 ) do |fh|
		fh.print( content )
	end
end

# Rebuild the ChangeLog immediately before release
task :prerelease => 'ChangeLog'


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


