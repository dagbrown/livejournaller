require 'rubygems'

spec = Gem::Specification.new do |s|

    # Basic information.
    s.name = 'livejournaller'
    s.version = File.open("VERSION").read.strip
    s.summary = <<-EOF
    A LiveJournal access library.
    EOF
    s.description = <<-EOF
    This is a library to access the LiveJournal API from Ruby, and a
    script or two to let you write and submit LiveJournal entries from
    the command line.
    EOF
    s.author = "Dave Brown"
    s.email = "livejournaller@dagbrown.com"
    # s.homepage = "http://www.rubyforge.org/projects/gurgitate-mail/"
    # s.rubyforge_project = "gurgitate-mail"

    s.files = Dir.glob("lib/*.rb")
    s.files += Dir.glob("bin/*")
    s.files += Dir.glob("share/*")

    # Load-time details: library and application
    s.require_path = 'lib'                 # Use these for libraries.
    s.autorequire = 'livejournaller'

    s.bindir = "bin"                       # Use these for applications.
    s.executables = %w{ljpost ljsend}
    s.default_executable = "ljpost"

    # Documentation and testing.
    # s.has_rdoc = true
    # s.test_suite_file = "test.rb"
end
