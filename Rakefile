#!/usr/bin/env rake

require 'rake/clean'

begin
	require 'hoe'
rescue LoadError
	abort "This Rakefile requires 'hoe' (gem install hoe)"
end

GEMSPEC = 'strelka.gemspec'

Hoe.plugin :mercurial
Hoe.plugin :signing
Hoe.plugin :deveiate

Hoe.plugins.delete :rubyforge

hoespec = Hoe.spec 'strelka' do
	self.readme_file = 'README.rdoc'
	self.history_file = 'History.rdoc'
	self.extra_rdoc_files = FileList[ '*.rdoc' ]
	self.license "BSD"

	self.developer 'Mahlon E. Smith', 'mahlon@martini.nu'
	self.developer 'Michael Granger', 'ged@FaerieMUD.org'

	self.dependency 'configurability', '~> 2.1'
	self.dependency 'foreman',         '~> 0.62'
	self.dependency 'highline',        '~> 1.6'
	self.dependency 'inversion',       '~> 0.12'
	self.dependency 'loggability',     '~> 0.9'
	self.dependency 'mongrel2',        ['~> 0.43', '>= 0.43.1']
	self.dependency 'pluggability',    '~> 0.4'
	self.dependency 'sysexits',        '~> 1.1'
	self.dependency 'trollop',         '~> 2.0'
	self.dependency 'uuidtools',       '~> 2.1'
	self.dependency 'safe_yaml',       '~> 1.0'

	self.dependency 'hoe-deveiate',            '~> 0.3',  :developer
	self.dependency 'rspec',                   '~> 3.0',  :developer
	self.dependency 'simplecov',               '~> 0.7',  :developer
	self.dependency 'rdoc-generator-fivefish', '~> 0.1',  :developer

	self.require_ruby_version( '>=2.0.0' )
	self.hg_sign_tags = true if self.respond_to?( :hg_sign_tags= )
	self.check_history_on_release = true if self.respond_to?( :check_history_on_release= )
	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end

ENV['VERSION'] ||= hoespec.spec.version.to_s

# Ensure the specs pass before checking in
task 'hg:precheckin' => [:check_history, :check_manifest, :spec]

if Rake::Task.task_defined?( '.gemtest' )
	Rake::Task['.gemtest'].clear
	task '.gemtest' do
		$stderr.puts "Not including a .gemtest until I'm confident the test suite is idempotent."
	end
end

desc "Build a coverage report"
task :coverage do
	ENV["COVERAGE"] = 'yes'
	Rake::Task[:spec].invoke
end


# Use the fivefish formatter for docs generated from development checkout
if File.directory?( '.hg' )
	require 'rdoc/task'

	Rake::Task[ 'docs' ].clear
	RDoc::Task.new( 'docs' ) do |rdoc|
	rdoc.main = "README.rdoc"
	rdoc.rdoc_files.include( "*.rdoc", "ChangeLog", "lib/**/*.rb" )
	rdoc.generator = :fivefish
	rdoc.title = "Strelka: A Ruby Web Framework"
	rdoc.rdoc_dir = 'doc'
	end
end

task :gemspec => GEMSPEC
file GEMSPEC => __FILE__
task GEMSPEC do |task|
	spec = $hoespec.spec
	spec.files.delete( '.gemtest' )
	spec.signing_key = nil
	spec.cert_chain = [ 'certs/mahlon.pem', 'certs/ged.pem' ]
	spec.version = "#{spec.version.bump}.0.pre#{Time.now.strftime("%Y%m%d%H%M%S")}"
	File.open( task.name, 'w' ) do |fh|
		fh.write( spec.to_ruby )
	end
end

CLOBBER.include( GEMSPEC.to_s )
task :default => :gemspec
