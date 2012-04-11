#!/usr/bin/env ruby
#encoding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
}

require 'date'
require 'rspec'

require 'spec/lib/helpers'

require 'strelka'
require 'strelka/paramvalidator'


#####################################################################
###	C O N T E X T S
#####################################################################
describe Strelka::ParamValidator do

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end


	before(:each) do
		@validator = Strelka::ParamValidator.new
	end


	it "starts out empty" do
		@validator.should be_empty()
		@validator.should_not have_args()
	end

	it "is no longer empty if at least one set of parameters has been validated" do
		@validator.add( :foo, :integer )

		@validator.validate( {'foo' => "1"} )

		@validator.should_not be_empty()
		@validator.should have_args()
	end

	it "allows constraints to be added" do
		@validator.add( :a_field, :string )
		@validator.param_names.should include( :a_field )
	end

	it "doesn't allow a parameter to be added twice" do
		@validator.add( :a_field, :string )
		expect {
			@validator.add( :a_field, :string )
		}.to raise_error( /parameter :a_field is already defined/i )
		@validator.param_names.should include( :a_field )
	end

	it "allows an existing constraint to be overridden" do
		@validator.add( :a_field, :string )
		@validator.override( :a_field, :integer )
		@validator.param_names.should include( :a_field )
		@validator.validate( 'a_field' => 'a string!' )
		@validator.should have_errors()
		@validator.should_not be_okay()
		@validator.error_messages.should include( "Invalid value for 'A Field'" )
	end

	it "doesn't allow a non-existant parameter to be overridden" do
		expect {
			@validator.override( :a_field, :string )
		}.to raise_error( /no parameter :a_field defined/i )
		@validator.param_names.should_not include( :a_field )
	end

	it "raises an exception on an unknown constraint type" do
		expect {
			@validator.add( :foo, $stderr )
		}.to raise_error( /no builtin :foo validator/ )
	end

	it "retains its parameters through a copy" do
		@validator.add( :foo, :string, :required )
		dup = @validator.dup
		@validator.validate( {} )
		@validator.should_not be_okay()
		@validator.should have_errors()
		@validator.error_messages.should == ["Missing value for 'Foo'"]
	end

	it "provides read and write access to valid args via the index operator" do
		@validator.add( :foo, /^\d+$/ )

		@validator.validate( {'foo' => "1"} )
		@validator[:foo].should == "1"

		@validator[:foo] = "bar"
		@validator["foo"].should == "bar"
	end


	it "untaints valid args if told to do so" do
		tainted_one = "1"
		tainted_one.taint

		@validator.add( :number, /^\d+$/, :untaint )
		@validator.validate( 'number' => tainted_one )

		@validator[:number].should == "1"
		@validator[:number].tainted?.should be_false()
	end


	it "returns the capture from a regexp constraint if it has only one" do
		@validator.add( :treename, /(\w+)/ )
		@validator.validate( 'treename' => "   ygdrassil   " )
		@validator[:treename].should == 'ygdrassil'
	end

	it "returns the captures from a regexp constraint as an array if it has more than one" do
		@validator.add( :stuff, /(\w+)(\S+)?/ )
		@validator.validate( 'stuff' => "   the1tree(!)   " )
		@validator[:stuff].should == ['the1tree', '(!)']
	end

	it "returns the captures from a regexp constraint with named captures as a Hash" do
		@validator.add( :order_number, /(?<category>[[:upper:]]{3})-(?<sku>\d{12})/, :untaint )
		@validator.validate( 'order_number' => "   JVV-886451300133   ".taint )

		@validator[:order_number].should == {:category => 'JVV', :sku => '886451300133'}
		@validator[:order_number][:category].should_not be_tainted()
		@validator[:order_number][:sku].should_not be_tainted()
	end

	it "returns the captures from a regexp constraint as an array " +
		"even if an optional capture doesn't match anything" do
		@validator.add( :amount, /^([\-+])?(\d+(?:\.\d+)?)/ )
		@validator.validate( 'amount' => '2.28' )

		@validator[:amount].should == [ nil, '2.28' ]
	end

	it "knows the names of fields that were required but missing from the parameters" do
		@validator.add( :id, :integer, :required )
		@validator.validate( {} )

		@validator.should have_errors()
		@validator.should_not be_okay()

		@validator.missing.should have(1).members
		@validator.missing.should == ['id']
	end

	it "knows the names of fields that did not meet their constraints" do
		@validator.add( :number, :integer, :required )
		@validator.validate( 'number' => 'rhinoceros' )

		@validator.should have_errors()
		@validator.should_not be_okay()

		@validator.invalid.should have(1).keys
		@validator.invalid.keys.should == ['number']
	end

	it "can return a combined list of all problem parameters, which includes " +
		" both missing and invalid fields" do
		@validator.add( :number, :integer )
		@validator.add( :id, /^(\w{20})$/, :required )

		@validator.validate( 'number' => 'rhinoceros' )

		@validator.should have_errors()
		@validator.should_not be_okay()

		@validator.error_fields.should have(2).members
		@validator.error_fields.should include('number')
		@validator.error_fields.should include('id')
	end

	it "can return human descriptions of validation errors" do
		@validator.add( :number, :integer )
		@validator.add( :id, /^(\w{20})$/, :required )
		@validator.validate( 'number' => 'rhinoceros', 'unknown' => "1" )

		@validator.error_messages.should have(2).members
		@validator.error_messages.should include("Missing value for 'Id'")
		@validator.error_messages.should include("Invalid value for 'Number'")
	end

	it "can include unknown fields in its human descriptions of validation errors" do
		@validator.add( :number, :integer )
		@validator.add( :id, /^(\w{20})$/, :required )
		@validator.validate( 'number' => 'rhinoceros', 'unknown' => "1" )

		@validator.error_messages(true).should have(3).members
		@validator.error_messages(true).should include("Missing value for 'Id'")
		@validator.error_messages(true).should include("Invalid value for 'Number'")
		@validator.error_messages(true).should include("Unknown parameter 'Unknown'")
	end

	it "can use provided descriptions of parameters when constructing human " +
		"validation error messages" do
		@validator.add( :number, :integer, "Numeral" )
		@validator.add( :id, /^(\w{20})$/, "Test Name", :required )
		@validator.validate( 'number' => 'rhinoceros', 'unknown' => "1" )

		@validator.error_messages.should have(2).members
		@validator.error_messages.should include("Missing value for 'Test Name'")
		@validator.error_messages.should include("Invalid value for 'Numeral'")
	end

	it "can get and set the profile's descriptions directly" do
		@validator.add( :number, :integer )
		@validator.add( :id, /^(\w{20})$/, :required )

		@validator.descriptions = {
			number: 'Numeral',
			id:     'Test Name'
		}
		@validator.validate( 'number' => 'rhinoceros', 'unknown' => "1" )

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
		@validator.add( 'rodent[size]', :string )
		@validator.validate( 'rodent[size]' => 'unusual' )

		@validator.valid.should == {'rodent' => {'size' => 'unusual'}}
	end

	it "coalesces complex hash fields into a nested hash of validated values" do
		@validator.add( 'recipe[ingredient][name]', :string )
		@validator.add( 'recipe[ingredient][cost]', :string )
		@validator.add( 'recipe[yield]', :string )

		args = {
			'recipe[ingredient][name]' => 'nutmeg',
			'recipe[ingredient][cost]' => '$0.18',
			'recipe[yield]' => '2 loaves',
		}
		@validator.validate( args )

		@validator.valid.should == {
			'recipe' => {
				'ingredient' => { 'name' => 'nutmeg', 'cost' => '$0.18' },
				'yield' => '2 loaves'
			}
		}
	end

	it "untaints both keys and values in complex hash fields if untainting is turned on" do
		@validator.add( 'recipe[ingredient][rarity]', /^([\w\-]+)$/, :required )
		@validator.add( 'recipe[ingredient][name]', :string )
		@validator.add( 'recipe[ingredient][cost]', :string )
		@validator.add( 'recipe[yield]', :string )
		@validator.untaint_all_constraints

		args = {
			'recipe[ingredient][rarity]'.taint => 'super-rare'.taint,
			'recipe[ingredient][name]'.taint => 'nutmeg'.taint,
			'recipe[ingredient][cost]'.taint => '$0.18'.taint,
			'recipe[yield]'.taint => '2 loaves'.taint,
		}
		@validator.validate( args )

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
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => 'true' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:enabled].should be_true()
	end

	it "accepts the value 't' for fields with boolean constraints" do
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => 't' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:enabled].should be_true()
	end

	it "accepts the value 'yes' for fields with boolean constraints" do
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => 'yes' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:enabled].should be_true()
	end

	it "accepts the value 'y' for fields with boolean constraints" do
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => 'y' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:enabled].should be_true()
	end

	it "accepts the value '1' for fields with boolean constraints" do
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => '1' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:enabled].should be_true()
	end

	it "accepts the value 'false' for fields with boolean constraints" do
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => 'false' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:enabled].should be_false()
	end

	it "accepts the value 'f' for fields with boolean constraints" do
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => 'f' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:enabled].should be_false()
	end

	it "accepts the value 'no' for fields with boolean constraints" do
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => 'no' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:enabled].should be_false()
	end

	it "accepts the value 'n' for fields with boolean constraints" do
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => 'n' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:enabled].should be_false()
	end

	it "accepts the value '0' for fields with boolean constraints" do
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => '0' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:enabled].should be_false()
	end

	it "rejects non-boolean parameters for fields with boolean constraints" do
		@validator.add( :enabled, :boolean )
		@validator.validate( 'enabled' => 'peanut' )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:enabled].should be_nil()
	end

	it "accepts simple integers for fields with integer constraints" do
		@validator.add( :count, :integer )
		@validator.validate( 'count' => '11' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:count].should == 11
	end

	it "accepts '0' for fields with integer constraints" do
		@validator.add( :count, :integer )
		@validator.validate( 'count' => '0' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:count].should == 0
	end

	it "accepts negative integers for fields with integer constraints" do
		@validator.add( :count, :integer )
		@validator.validate( 'count' => '-407' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:count].should == -407
	end

	it "rejects non-integers for fields with integer constraints" do
		@validator.add( :count, :integer )
		@validator.validate( 'count' => '11.1' )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:count].should be_nil()
	end

	it "rejects integer values with other cruft in them for fields with integer constraints" do
		@validator.add( :count, :integer )
		@validator.validate( 'count' => '88licks' )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:count].should be_nil()
	end

	it "accepts simple floats for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '3.14' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == 3.14
	end

	it "accepts negative floats for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '-3.14' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == -3.14
	end

	it "accepts positive floats for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '+3.14' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == 3.14
	end

	it "accepts floats that begin with '.' for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '.1418' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == 0.1418
	end

	it "accepts negative floats that begin with '.' for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '-.171' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == -0.171
	end

	it "accepts positive floats that begin with '.' for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '+.86668001' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == 0.86668001
	end

	it "accepts floats in exponential notation for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '1756e-5' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == 1756e-5
	end

	it "accepts negative floats in exponential notation for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '-28e8' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == -28e8
	end

	it "accepts floats that start with '.' in exponential notation for fields with float " +
	   "constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '.5552e-10' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == 0.5552e-10
	end

	it "accepts negative floats that start with '.' in exponential notation for fields with " +
	   "float constraints" do
	   @validator.add( :amount, :float )
	   @validator.validate( 'amount' => '-.288088e18' )

	   @validator.should be_okay()
	   @validator.should_not have_errors()

	   @validator[:amount].should == -0.288088e18
	end

	it "accepts integers for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '288' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == 288.0
	end

	it "accepts negative integers for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '-1606' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == -1606.0
	end

	it "accepts positive integers for fields with float constraints" do
		@validator.add( :amount, :float )
		@validator.validate( 'amount' => '2600' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:amount].should == 2600.0
	end


	it "accepts dates for fields with date constraints" do
		@validator.add( :expires, :date )
		@validator.validate( 'expires' => '2008-11-18' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:expires].should == Date.parse( '2008-11-18' )
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
			@validator.add( :homepage, :uri )
			@validator.validate( 'homepage' => uri_string )

			@validator.should be_okay()
			@validator.should_not have_errors()

			@validator[:homepage].should be_a_kind_of( URI::Generic )
			@validator[:homepage].to_s.should == uri_string
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
			@validator.add( :homepage, :uri )
			@validator.validate( 'homepage' => uri_string )

			@validator.should_not be_okay()
			@validator.should have_errors()

			@validator[:homepage].should be_nil()
		end
	end

	it "accepts simple RFC822 addresses for fields with email constraints" do
		@validator.add( :email )
		@validator.validate( 'email' => 'jrandom@hacker.ie' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:email].should == 'jrandom@hacker.ie'
	end

	it "accepts hyphenated domains in RFC822 addresses for fields with email constraints" do
		@validator.add( :email )
		@validator.validate( 'email' => 'jrandom@just-another-hacquer.fr' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:email].should == 'jrandom@just-another-hacquer.fr'
	end

	COMPLEX_ADDRESSES = [
		'ruby+hacker@random-example.org',
		'"ruby hacker"@ph8675309.org',
		'jrandom@[ruby hacquer].com',
		'abcdefghijklmnopqrstuvwxyz@abcdefghijklmnopqrstuvwxyz',
	]
	COMPLEX_ADDRESSES.each do |addy|
		it "accepts #{addy} for fields with email constraints" do
			@validator.add( :mail, :email )
			@validator.validate( 'mail' => addy )

			@validator.should be_okay()
			@validator.should_not have_errors()

			@validator[:mail].should == addy
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
			@validator.add( :mail, :email )
			@validator.validate( 'mail' => addy )

			@validator.should_not be_okay()
			@validator.should have_errors()

			@validator[:mail].should be_nil()
		end
	end

	it "accepts simple hosts for fields with host constraints" do
		@validator.add( :host, :hostname )
		@validator.validate( 'host' => 'deveiate.org' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:host].should == 'deveiate.org'
	end

	it "accepts hyphenated hosts for fields with host constraints" do
		@validator.add( :hostname )
		@validator.validate( 'hostname' => 'your-characters-can-fly.kr' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:hostname].should == 'your-characters-can-fly.kr'
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
			@validator.add( :hostname )
			@validator.validate( 'hostname' => hostname )

			@validator.should_not be_okay()
			@validator.should have_errors()

			@validator[:hostname].should be_nil()
		end
	end

	it "accepts alpha characters for fields with alpha constraints" do
		@validator.add( :alpha )
		@validator.validate( 'alpha' => 'abelincoln' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:alpha].should == 'abelincoln'
	end

	it "rejects non-alpha characters for fields with alpha constraints" do
		@validator.add( :alpha )
		@validator.validate( 'alpha' => 'duck45' )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:alpha].should be_nil()
	end

	### 'alphanumeric'
	it "accepts alphanumeric characters for fields with alphanumeric constraints" do
		@validator.add( :username, :alphanumeric )
		@validator.validate( 'username' => 'zombieabe11' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:username].should == 'zombieabe11'
	end

	it "rejects non-alphanumeric characters for fields with alphanumeric constraints" do
		@validator.add( :username, :alphanumeric )
		@validator.validate( 'username' => 'duck!ling' )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:username].should be_nil()
	end

	### 'printable'
	it "accepts printable characters for fields with 'printable' constraints" do
		test_content = <<-EOF
		I saw you with some kind of medical apparatus strapped to your
        spine. It was all glass and metal, a great crystaline hypodermic
        spider, carrying you into the aether with a humming, crackling sound.
		EOF

		@validator.add( :prologue, :printable )
		@validator.validate( 'prologue' => test_content )

		@validator.should be_okay()
		@validator[:prologue].should == test_content
	end

	it "rejects non-printable characters for fields with 'printable' constraints" do
		@validator.add( :prologue, :printable )
		@validator.validate( 'prologue' => %{\0Something cold\0} )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:prologue].should be_nil()
	end


	it "accepts any word characters for fields with 'word' constraints" do
		@validator.add( :vocab_word, :word )
		@validator.validate( 'vocab_word' => "Собака" )

		@validator.should_not have_errors()
		@validator.should be_okay()

		@validator[:vocab_word].should == "Собака"
	end

	it "accepts parameters for fields with Proc constraints if the Proc returns a true value" do
		test_date = '2007-07-17'

		@validator.add( :creation_date ) do |input|
			Date.parse( input )
		end
		@validator.validate( 'creation_date' => test_date )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:creation_date].should == Date.parse( test_date )
	end

	it "rejects parameters for fields with Proc constraints if the Proc returns a false value" do
		@validator.add( :creation_date ) do |input|
			Date.parse( input )
		end
		@validator.validate( 'creation_date' => '::::' )

		@validator.should_not be_okay()
		@validator.should have_errors()

		@validator[:creation_date].should be_nil()
	end

	it "can be merged with another set of parameters" do
		@validator.add( :foo, :integer, :required )
		@validator.validate( {} )
		newval = @validator.merge( 'foo' => '1' )

		newval.should_not equal( @validator )

		@validator.should_not be_okay()
		@validator.should have_errors()
		newval.should be_okay()
		newval.should_not have_errors()

		@validator[:foo].should == nil
		newval[:foo].should == 1
	end

	it "can have required parameters merged into it after the initial validation" do
		@validator.add( :foo, :integer, :required )
		@validator.validate( {} )
		@validator.merge!( 'foo' => '1' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:foo].should == 1
	end

	it "can have optional parameters merged into it after the initial validation" do
		@validator.add( :foom, /^\d+$/ )
		@validator.validate( {} )
		@validator.merge!( 'foom' => '5' )

		@validator.should be_okay()
		@validator.should_not have_errors()

		@validator[:foom].should == '5'
	end

    it "rejects invalid parameters when they're merged after initial validation" do
            @validator.add( :foom, /^\d+$/ )
            @validator.add( :bewm, /^\d+$/ )
            @validator.validate( 'foom' => "1" )

            @validator.merge!( 'bewm' => 'buckwheat noodles' )

            @validator.should_not be_okay()
            @validator.should have_errors()
            @validator[:bewm].should == nil
    end

    it "allows valid parameters to be fetched en masse" do
            @validator.add( :foom, /^\d+$/ )
            @validator.add( :bewm, /^\d+$/ )
            @validator.validate( 'foom' => "1", "bewm" => "2" )
            @validator.values_at( :foom, :bewm ).should == [ '1', '2' ]
    end

    it "treats ArgumentErrors in builtin constraints as validation failures" do
            @validator.add( :integer )
            @validator.validate( 'integer' => 'jalopy' )
            @validator.should_not be_okay()
            @validator.should have_errors()
            @validator[:integer].should be_nil()
    end

end

