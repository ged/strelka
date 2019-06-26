#!/usr/bin/env rspec -cfd
#encoding: utf-8

require_relative '../helpers'

require 'tempfile'
require 'rspec'

require 'strelka/cli'

describe Strelka::CLI do

	before( :all ) do
		testcommands = Module.new
		testcommands.extend( Strelka::CLI::Subcommand )
		testcommands.module_eval do
			command :test_output do |cmd|
				cmd.action do
					prompt.say "Test command!"
				end
			end

			command :test_dryrun do |cmd|
				cmd.action do
					unless_dryrun( "Running the test." ) do
						$stdout.puts "Ran it!"
					end
				end
			end
		end
	end

	after( :each ) do
		described_class.reset_prompt
	end

	describe "output redirection" do

		it "uses STDERR for user interaction" do
			expect {
				described_class.run([ 'test_output' ])
			}.to output( /Test command!\n/ ).to_stderr
		end


		it "redirects its output to STDOUT when run with `-o -`" do
			expect {
				described_class.run([ '-o', '-', 'test_output' ])
			}.to output( /Test command!\n/ ).to_stdout
		end


		it "redirects its output to the named file when run with `-o filename`" do
			tmpfile = Dir::Tmpname.create( 'strelka-command-fileout' ) { }

			begin
				described_class.run([ '-o', tmpfile, 'test_output' ])
				expect( IO.read(tmpfile) ).to match( /Test command!\n/ )
			ensure
				File.unlink( tmpfile ) if tmpfile && File.exist?( tmpfile )
			end
		end

	end


	describe "dry-run mode" do

		it "executes the protected block if dry-run mode isn't enabled" do
			expect {
				described_class.run([ 'test_dryrun' ])
			}.to output( /Ran it!/ ).to_stdout
		end


		it "doesn't execute the block if dry-run mode *is* enabled" do
			expect {
				Loggability.outputting_to( [] ) do
					described_class.run([ '-n', 'test_dryrun' ])
				end
			}.to_not output( /Ran it!/ ).to_stdout
		end

	end

end

