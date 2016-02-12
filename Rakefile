desc "Add copyright headers"
task :headers do
  require 'rubygems'
  require 'copyright_header'

  args = {
    :license_file => '.license_header',
    :add_path => 'bin/:lib/:puppet/',
    :output_dir => '.',
    :guess_extension => true,
  }

  command_line = CopyrightHeader::CommandLine.new( args )
  command_line.execute
end