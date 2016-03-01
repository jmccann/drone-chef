guard :rspec, all_on_start: true, cmd: "bundle exec rspec" do
  require "guard/rspec/dsl"
  dsl = Guard::RSpec::Dsl.new(self)

  rspec = dsl.rspec
  watch(rspec.spec_helper) { rspec.spec_dir }
  watch(rspec.spec_support) { rspec.spec_dir }
  watch(rspec.spec_files)

  ruby = dsl.ruby
  dsl.watch_spec_files_for(ruby.lib_files)
end

guard :rubocop, all_on_start: true, cli: "-c .rubocop.yml" do
  watch(/.+\.rb\z/)

  watch(%r{(?:.+/)?\.houn\..*\.yml$}) do |m|
    File.dirname(m[0])
  end
end
