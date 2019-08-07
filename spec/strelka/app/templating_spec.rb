# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen-string-literal: true

require_relative '../../helpers'

require 'rspec'
require 'inversion'

require 'strelka'
require 'strelka/plugins'
require 'strelka/app/templating'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Templating do

	before( :all ) do
		@request_factory = Mongrel2::RequestFactory.new( route: '/user' )
		@original_template_paths = Inversion::Template.template_paths.dup
	end

	after( :all ) do
		Inversion::Template.template_paths.replace( @original_template_paths )
	end


	it_should_behave_like( "A Strelka Plugin" )


	describe "template discovery" do

		before( :each ) do
			Inversion::Template.template_paths.replace( @original_template_paths )
		end

		it "can discover template directories for loaded gems that depend on Strelka" do
			specs = {}
			specs[:gymnastics]  = make_gemspec( 'gymnastics',  '1.0.0' )
			specs[:cycling]     = make_gemspec( 'cycling',  '1.0.8' )
			specs[:karate]      = make_gemspec( 'karate',    '1.0.0', false )
			specs[:javelin]     = make_gemspec( 'javelin', '1.0.0' )

			expect( Gem::Specification ).to receive( :latest_specs ).and_return( specs.values )

			gymnastics_path  = specs[:gymnastics].full_gem_path
			cycling_path  = specs[:cycling].full_gem_path
			javelin_path = specs[:javelin].full_gem_path

			expect( Dir ).to receive( :glob ).with( 'data/*/templates' ).
				and_return([ "data/foom/templates" ])
			expect( Dir ).to receive( :glob ).with( "#{javelin_path}/data/javelin/templates" ).
				and_return([ "#{javelin_path}/data/javelin/templates" ])
			expect( Dir ).to receive( :glob ).with( "#{gymnastics_path}/data/gymnastics/templates" ).
				and_return([ "#{gymnastics_path}/data/gymnastics/templates" ])

			expect( Dir ).to receive( :glob ).with( "#{cycling_path}/data/cycling/templates" ).
				and_return([])

			template_dirs = described_class.discover_template_dirs

			expect( template_dirs.size ).to eq(  3  )
			expect( template_dirs ).to include(
				Pathname("data/foom/templates"),
				Pathname("#{javelin_path}/data/javelin/templates"),
				Pathname("#{gymnastics_path}/data/gymnastics/templates")
			)
		end


		it "injects template directories from loaded gems into Inversion's template path" do
			specs = {}
			specs[:gymnastics]  = make_gemspec( 'gymnastics',  '1.0.0' )
			specs[:javelin]     = make_gemspec( 'javelin', '1.0.0' )

			expect( Gem::Specification ).to receive( :latest_specs ).and_return( specs.values )

			gymnastics_path = specs[:gymnastics].full_gem_path
			javelin_path    = specs[:javelin].full_gem_path

			expect( Dir ).to receive( :glob ).with( 'data/*/templates' ).
				and_return([ "data/foom/templates" ])
			expect( Dir ).to receive( :glob ).with( "#{javelin_path}/data/javelin/templates" ).
				and_return([ "#{javelin_path}/data/javelin/templates" ])
			expect( Dir ).to receive( :glob ).with( "#{gymnastics_path}/data/gymnastics/templates" ).
				and_return([ "#{gymnastics_path}/data/gymnastics/templates" ])

			Module.new { include Strelka::App::Templating }

			expect( Inversion::Template.template_paths ).to include(
				Pathname("data/foom/templates"),
				Pathname("#{javelin_path}/data/javelin/templates"),
				Pathname("#{gymnastics_path}/data/gymnastics/templates")
			)
		end

	end


	describe "an including App" do

		before( :each ) do
			@app = Class.new( Strelka::App ) do
				plugin :templating
				templates :main => 'main.tmpl'

				def initialize( appid=TEST_APPID, sspec=TEST_SEND_SPEC, rspec=TEST_RECV_SPEC )
					super
				end
			end
			@req = @request_factory.get( '/user/info' )
		end


		it "has its config inherited by subclasses" do
			@app.templates :text => '/tmp/blorp'
			@app.layout 'layout.tmpl'
			subclass = Class.new( @app )

			expect( subclass.template_map ).to eq( @app.template_map )
			expect( subclass.template_map ).to_not equal( @app.template_map )
			expect( subclass.layout_template ).to eq( @app.layout_template )
			expect( subclass.layout_template ).to_not equal( @app.layout_template )
		end

		it "has a Hash of templates" do
			expect( @app.templates ).to be_a( Hash )
		end

		it "can add templates that it wants to use to its templates hash" do
			@app.class_eval do
				templates :main => 'main.tmpl'
			end

			expect( @app.templates ).to eq( { :main => 'main.tmpl' } )
		end

		it "can declare a layout template" do
			@app.class_eval do
				layout 'layout.tmpl'
			end

			expect( @app.layout ).to eq( 'layout.tmpl' )
		end

		describe "instance" do

			before( :all ) do
				basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
				specdir = basedir + 'spec'
				specdata = specdir + 'data'

				tmpl_paths = [ specdata ]
				Inversion::Template.configure( :template_paths => tmpl_paths )
			end

			before( :each ) do
				@app.class_eval do
					templates :main => 'main.tmpl'
				end
			end


			it "can load declared templates by mentioning the symbol" do
				expect( @app.new.template( :main ) ).to be_a( Inversion::Template )
			end

			it "can respond with just a template name" do
				@app.class_eval do
					def handle_request( req )
						super { :main }
					end
				end

				res = @app.new.handle( @req )

				res.body.rewind
				expect( res.body.read ).to eq( "A template for testing the Templating plugin.\n" )
				expect( res.status ).to eq( 200 )
			end

			it "can respond with just a template instance" do
				@app.class_eval do
					def handle_request( req )
						super { self.template(:main) }
					end
				end

				res = @app.new.handle( @req )

				res.body.rewind
				expect( res.body.read ).to eq( "A template for testing the Templating plugin.\n" )
				expect( res.status ).to eq( 200 )
			end

			it "can respond with a Mongrel2::HTTPResponse with a template instance as its body" do
				@app.class_eval do
					def handle_request( req )
						super do
							res = req.response
							res.body = self.template( :main )
							res
						end
					end
				end

				res = @app.new.handle( @req )

				res.body.rewind
				expect( res.body.read ).to eq( "A template for testing the Templating plugin.\n" )
				expect( res.status ).to eq( 200 )
			end


			it "wraps the layout template around whatever gets returned if one is set" do
				@app.class_eval do
					layout 'layout.tmpl'

					def handle_request( req )
						# Super through the plugins and then load the template into the response
						super do
							res = req.response
							res.body = self.template( :main )
							res
						end
					end
				end

				res = @app.new.handle( @req )

				res.body.rewind
				expect( res.body.read ).to eq( "A minimal layout template.\n" +
					"A template for testing the Templating plugin.\n\n" )
				expect( res.status ).to eq( 200 )
			end

			it "doesn't wrap the layout around non-template responses" do
				@app.class_eval do
					layout 'layout.tmpl'

					def handle_request( req )
						# Super through the plugins and then load the template into the response
						super do
							res = req.response
							res.body = self.template( :main ).render
							res
						end
					end
				end

				res = @app.new.handle( @req )

				res.body.rewind
				expect( res.body.read ).to eq( "A template for testing the Templating plugin.\n" )
			end

		end

	end


end

