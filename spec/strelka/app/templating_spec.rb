# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'rspec'
require 'inversion'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/app/plugins'
require 'strelka/app/templating'

require 'strelka/behavior/plugin'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Strelka::App::Templating do

	before( :all ) do
		setup_logging( :fatal )
		@request_factory = Mongrel2::RequestFactory.new( route: '/user' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like( "A Strelka::App Plugin" )


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

			subclass.template_map.should == @app.template_map
			subclass.template_map.should_not equal( @app.template_map )
			subclass.layout_template.should == @app.layout_template
			subclass.layout_template.should_not equal( @app.layout_template )
		end

		it "has a Hash of templates" do
			@app.templates.should be_a( Hash )
		end

		it "can add templates that it wants to use to its templates hash" do
			@app.class_eval do
				templates :main => 'main.tmpl'
			end

			@app.templates.should == { :main => 'main.tmpl' }
		end

		it "can declare a layout template" do
			@app.class_eval do
				layout 'layout.tmpl'
			end

			@app.layout.should == 'layout.tmpl'
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
				@app.new.template( :main ).should be_a( Inversion::Template )
			end

			it "can respond with just a template name" do
				@app.class_eval do
					def handle_request( req )
						super { :main }
					end
				end

				res = @app.new.handle( @req )

				res.body.should == "A template for testing the Templating plugin.\n"
				res.status.should == 200
			end

			it "can respond with just a template instance" do
				@app.class_eval do
					def handle_request( req )
						super { self.template(:main) }
					end
				end

				res = @app.new.handle( @req )

				res.body.should == "A template for testing the Templating plugin.\n"
				res.status.should == 200
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

				res.body.should == "A template for testing the Templating plugin.\n"
				res.status.should == 200
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

				res.body.should == "A minimal layout template.\n" +
					"A template for testing the Templating plugin.\n\n"
				res.status.should == 200
			end

		end

	end


end

