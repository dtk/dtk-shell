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

def dtk_nested_require(dir,*files_x)
  files = (files_x.first.kind_of?(Array) ? files_x.first : files_x) 
  caller_dir = caller.first.gsub(/\/[^\/]+$/,"")
  files.each{|f|require File.expand_path("#{dir}/#{f}",caller_dir)}
end

def dtk_require_dtk_common(common_library)
  dtk_require("../../" + determine_common_folder() + "/lib/#{common_library}")
end

private

##
# Checks for expected names of dtk-common folder and returns name of existing common folder
def determine_common_folder
  POSSIBLE_COMMON_FOLDERS.each do |folder|
    path = File.join(File.dirname(__FILE__),'..','..',folder)
    return folder if File.directory?(path)
  end

  raise "\nCommon directory not found, please make sure that you have cloned dtk-common folder!"
end
