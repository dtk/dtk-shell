require File.expand_path('../lib/error', File.dirname(__FILE__))

# we leave possibilites that folders user multiple names
# when somebody takes fresh projects from git it is expected that
# person will use dtk-common name
POSSIBLE_COMMON_FOLDERS = ['common','dtk-common']


def dtk_require(*files_x)
  files = (files_x.first.kind_of?(Array) ? files_x.first : files_x) 
  caller_dir = caller.first.gsub(/\/[^\/]+$/,"")
  files.each{|f|require File.expand_path(f,caller_dir)}
end

def dtk_require_from_base(*files_x)
  #different than just calling dtk_require because of change to context give by caller
  dtk_require(*files_x)
end

def dtk_require_common_commands(*files_x)
  dtk_require_from_base(*files_x.map{|f|"commands/common/#{f}"})
end

def dtk_nested_require(dir,*files_x)
  files = (files_x.first.kind_of?(Array) ? files_x.first : files_x) 
  caller_dir = caller.first.gsub(/\/[^\/]+$/,"")

  # invalid command will be send here as such needs to be handled.
  # we will throw DtkClient error as invalid command
  files.each do |f|
    begin
      require File.expand_path("#{dir}/#{f}",caller_dir)
    rescue LoadError => e
      if e.message.include? "#{dir}/#{f}"
        raise DTK::Client::DtkError,"Command '#{f}' not found."
      else
        raise e
      end
    end
  end
end

def dtk_require_dtk_common(common_library)
  # use common folder else common gem
  common_folder = determine_common_folder()

  if common_folder
    dtk_require("../../" + common_folder + "/lib/#{common_library}")
  elsif is_dtk_common_installed?
    require common_library
  else
    raise DTK::Client::DtkError,"Common directory/gem not found, please make sure that you have cloned dtk-common folder or installed dtk common gem!"
  end
end

private

##
# Check if dtk-common gem has been installed if so use common gem. If there is no gem
# logic from dtk_require_dtk_common will try to find commond folder.
# DEVELOPER NOTE: Uninstall dtk-common gem when changing dtk-common to avoid re-building gem.
def is_dtk_common_installed?
  begin
    # if no exception gem is found
    gem 'dtk-common'
    return true
  rescue Gem::LoadError
    return false
  end
end

##
# Checks for expected names of dtk-common folder and returns name of existing common folder
def determine_common_folder
  POSSIBLE_COMMON_FOLDERS.each do |folder|
    path = File.join(File.dirname(__FILE__),'..','..',folder)
    return folder if File.directory?(path)
  end

  return nil
end
