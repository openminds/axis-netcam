# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{axis-netcam}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Matt Zukowski"]
  s.date = %q{2010-02-08}
  s.description = %q{Provides a Ruby interface for interacting with network cameras from Axis Communications.}
  s.email = %q{matt@roughest.net}
  s.extra_rdoc_files = ["CHANGELOG.txt", "LICENSE.txt", "Manifest.txt", "README.txt"]
  s.files = ["CHANGELOG.txt", "LICENSE.txt", "Manifest.txt", "README.txt", "Rakefile", "lib/axis-netcam.rb", "lib/axis-netcam/camera.rb", "lib/axis-netcam/version.rb", "setup.rb", "test/axis-netcam_test.rb", "test/test_helper.rb"]
  s.homepage = %q{http://axis-netcam.rubyforge.org}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{axis-netcam}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Provides a Ruby interface for interacting with network cameras from Axis Communications.}
  s.test_files = ["test/axis-netcam_test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rubyforge>, [">= 2.0.3"])
      s.add_development_dependency(%q<gemcutter>, [">= 0.2.1"])
      s.add_development_dependency(%q<hoe>, [">= 2.5.0"])
    else
      s.add_dependency(%q<rubyforge>, [">= 2.0.3"])
      s.add_dependency(%q<gemcutter>, [">= 0.2.1"])
      s.add_dependency(%q<hoe>, [">= 2.5.0"])
    end
  else
    s.add_dependency(%q<rubyforge>, [">= 2.0.3"])
    s.add_dependency(%q<gemcutter>, [">= 0.2.1"])
    s.add_dependency(%q<hoe>, [">= 2.5.0"])
  end
end