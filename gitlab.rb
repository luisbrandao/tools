require "gitlab"
require 'optparse'

options = {:token => "",
           :url => "https://git.sascar.com.br/api/v4"}
OptionParser.new do |opt|
  opt.on("-t", "--token [token]", String, "gitlab private token") {|o| options[:token] = o }
  opt.on("-u", "--url [url]", String, "gitlab endpoint url") {|o| options[:url] = o }
end.parse!

gitlab = Gitlab.client(endpoint: options[:url], private_token: options[:token])

if ARGV.length < 2
  puts "We need at least 2 arguments"
  exit
end

repo = ARGV[0]
ARGV.delete(repo)

for branch in ARGV
  #gitlab.repo_unprotect_branch(repo,branch)
  gitlab.delete_branch(repo, branch)
  gitlab.create_branch(repo, branch, "master")
  #gitlab.repo_protect_branch(repo, branch)
end
