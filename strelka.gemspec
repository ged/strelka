# -*- encoding: utf-8 -*-
# stub: strelka 0.10.0.pre20150325175929 ruby lib

Gem::Specification.new do |s|
  s.name = "strelka"
  s.version = "0.10.0.pre20150325175929"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Mahlon E. Smith", "Michael Granger"]
  s.cert_chain = ["/Users/ged/.gem/gem-public_cert.pem"]
  s.date = "2015-03-26"
  s.description = "Strelka is a framework for creating and deploying\nMongrel2[http://mongrel2.org/] web applications in Ruby.\n\nIt's named after a lesser known {Russian\ncosmonaut}[http://en.wikipedia.org/wiki/Strelka_(dog)#Belka_and_Strelka] who was\none of the first canine space travelers to orbit the Earth and return alive.\nHer name means \"little arrow\"."
  s.email = ["mahlon@martini.nu", "ged@FaerieMUD.org"]
  s.executables = ["strelka"]
  s.extra_rdoc_files = ["Deploying.rdoc", "History.rdoc", "IDEAS.rdoc", "MILESTONES.rdoc", "Manifest.txt", "Plugins.rdoc", "README.rdoc", "Tutorial.rdoc", "Deploying.rdoc", "History.rdoc", "IDEAS.rdoc", "MILESTONES.rdoc", "Plugins.rdoc", "README.rdoc", "Tutorial.rdoc"]
  s.files = ["ChangeLog", "Deploying.rdoc", "History.rdoc", "IDEAS.rdoc", "MILESTONES.rdoc", "Manifest.txt", "Plugins.rdoc", "README.rdoc", "Rakefile", "Tutorial.rdoc", "bin/strelka", "contrib/hoetemplate/History.rdoc.erb", "contrib/hoetemplate/Manifest.txt.erb", "contrib/hoetemplate/README.rdoc.erb", "contrib/hoetemplate/Rakefile.erb", "contrib/hoetemplate/data/project/apps/file_name_app", "contrib/hoetemplate/data/project/templates/layout.tmpl.erb", "contrib/hoetemplate/data/project/templates/top.tmpl.erb", "contrib/hoetemplate/lib/file_name.rb.erb", "contrib/hoetemplate/spec/file_name_spec.rb.erb", "contrib/strelka-dogs/doggie6.svg", "contrib/strelka-dogs/doggie7.svg", "examples/Procfile", "examples/apps/auth-demo", "examples/apps/auth-demo2", "examples/apps/hello-world", "examples/apps/sessions-demo", "examples/apps/upload-demo", "examples/apps/ws-chat", "examples/apps/ws-echo", "examples/config.yml", "examples/gen-config.rb", "examples/static/examples.css", "examples/static/examples.html", "examples/strelka.conf.example", "examples/templates/auth-form.tmpl", "examples/templates/auth-success.tmpl", "examples/templates/layout.tmpl", "examples/templates/upload-form.tmpl", "examples/templates/upload-success.tmpl", "lib/strelka.rb", "lib/strelka/app.rb", "lib/strelka/app/auth.rb", "lib/strelka/app/errors.rb", "lib/strelka/app/filters.rb", "lib/strelka/app/negotiation.rb", "lib/strelka/app/parameters.rb", "lib/strelka/app/restresources.rb", "lib/strelka/app/routing.rb", "lib/strelka/app/sessions.rb", "lib/strelka/app/templating.rb", "lib/strelka/authprovider.rb", "lib/strelka/authprovider/basic.rb", "lib/strelka/authprovider/hostaccess.rb", "lib/strelka/behavior/plugin.rb", "lib/strelka/constants.rb", "lib/strelka/cookie.rb", "lib/strelka/cookieset.rb", "lib/strelka/discovery.rb", "lib/strelka/exceptions.rb", "lib/strelka/httprequest.rb", "lib/strelka/httprequest/acceptparams.rb", "lib/strelka/httprequest/auth.rb", "lib/strelka/httprequest/negotiation.rb", "lib/strelka/httprequest/session.rb", "lib/strelka/httpresponse.rb", "lib/strelka/httpresponse/negotiation.rb", "lib/strelka/httpresponse/session.rb", "lib/strelka/mixins.rb", "lib/strelka/multipartparser.rb", "lib/strelka/paramvalidator.rb", "lib/strelka/plugins.rb", "lib/strelka/router.rb", "lib/strelka/router/default.rb", "lib/strelka/router/exclusive.rb", "lib/strelka/session.rb", "lib/strelka/session/db.rb", "lib/strelka/session/default.rb", "lib/strelka/testing.rb", "lib/strelka/websocketserver.rb", "lib/strelka/websocketserver/routing.rb", "spec/constants.rb", "spec/data/error.tmpl", "spec/data/forms/2_images.form", "spec/data/forms/singleupload.form", "spec/data/forms/testform.form", "spec/data/forms/testform_bad.form", "spec/data/forms/testform_badheaders.form", "spec/data/forms/testform_metadataonly.form", "spec/data/forms/testform_msie.form", "spec/data/forms/testform_multivalue.form", "spec/data/forms/testform_truncated_metadata.form", "spec/data/layout.tmpl", "spec/data/main.tmpl", "spec/helpers.rb", "spec/strelka/app/auth_spec.rb", "spec/strelka/app/errors_spec.rb", "spec/strelka/app/filters_spec.rb", "spec/strelka/app/negotiation_spec.rb", "spec/strelka/app/parameters_spec.rb", "spec/strelka/app/restresources_spec.rb", "spec/strelka/app/routing_spec.rb", "spec/strelka/app/sessions_spec.rb", "spec/strelka/app/templating_spec.rb", "spec/strelka/app_spec.rb", "spec/strelka/authprovider/basic_spec.rb", "spec/strelka/authprovider/hostaccess_spec.rb", "spec/strelka/authprovider_spec.rb", "spec/strelka/cookie_spec.rb", "spec/strelka/cookieset_spec.rb", "spec/strelka/discovery_spec.rb", "spec/strelka/exceptions_spec.rb", "spec/strelka/httprequest/acceptparams_spec.rb", "spec/strelka/httprequest/auth_spec.rb", "spec/strelka/httprequest/negotiation_spec.rb", "spec/strelka/httprequest/session_spec.rb", "spec/strelka/httprequest_spec.rb", "spec/strelka/httpresponse/negotiation_spec.rb", "spec/strelka/httpresponse/session_spec.rb", "spec/strelka/httpresponse_spec.rb", "spec/strelka/mixins_spec.rb", "spec/strelka/multipartparser_spec.rb", "spec/strelka/paramvalidator_spec.rb", "spec/strelka/plugins_spec.rb", "spec/strelka/router/default_spec.rb", "spec/strelka/router/exclusive_spec.rb", "spec/strelka/router_spec.rb", "spec/strelka/session/db_spec.rb", "spec/strelka/session/default_spec.rb", "spec/strelka/session_spec.rb", "spec/strelka/websocketserver/routing_spec.rb", "spec/strelka/websocketserver_spec.rb", "spec/strelka_spec.rb"]
  s.homepage = "http://deveiate.org/projects/Strelka"
  s.licenses = ["BSD"]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0")
  s.rubygems_version = "2.4.6"
  s.signing_key = "/Volumes/Keys/ged-private_gem_key.pem"
  s.summary = "Strelka is a framework for creating and deploying Mongrel2[http://mongrel2.org/] web applications in Ruby"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<configurability>, ["~> 2.1"])
      s.add_runtime_dependency(%q<foreman>, ["~> 0.62"])
      s.add_runtime_dependency(%q<highline>, ["~> 1.6"])
      s.add_runtime_dependency(%q<inversion>, ["~> 0.12"])
      s.add_runtime_dependency(%q<loggability>, ["~> 0.9"])
      s.add_runtime_dependency(%q<mongrel2>, [">= 0.43.1", "~> 0.43"])
      s.add_runtime_dependency(%q<pluggability>, ["~> 0.4"])
      s.add_runtime_dependency(%q<sysexits>, ["~> 1.1"])
      s.add_runtime_dependency(%q<trollop>, ["~> 2.0"])
      s.add_runtime_dependency(%q<uuidtools>, ["~> 2.1"])
      s.add_runtime_dependency(%q<safe_yaml>, ["~> 1.0"])
      s.add_development_dependency(%q<hoe-mercurial>, ["~> 1.4"])
      s.add_development_dependency(%q<hoe-deveiate>, ["~> 0.6"])
      s.add_development_dependency(%q<hoe-highline>, ["~> 0.2"])
      s.add_development_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_development_dependency(%q<rspec>, ["~> 3.0"])
      s.add_development_dependency(%q<simplecov>, ["~> 0.7"])
      s.add_development_dependency(%q<rdoc-generator-fivefish>, ["~> 0.1"])
      s.add_development_dependency(%q<hoe>, ["~> 3.13"])
    else
      s.add_dependency(%q<configurability>, ["~> 2.1"])
      s.add_dependency(%q<foreman>, ["~> 0.62"])
      s.add_dependency(%q<highline>, ["~> 1.6"])
      s.add_dependency(%q<inversion>, ["~> 0.12"])
      s.add_dependency(%q<loggability>, ["~> 0.9"])
      s.add_dependency(%q<mongrel2>, [">= 0.43.1", "~> 0.43"])
      s.add_dependency(%q<pluggability>, ["~> 0.4"])
      s.add_dependency(%q<sysexits>, ["~> 1.1"])
      s.add_dependency(%q<trollop>, ["~> 2.0"])
      s.add_dependency(%q<uuidtools>, ["~> 2.1"])
      s.add_dependency(%q<safe_yaml>, ["~> 1.0"])
      s.add_dependency(%q<hoe-mercurial>, ["~> 1.4"])
      s.add_dependency(%q<hoe-deveiate>, ["~> 0.6"])
      s.add_dependency(%q<hoe-highline>, ["~> 0.2"])
      s.add_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_dependency(%q<rspec>, ["~> 3.0"])
      s.add_dependency(%q<simplecov>, ["~> 0.7"])
      s.add_dependency(%q<rdoc-generator-fivefish>, ["~> 0.1"])
      s.add_dependency(%q<hoe>, ["~> 3.13"])
    end
  else
    s.add_dependency(%q<configurability>, ["~> 2.1"])
    s.add_dependency(%q<foreman>, ["~> 0.62"])
    s.add_dependency(%q<highline>, ["~> 1.6"])
    s.add_dependency(%q<inversion>, ["~> 0.12"])
    s.add_dependency(%q<loggability>, ["~> 0.9"])
    s.add_dependency(%q<mongrel2>, [">= 0.43.1", "~> 0.43"])
    s.add_dependency(%q<pluggability>, ["~> 0.4"])
    s.add_dependency(%q<sysexits>, ["~> 1.1"])
    s.add_dependency(%q<trollop>, ["~> 2.0"])
    s.add_dependency(%q<uuidtools>, ["~> 2.1"])
    s.add_dependency(%q<safe_yaml>, ["~> 1.0"])
    s.add_dependency(%q<hoe-mercurial>, ["~> 1.4"])
    s.add_dependency(%q<hoe-deveiate>, ["~> 0.6"])
    s.add_dependency(%q<hoe-highline>, ["~> 0.2"])
    s.add_dependency(%q<rdoc>, ["~> 4.0"])
    s.add_dependency(%q<rspec>, ["~> 3.0"])
    s.add_dependency(%q<simplecov>, ["~> 0.7"])
    s.add_dependency(%q<rdoc-generator-fivefish>, ["~> 0.1"])
    s.add_dependency(%q<hoe>, ["~> 3.13"])
  end
end
