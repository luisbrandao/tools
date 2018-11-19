#!/usr/bin/env ruby
require "gitlab"
require 'optparse'

options = {:token => "",
           :url => "https://git.sascar.com.br/api/v4",
           :full => 1}
OptionParser.new do |opt|
  opt.on("-t", "--token [token]", String, "gitlab private token") {|o| options[:token] = o }
  opt.on("-u", "--url [url]", String, "gitlab endpoint url") {|o| options[:url] = o }
  opt.on("-f", "--full", "recreate all default branches") {|o| options[:full] = 0 }
end.parse!

gitlab = Gitlab.client(endpoint: options[:url], private_token: options[:token])

# Lida com os argumentos
if options[:full] == 0
  if (ARGV.length != 1)
    abort ("--full takes only 1 param: repo")
  else
    branches = ['desenvolvimento', 'testes_integrados', 'homologacao']
    puts "Doing for:"
    puts branches
  end
elsif (ARGV.length < 2)
  abort ("We need at least 2 arguments")
end
repo = ARGV[0]
unless options[:full] == 0
  branches = ARGV
  branches.delete(repo)
end

# Verificação de segurança
nogo = ['master', 'deploy']
unless (branches & nogo).empty?
  abort ("Error. no-go banch suplied")
end

# Confere as opções padrão de proteção da branch
default_protect = ["master", "homologacao", "deploy"]
for branch in gitlab.repo_branches(repo)
  for target in default_protect
    if (branch.name == target and not branch.protected)
      gitlab.repo_protect_branch(repo, target)
    end
  end
end

puts "Start ========================"
for branch in branches
  puts "Deleting and recreating: " + branch
  begin
    gitlab.delete_branch(repo, branch)
    gitlab.create_branch(repo, branch, "master")
  rescue Gitlab::Error::NotFound
    puts branch + " does not exist."
  end
end
puts "Finish ======================="
