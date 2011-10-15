#!/usr/bin/env ruby
#encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'date'
require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/app/paramvalidator'


#####################################################################
###	C O N T E X T S
#####################################################################
describe Strelka::App::ParamValidator do

	TEST_PROFILE = {
		:required		=> [ :required ],
		:optional		=> %w{
			optional number int_constraint float_constraint bool_constraint email_constraint
            host_constraint regexp_w_captures regexp_w_one_capture regexp_w_named_captures
            alpha_constraint alphanumeric_constraint printable_constraint proc_constraint
            uri_constraint word_constraint date_constraint
		},
		:constraints	=> {
			:number                  => /^\d+$/,
			:regexp_w_captures       => /(\w+)(\S+)?/,
			:regexp_w_one_capture    => /(\w+)/,
			:regexp_w_named_captures => /(?<category>[[:upper:]]{3})-(?<sku>\d{12})/,
			:int_constraint          => :integer,
			:float_constraint        => :float,
			:bool_constraint         => :boolean,
			:email_constraint        => :email,
			:uri_constraint          => :uri,
			:host_constraint         => :hostname,
			:alpha_constraint        => :alpha,
			:alphanumeric_constraint => :alphanumeric,
			:printable_constraint    => :printable,
			:word_constraint         => :word,
			:proc_constraint         => Date.method( :parse ),
			:date_constraint         => :date,
		},
	}


	before( :all ) do
		setup_logging( :fatal )
	end

	before(:each) do
		@validator = Strelka::App::ParamValidator.new( TEST_PROFILE )
	end

	after( :all ) do
		reset_logging()
	end


	it "starts out empty" do
		@validator.should be_empty()
		@validator.should_not have_args()
	end

	it "is no longer empty if at least one set of parameters has been validated" do
		@validator.validate( {'required' => "1"} )

		@validator.should_not be_empty()
		@validator.should have_args()
	end

	it "raises an exception on an unknown constraint type" do
		pending "figure out why this isn't working" do
			profile = {
				required: [:required],
				constraints: {
					required: $stderr,
				}
			}
			val = Strelka::App::ParamValidator.new( profile )

			expect {
				val.validate( required: '1' )
			}.to raise_error( /unknown constraint type IO/ )
		end
	end

	# Test index operator interface
	it "provides read and write access to valid args via the index operator" do
		rval = nil

		@validator.validate( {'required' => "1"} )
		@validator[:required].should == "1"

		@validator[:required] = "bar"
		@validator["required"].should == "bar"
	end


	it "untaints valid args if told to do so" do
		rval = nil
		tainted_one = "1"
		tainted_one.taint

		@validator.validate( {'required' => 1, 'number' => tainted_one},
			:untaint_all_constraints => true )

		Strelka.log.debug "Validator: %p" % [@validator]

		@validator[:number].should == "1"
		@validator[:number].tainted?.should be_false()
	end


	it "untaints field names" do
		rval = nil
		tainted_one = "1"
		tainted_one.taint

		@validator.validate( {'required' => 1, 'number' => tainted_one},
			:untaint_all_constraints => true )

		Strelka.log.debug "Validator: %p" % [@validator]

		@validator[:number].should == "1"
		@validator[:number].tainted?.should be_false()
	end


	it "returns the capture from a regexp constraint if it has only one" do
		rval = nil
		params = { 'required' => 1, 'regexp_w_one_capture' => "   ygdrassil   " }

		@validator.validate( params, :untaint_all_constraints => true )

		Strelka.log.debug "Validator: %p" % [@validator]

		@validator[:regexp_w_one_capture].should == 'ygdrassil'
	end

	it "returns the captures from a regexp constraint as an array if it has more than one" do
		rval = nil
		params = { 'required' => 1, 'regexp_w_captures' => "   the1tree(!)   " }

		@validator.validate( params, :untaint_all_constraints => true )

		Strelka.log.debug "Validator: %p" % [@validator]

		@validator[:regexp_w_captures].should == ['the1tree', '(!)']
	end

	it "returns the captures from a regexp constraint with named captures as a Hash" do
		rval = nil
		params = { 'required' => 1, 'regexp_w_named_captures' => "   JVV-886451300133   ".taint }

		@validator.validate( params, :untaint_all_constraints => true )

		Strelka.log.debug "Validator: %p" % [@validator]

		@validator[:regexp_w_named_captures].should == {:category => 'JVV', :sku => '886451300133'}
		@validator[:regexp_w_named_captures][:category].should_not be_tainted()
		@validator[:regexp_w_named_captures][:sku].should_not be_tainted()
	end

	it "returns the captures from a regexp constraint as an array " +
		"even if an optional capture doesn't match anything" do
		rval = nil
		params = { 'required' => 1, 'regexp_w_captures' => "   the1tree   " }

		@validator.validate( params, :untaint_all_constraints => true )

		Strelka.log.debug "Validator: %p" % [@validator]

		@validator[:regexp_w_captures].should == ['the1tree', nil]
	end

	it "knows the names of fields that were required but missing from the parameters" do
		@validator.validate( {} )

		@validator.should have_errors()
		@validator.should_not be_okay()

		@validator.missing.should have(1).members
		@validator.missing.should == ['required']
	end

	it "knows the names of fields that did not meet their constraints" do
		params = {'number' => 'rhinoceros'}
		@validator.validate( params )

		@validator.should have_errors()
		@validator.should_not be_okay()

		@validator.invalid.should have(1).keys
		@validator.invalid.keys.should == ['number']
	end

	it "can return a combined list of all problem parameters, which includes " +
		" both missing and invalid fields" do
		params = {'number' => 'rhinoceros'}
		@validator.validate( params )

		@validator.should have_errors()
		@validator.should_not be_okay()

		@validator.error_fields.should have(2).members
		@validator.error_fields.should include('number')
		@validator.error_fields.should include('required')
	end

	it "can return human descriptions of validation errors" do
		params = {'number' => 'rhinoceros', 'unknown' => "1"}
		@validator.validate( params )

		@validator.error_messages.should have(2).members
		@validator.error_messages.should include("Missing value for 'Required'")
		@validator.error_messages.should include("Invalid value for 'Number'")
	end

	it "can include unknown fields in its human descriptions of validation errors" do
		params = {'number' => 'rhinoceros', 'unknown' => "1"}
		@validator.validate( params )

		@validator.error_messages(true).should have(3).members
		@validator.error_messages(true).should include("Missing value for 'Required'")
		@validator.error_messages(true).should include("Invalid value for 'Number'")
		@validator.error_messages(true).should include("Unknown parameter 'Unknown'")
	end

	it "can use provided descriptions of parameters when constructing human " +
		"validation error messages" do
		descs = {
			:number => "Numeral",
			:required => "Test Name",
		}
		params = {'number' => 'rhinoceros', 'unknown' => "1"}
		@validator.validate( params, :descriptions => descs )

		@validator.error_messages.should have(2).members
		@validator.error_messages.should include("Missing value for 'Test Name'")
		@validator.error_messages.should include("Invalid value for 'Numeral'")
	end

	it "can get and set the profile's descriptions directly" do
		params = {'number' => 'rhinoceros', 'unknown' => "1"}

		@validator.descriptions = {
			number: 'Numeral',
			required: 'Test Name'
		}
		@validator.validate( params )

		@validator.descriptions.should have( 2 ).members
		@validator.error_messages.should have( 2 ).members
		@validator.error_messages.should include("Missing value for 'Test Name'")
		@validator.error_messages.should include("Invalid value for 'Numeral'")
	end

	it "capitalizes the names of simple fields for descriptions" do
		@validator.get_description( "required" ).should == 'Required'
	end

	it "splits apart underbarred field names into capitalized words for descriptions" do
		@validator.get_description( "rodent_size" ).should == 'Rodent Size'
	end

	it "uses the key for descriptions of hash fields" do
		@validator.get_description( "rodent[size]" ).should == 'Size'
	end

	it "uses separate capitalized words for descriptions of hash fields with underbarred keys " do
		@validator.get_description( "castle[baron_id]" ).should == 'Baron Id'
	end

	it "coalesces simple hash fields into a hash of validated values" do
		@validator.validate( {'rodent[size]' => 'unusual'}, :optional => ['rodent[size]'] )

		@validator.valid.should == {'rodent' => {'size' => 'unusual'}}
	end

	it "coalesces complex hash fields into a nested hash of validated values" do
		profile = {
			:optional => [
				'recipe[ingredient][name]',
				'recipe[ingredient][cost]',
				'recipe[yield]'
			]
		}
		args = {
			'recipe[ingredient][name]' => 'nutmeg',
			'recipe[ingredient][cost]' => '$0.18',
			'recipe[yield]' => '2 loaves',
		}

		@validator.validate( args, profile )
		@validator.valid.should == {
			'recipe' => {
				'ingredient' => { 'name' => 'nutmeg', 'cost' => '$0.18' },
				'yield' => '2 loaves'
			}
		}
	end

	it "untaints both keys and values in complex hash fields if untainting is turned on" do
		profile = {
			:required => [
				'recipe[ingredient][rarity]',
			],
			:optional => [
				'recipe[ingredient][name]',
				'recipe[ingredient][cost]',
				'recipe[yield]'
			],
			:constraints	=> {
				'recipe[ingredient][rarity]' => /^([\w\-]+)$/,
			},
			:untaint_all_constraints => true,
		}
		args = {
			'recipe[ingredient][rarity]'.taint => 'super-rare'.taint,
			'recipe[ingredient][name]'.taint => 'nutmeg'.taint,
			'recipe[ingredient][cost]'.taint => '$0.18'.taint,
			'recipe[yield]'.taint => '2 loaves'.taint,
		}

		@validator.validate( args, profile )

		@validator.valid.should == {
			'recipe' => {
				'ingredient' => { 'name' => 'nutmeg', 'cost' => '$0.18', 'rarity' => 'super-rare' },
				'yield' => '2 loaves'
			}
		}

		@validator.valid.keys.all? {|key| key.should_not be_tainted() }
		@validator.valid.values.all? {|key| key.should_not be_tainted() }
		@validator.valid['recipe'].keys.all? {|key| key.should_not be_tainted() }
		@validator.valid['recipe']['ingredient'].keys.all? {|key| key.should_not be_tainted() }
		@validator.valid['recipe']['yield'].should_not be_tainted()
		@validator.valid['recipe']['ingredient']['rarity'].should_not be_tainted()
		@validator.valid['recipe']['ingredient']['name'].should_not be_tainted()
		@validator.valid['recipe']['ingredient']['cost'].should_not be_tainted()
	end

	it "accepts the value 'true' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'true'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_true()
	end

	it "accepts the value 't' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 't'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_true()
	end

	it "accepts the value 'yes' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'yes'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_true()
	end

	it "accepts the value 'y' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'y'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_true()
	end

	it "accepts the value '1' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => '1'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_true()
	end

	it "accepts the value 'false' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'false'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_false()
	end

	it "accepts the value 'f' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'f'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_false()
	end

	it "accepts the value 'no' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'no'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_false()
	end

	it "accepts the value 'n' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'n'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_false()
	end

	it "accepts the value '0' for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => '0'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:bool_constraint].should be_false()
	end

	it "rejects non-boolean parameters for fields with boolean constraints" do
		params = {'required' => '1', 'bool_constraint' => 'peanut'}

		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:bool_constraint].should be_nil()
	end

	it "accepts simple integers for fields with integer constraints" do
		params = {'required' => '1', 'int_constraint' => '11'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:int_constraint].should == 11
	end

	it "accepts '0' for fields with integer constraints" do
		params = {'required' => '1', 'int_constraint' => '0'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:int_constraint].should == 0
	end

	it "accepts negative integers for fields with integer constraints" do
		params = {'required' => '1', 'int_constraint' => '-407'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:int_constraint].should == -407
	end

	it "rejects non-integers for fields with integer constraints" do
		params = {'required' => '1', 'int_constraint' => '11.1'}

		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:int_constraint].should be_nil()
	end

	it "rejects integer values with other cruft in them for fields with integer constraints" do
		params = {'required' => '1', 'int_constraint' => '88licks'}

		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:int_constraint].should be_nil()
	end

	it "accepts simple floats for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '3.14'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == 3.14
	end

	it "accepts negative floats for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '-3.14'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == -3.14
	end

	it "accepts positive floats for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '+3.14'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == 3.14
	end

	it "accepts floats that begin with '.' for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '.1418'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == 0.1418
	end

	it "accepts negative floats that begin with '.' for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '-.171'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == -0.171
	end

	it "accepts positive floats that begin with '.' for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '+.86668001'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == 0.86668001
	end

	it "accepts floats in exponential notation for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '1756e-5'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == 0.01756
	end

	it "accepts negative floats in exponential notation for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '-28e8'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == -28e8
	end

	it "accepts floats that start with '.' in exponential notation for fields with float " +
	   "constraints" do
		params = {'required' => '1', 'float_constraint' => '.5552e-10'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == 0.5552e-10
	end

	it "accepts negative floats that start with '.' in exponential notation for fields with " +
	   "float constraints" do
		params = {'required' => '1', 'float_constraint' => '-.288088e18'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == -0.288088e18
	end

	it "accepts integers for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '288'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == 288.0
	end

	it "accepts negative integers for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '-1606'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == -1606.0
	end

	it "accepts positive integers for fields with float constraints" do
		params = {'required' => '1', 'float_constraint' => '+2600'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:float_constraint].should == 2600.0
	end

	it "accepts dates for fields with date constraints" do
		params = {'required' => '1', 'date_constraint' => '2008-11-18'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:date_constraint].should == Date.parse( '2008-11-18' )
	end


	VALID_URIS = %w{
		http://127.0.0.1
		http://127.0.0.1/
		http://[127.0.0.1]/
		http://ruby-lang.org/
		http://www.rocketboom.com/vlog/rb_08_feb_01
		http://del.icio.us/search/?fr=del_icio_us&p=ruby+arrow&type=all
		http://[FEDC:BA98:7654:3210:FEDC:BA98:7654:3210]:8080/index.html
		http://[1080:0:0:0:8:800:200C:417A]/index.html
		http://[3ffe:2a00:100:7031::1]
		http://[1080::8:800:200C:417A]/foo
		http://[::192.9.5.5]/ipng
		http://[::FFFF:129.144.52.38]:3474/index.html
		http://[2010:836B:4179::836B:4179]

		https://mail.google.com/
		https://127.0.0.1/
		https://r4.com:8080/

		ftp://ftp.ruby-lang.org/pub/ruby/1.0/ruby-0.49.tar.gz
		ftp://crashoverride:god@gibson.ellingsonmineral.com/root/.workspace/.garbage.

		ldap:/o=University%20of%20Michigan,c=US
		ldap://ldap.itd.umich.edu/o=University%20of%20Michigan,c=US
		ldap://ldap.itd.umich.edu/o=University%20of%20Michigan,c=US?postalAddress
		ldap://host.com:6666/o=University%20of%20Michigan,c=US??sub?(cn=Babs%20Jensen)
		ldap://ldap.itd.umich.edu/c=GB?objectClass?one
		ldap://ldap.question.com/o=Question%3f,c=US?mail
		ldap://ldap.netscape.com/o=Babsco,c=US??(int=%5c00%5c00%5c00%5c04)
		ldap:/??sub??bindname=cn=Manager%2co=Foo
		ldap:/??sub??!bindname=cn=Manager%2co=Foo
	  }

	VALID_URIS.each do |uri_string|
		it "accepts #{uri_string} for fields with URI constraints" do
			params = {'required' => '1', 'uri_constraint' => uri_string}

			@validator.validate( params )

			@validator.should be_okay()
			@validator.should_not have_errors()

			@validator[:uri_constraint].should be_a_kind_of( URI::Generic )
			@validator[:uri_constraint].to_s.should == uri_string
		end
	end

	# :FIXME: I don't know LDAP uris very well, so I'm not sure how they're likely to
	# be invalidly-occurring in the wild
	INVALID_URIS = %W{
		glark:

		http:
		http://
		http://_com/vlog/rb_08_feb_01
		http://del.icio.us/search/\x20\x14\x18
		http://FEDC:BA98:7654:3210:FEDC:BA98:7654:3210/index.html
		http://1080:0:0:0:8:800:200C:417A/index.html
		http://3ffe:2a00:100:7031::1
		http://1080::8:800:200C:417A/foo
		http://::192.9.5.5/ipng
		http://::FFFF:129.144.52.38:80/index.html
		http://2010:836B:4179::836B:4179

		https:
		https://user:pass@/
		https://r4.com:nonnumericport/

		ftp:
		ftp:ruby-0.49.tar.gz
		ftp://crashoverride:god@/root/.workspace/.garbage.

		ldap:
		ldap:/o=University\x20of\x20Michigan,c=US
		ldap://ldap.itd.umich.edu/o=University+\x00of+Michigan
	  }

	INVALID_URIS.each do |uri_string|
		it "rejects #{uri_string} for fields with URI constraints" do
			params = {'required' => '1', 'uri_constraint' => uri_string}

			# lambda {
				@validator.validate( params )
			# }.should_not raise_error()

			@validator.should_not be_okay()
			@validator.should have_errors()

			@validator[:uri_constraint].should be_nil()
		end
	end

	it "accepts simple RFC822 addresses for fields with email constraints" do
		params = {'required' => '1', 'email_constraint' => 'jrandom@hacker.ie'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:email_constraint].should == 'jrandom@hacker.ie'
	end

	it "accepts hyphenated domains in RFC822 addresses for fields with email constraints" do
		params = {'required' => '1', 'email_constraint' => 'jrandom@just-another-hacquer.fr'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:email_constraint].should == 'jrandom@just-another-hacquer.fr'
	end

	COMPLEX_ADDRESSES = [
		'ruby+hacker@random-example.org',
		'"ruby hacker"@ph8675309.org',
		'jrandom@[ruby hacquer].com',
		'abcdefghijklmnopqrstuvwxyz@abcdefghijklmnopqrstuvwxyz',
	]
	COMPLEX_ADDRESSES.each do |addy|
		it "accepts #{addy} for fields with email constraints" do
			params = {'required' => '1', 'email_constraint' => addy}

			@validator.validate( params )

			@validator.should be_okay()
			@validator.should_not have_errors()

			@validator[:email_constraint].should == addy
		end
	end


	BOGUS_ADDRESSES = [
		'jrandom@hacquer com',
		'jrandom@ruby hacquer.com',
		'j random@rubyhacquer.com',
		'j random@ruby|hacquer.com',
		'j:random@rubyhacquer.com',
	]
	BOGUS_ADDRESSES.each do |addy|
		it "rejects #{addy} for fields with email constraints" do
			params = {'required' => '1', 'email_constraint' => addy}

			@validator.validate( params )

			@validator.should_not be_okay()
			@validator.should have_errors()

			@validator[:email_constraint].should be_nil()
		end
	end

	it "accepts simple hosts for fields with host constraints" do
		params = {'required' => '1', 'host_constraint' => 'deveiate.org'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:host_constraint].should == 'deveiate.org'
	end

	it "accepts hyphenated hosts for fields with host constraints" do
		params = {'required' => '1', 'host_constraint' => 'your-characters-can-fly.kr'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:host_constraint].should == 'your-characters-can-fly.kr'
	end

	BOGUS_HOSTS = [
		'.',
		'glah ',
		'glah[lock]',
		'glah.be$',
		'indus«tree».com',
	]

	BOGUS_HOSTS.each do |hostname|
		it "rejects #{hostname} for fields with host constraints" do
			params = {'required' => '1', 'host_constraint' => hostname}

			@validator.validate( params )

			@validator.should_not be_okay()
			@validator.should have_errors()

			@validator[:host_constraint].should be_nil()
		end
	end

	it "accepts alpha characters for fields with alpha constraints" do
		params = {'required' => '1', 'alpha_constraint' => 'abelincoln'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:alpha_constraint].should == 'abelincoln'
	end

	it "rejects non-alpha characters for fields with alpha constraints" do
		params = {'required' => '1', 'alpha_constraint' => 'duck45'}

		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:alpha_constraint].should be_nil()
	end

	### 'alphanumeric'
	it "accepts alphanumeric characters for fields with alphanumeric constraints" do
		params = {'required' => '1', 'alphanumeric_constraint' => 'zombieabe11'}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:alphanumeric_constraint].should == 'zombieabe11'
	end

	it "rejects non-alphanumeric characters for fields with alphanumeric constraints" do
		params = {'required' => '1', 'alphanumeric_constraint' => 'duck!ling'}

		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:alphanumeric_constraint].should be_nil()
	end

	### 'printable'
	it "accepts printable characters for fields with 'printable' constraints" do
		test_content = <<-EOF
		I saw you with some kind of medical apparatus strapped to your
        spine. It was all glass and metal, a great crystaline hypodermic
        spider, carrying you into the aether with a humming, crackling sound.
		EOF

		params = {
			'required' => '1',
			'printable_constraint' => test_content
		}

		@validator.validate( params )

		@validator.should be_okay()
		@validator[:printable_constraint].should == test_content
	end

	it "rejects non-printable characters for fields with 'printable' constraints" do
		params = {'required' => '1', 'printable_constraint' => %{\0Something cold\0}}

		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:printable_constraint].should be_nil()
	end


	it "accepts any word characters for fields with 'word' constraints" do
		params = {
			'required' => '1',
			'word_constraint' => "Собака"
		}

		@validator.validate( params )

		@validator.should_not have_errors()
		@validator.should be_okay()

		@validator[:word_constraint].should == params['word_constraint']
	end

	it "accepts parameters for fields with Proc constraints if the Proc returns a true value" do
		test_date = '2007-07-17'
		params = {'required' => '1', 'proc_constraint' => test_date}

		@validator.validate( params )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:proc_constraint].should == Date.parse( test_date )
	end

	it "rejects parameters for fields with Proc constraints if the Proc returns a false value" do
		params = {'required' => '1', 'proc_constraint' => %{::::}}

		@validator.validate( params )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:proc_constraint].should be_nil()
	end

	it "can be merged with another set of parameters" do
		params = {}
		@validator.validate( params )
		newval = @validator.merge( 'required' => '1' )

		newval.should_not equal( @validator )

		@validator.should_not be_okay()
		@validator.should have_errors()
		newval.should be_okay()
		newval.should_not have_errors()

		@validator[:required].should == nil
		newval[:required].should == '1'
	end

	it "can have required parameters merged into it after the initial validation" do
		params = {}
		@validator.validate( params )
		@validator.merge!( 'required' => '1' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:required].should == '1'
	end

	it "can have optional parameters merged into it after the initial validation" do
		params = { 'required' => '1' }
		@validator.validate( params )
		@validator.merge!( 'optional' => 'yep.' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:optional].should == 'yep.'
	end

	it "rejects invalid parameters when they're merged after initial validation" do
		params = { 'required' => '1', 'number' => '88' }
		@validator.validate( params )
		@validator.merge!( 'number' => 'buckwheat noodles' )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:number].should be_nil()
	end

	it "allows valid parameters to be fetched en masse" do
		params = { 'required' => '1', 'number' => '88' }
		@validator.validate( params )
		@validator.values_at( :required, :number ).should == [ '1', '88' ]
	end

	it "treats ArgumentErrors in builtin constraints as validation failures" do
		params = { 'required' => '1', 'number' => 'jalopy' }
		@validator.validate( params )
		@validator.should_not be_okay()
		@validator.should have_errors()
		@validator.error_messages.should == ["Invalid value for 'Number'"]
		@validator[:number].should == nil
	end

end

