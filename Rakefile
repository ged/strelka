#!/usr/bin/env rake

begin
	require 'hoe'
rescue LoadError
	abort "This Rakefile requires 'hoe' (gem install hoe)"
end

Hoe.plugin :mercurial
Hoe.plugin :signing

Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec 'strelka' do
	self.readme_file = 'README.rdoc'
	self.history_file = 'History.rdoc'
	self.extra_rdoc_files << 'README.rdoc' << 
		'History.rdoc' << 'IDEAS.textile'

	self.developer 'Michael Granger', 'ged@FaerieMUD.org'

	self.dependency 'mongrel2',        '~> 0.3'
	self.dependency 'configurability', '~> 1.0'
	self.dependency 'inversion',       '~> 0.1.1'

	self.dependency 'tilt',            '~> 1.3', :developer
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
