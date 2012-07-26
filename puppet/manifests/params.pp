class dtk_client::params()
{
  $client_user = 'dtk-client'
  $dtk_username = 'joe'
  $dtk_password = 'r8server'
  $client_user_homedir = "/home/${client_user}"
  $repos = ['client','common']
  $repo_urls = {
    'client' => 'git@github.com:rich-reactor8/dtk-client.git',
    'common' => 'git@github.com:rich-reactor8/dtk-common.git'
  }
  $repo_targets = {
    'client' => 'src',
    'common' => 'common'
  }
}
