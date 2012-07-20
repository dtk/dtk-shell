module DTK::Client
  class AdminCommand < CommandBaseThor
    desc "add-pub-key [PATH-TO-PUB-KEY]","Adds a ssh rsa public key for user. Default PATH-TO-PUB-KEY is <user-home-dir>/.ssh/id_rsa.pub"
    def add_pub_key(path_to_key=nil)
      path_to_key ||= "#{ENV['HOME']}/.ssh/id_rsa.pub" #TODO: very brittle
      unless File.file?(path_to_key)
        raise Error.new("No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)")
      end
      key = File.open(path_to_key){|f|f.read}
      post_body = {
        :key => key.chomp
      }
      post rest_url("user/add_ssh_rsa_pub_key"), post_body
    end
  end
end

