# -*- encoding: utf-8 -*-
# stub: strelka 0.19.0.pre.20191020154423 ruby lib

Gem::Specification.new do |s|
  s.name = "strelka".freeze
  s.version = "0.19.0.pre.20191020154423"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.date = "2019-10-20"
  s.description = "Strelka is a framework for creating and deploying Mongrel2[http://mongrel2.org/] web applications in Ruby.".freeze
  s.files = ["Deploying.rdoc".freeze, "History.rdoc".freeze, "IDEAS.rdoc".freeze, "Plugins.rdoc".freeze, "README.rdoc".freeze, "Rakefile".freeze, "Tutorial.rdoc".freeze, "bin/strelka".freeze, "lib/strelka.rb".freeze, "lib/strelka/app.rb".freeze, "lib/strelka/app/auth.rb".freeze, "lib/strelka/app/errors.rb".freeze, "lib/strelka/app/filters.rb".freeze, "lib/strelka/app/negotiation.rb".freeze, "lib/strelka/app/parameters.rb".freeze, "lib/strelka/app/restresources.rb".freeze, "lib/strelka/app/routing.rb".freeze, "lib/strelka/app/sessions.rb".freeze, "lib/strelka/app/templating.rb".freeze, "lib/strelka/authprovider.rb".freeze, "lib/strelka/authprovider/basic.rb".freeze, "lib/strelka/authprovider/hostaccess.rb".freeze, "lib/strelka/behavior/plugin.rb".freeze, "lib/strelka/cli.rb".freeze, "lib/strelka/command/config.rb".freeze, "lib/strelka/command/discover.rb".freeze, "lib/strelka/command/start.rb".freeze, "lib/strelka/constants.rb".freeze, "lib/strelka/cookie.rb".freeze, "lib/strelka/cookieset.rb".freeze, "lib/strelka/discovery.rb".freeze, "lib/strelka/exceptions.rb".freeze, "lib/strelka/httprequest.rb".freeze, "lib/strelka/httprequest/acceptparams.rb".freeze, "lib/strelka/httprequest/auth.rb".freeze, "lib/strelka/httprequest/negotiation.rb".freeze, "lib/strelka/httprequest/session.rb".freeze, "lib/strelka/httpresponse.rb".freeze, "lib/strelka/httpresponse/negotiation.rb".freeze, "lib/strelka/httpresponse/session.rb".freeze, "lib/strelka/mixins.rb".freeze, "lib/strelka/multipartparser.rb".freeze, "lib/strelka/multirunner.rb".freeze, "lib/strelka/paramvalidator.rb".freeze, "lib/strelka/plugins.rb".freeze, "lib/strelka/router.rb".freeze, "lib/strelka/router/default.rb".freeze, "lib/strelka/router/exclusive.rb".freeze, "lib/strelka/session.rb".freeze, "lib/strelka/session/db.rb".freeze, "lib/strelka/session/default.rb".freeze, "lib/strelka/signal_handling.rb".freeze, "lib/strelka/testing.rb".freeze, "lib/strelka/websocketserver.rb".freeze, "lib/strelka/websocketserver/heartbeat.rb".freeze, "lib/strelka/websocketserver/routing.rb".freeze, "spec/constants.rb".freeze, "spec/data/error.tmpl".freeze, "spec/data/forms/2_images.form".freeze, "spec/data/forms/singleupload.form".freeze, "spec/data/forms/testform.form".freeze, "spec/data/forms/testform_bad.form".freeze, "spec/data/forms/testform_badheaders.form".freeze, "spec/data/forms/testform_metadataonly.form".freeze, "spec/data/forms/testform_msie.form".freeze, "spec/data/forms/testform_multivalue.form".freeze, "spec/data/forms/testform_truncated_metadata.form".freeze, "spec/data/layout.tmpl".freeze, "spec/data/main.tmpl".freeze, "spec/helpers.rb".freeze, "spec/strelka/app/auth_spec.rb".freeze, "spec/strelka/app/errors_spec.rb".freeze, "spec/strelka/app/filters_spec.rb".freeze, "spec/strelka/app/negotiation_spec.rb".freeze, "spec/strelka/app/parameters_spec.rb".freeze, "spec/strelka/app/restresources_spec.rb".freeze, "spec/strelka/app/routing_spec.rb".freeze, "spec/strelka/app/sessions_spec.rb".freeze, "spec/strelka/app/templating_spec.rb".freeze, "spec/strelka/app_spec.rb".freeze, "spec/strelka/authprovider/basic_spec.rb".freeze, "spec/strelka/authprovider/hostaccess_spec.rb".freeze, "spec/strelka/authprovider_spec.rb".freeze, "spec/strelka/cli_spec.rb".freeze, "spec/strelka/cookie_spec.rb".freeze, "spec/strelka/cookieset_spec.rb".freeze, "spec/strelka/discovery_spec.rb".freeze, "spec/strelka/exceptions_spec.rb".freeze, "spec/strelka/httprequest/acceptparams_spec.rb".freeze, "spec/strelka/httprequest/auth_spec.rb".freeze, "spec/strelka/httprequest/negotiation_spec.rb".freeze, "spec/strelka/httprequest/session_spec.rb".freeze, "spec/strelka/httprequest_spec.rb".freeze, "spec/strelka/httpresponse/negotiation_spec.rb".freeze, "spec/strelka/httpresponse/session_spec.rb".freeze, "spec/strelka/httpresponse_spec.rb".freeze, "spec/strelka/mixins_spec.rb".freeze, "spec/strelka/multipartparser_spec.rb".freeze, "spec/strelka/paramvalidator_spec.rb".freeze, "spec/strelka/plugins_spec.rb".freeze, "spec/strelka/router/default_spec.rb".freeze, "spec/strelka/router/exclusive_spec.rb".freeze, "spec/strelka/router_spec.rb".freeze, "spec/strelka/session/db_spec.rb".freeze, "spec/strelka/session/default_spec.rb".freeze, "spec/strelka/session_spec.rb".freeze, "spec/strelka/testing_spec.rb".freeze, "spec/strelka/websocketserver/heartbeat_spec.rb".freeze, "spec/strelka/websocketserver/routing_spec.rb".freeze, "spec/strelka/websocketserver_spec.rb".freeze, "spec/strelka_spec.rb".freeze]
  s.homepage = "https://hg.sr.ht/~ged/Strelka".freeze
  s.licenses = ["BSD-3-Clause".freeze]
  s.rubygems_version = "3.0.6".freeze
  s.summary = "Strelka is a framework for creating and deploying Mongrel2[http://mongrel2.org/] web applications in Ruby.".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<configurability>.freeze, ["~> 3.1"])
      s.add_runtime_dependency(%q<foreman>.freeze, ["~> 0.62"])
      s.add_runtime_dependency(%q<highline>.freeze, ["~> 1.6"])
      s.add_runtime_dependency(%q<inversion>.freeze, ["~> 1.0"])
      s.add_runtime_dependency(%q<loggability>.freeze, ["~> 0.9"])
      s.add_runtime_dependency(%q<mongrel2>.freeze, ["~> 0.53"])
      s.add_runtime_dependency(%q<pluggability>.freeze, ["~> 0.4"])
      s.add_runtime_dependency(%q<sysexits>.freeze, ["~> 1.1"])
      s.add_runtime_dependency(%q<uuidtools>.freeze, ["~> 2.1"])
      s.add_runtime_dependency(%q<safe_yaml>.freeze, ["~> 1.0"])
      s.add_runtime_dependency(%q<gli>.freeze, ["~> 2.14"])
      s.add_development_dependency(%q<rake-deveiate>.freeze, ["~> 0.4"])
      s.add_development_dependency(%q<rspec>.freeze, ["~> 3.8"])
      s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.7"])
      s.add_development_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.1"])
    else
      s.add_dependency(%q<configurability>.freeze, ["~> 3.1"])
      s.add_dependency(%q<foreman>.freeze, ["~> 0.62"])
      s.add_dependency(%q<highline>.freeze, ["~> 1.6"])
      s.add_dependency(%q<inversion>.freeze, ["~> 1.0"])
      s.add_dependency(%q<loggability>.freeze, ["~> 0.9"])
      s.add_dependency(%q<mongrel2>.freeze, ["~> 0.53"])
      s.add_dependency(%q<pluggability>.freeze, ["~> 0.4"])
      s.add_dependency(%q<sysexits>.freeze, ["~> 1.1"])
      s.add_dependency(%q<uuidtools>.freeze, ["~> 2.1"])
      s.add_dependency(%q<safe_yaml>.freeze, ["~> 1.0"])
      s.add_dependency(%q<gli>.freeze, ["~> 2.14"])
      s.add_dependency(%q<rake-deveiate>.freeze, ["~> 0.4"])
      s.add_dependency(%q<rspec>.freeze, ["~> 3.8"])
      s.add_dependency(%q<simplecov>.freeze, ["~> 0.7"])
      s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.1"])
    end
  else
    s.add_dependency(%q<configurability>.freeze, ["~> 3.1"])
    s.add_dependency(%q<foreman>.freeze, ["~> 0.62"])
    s.add_dependency(%q<highline>.freeze, ["~> 1.6"])
    s.add_dependency(%q<inversion>.freeze, ["~> 1.0"])
    s.add_dependency(%q<loggability>.freeze, ["~> 0.9"])
    s.add_dependency(%q<mongrel2>.freeze, ["~> 0.53"])
    s.add_dependency(%q<pluggability>.freeze, ["~> 0.4"])
    s.add_dependency(%q<sysexits>.freeze, ["~> 1.1"])
    s.add_dependency(%q<uuidtools>.freeze, ["~> 2.1"])
    s.add_dependency(%q<safe_yaml>.freeze, ["~> 1.0"])
    s.add_dependency(%q<gli>.freeze, ["~> 2.14"])
    s.add_dependency(%q<rake-deveiate>.freeze, ["~> 0.4"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.8"])
    s.add_dependency(%q<simplecov>.freeze, ["~> 0.7"])
    s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.1"])
  end
end
