require 'rubygems'
require File.expand_path("require_first", File.dirname(__FILE__))
#TODO: should be common gem
dtk_require_dtk_common("rest_client_wrapper")
dtk_require_dtk_common("hash_object")

########
dtk_require("auxiliary")
dtk_require("core")
dtk_require("error")
dtk_require("pp_columns")
dtk_require("commands")
dtk_require("view_processor")
dtk_require("search_hash")
dtk_require("dtk_logger")


