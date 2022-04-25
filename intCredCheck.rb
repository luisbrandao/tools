#!/usr/bin/env ruby
#require 'irb/completion'
require 'json'
require 'net/http'
require 'uri'
require 'colorize'

require 'optparse'
require 'pp'

options = {:file => "TenantConfig.json", :legacy => 1}
OptionParser.new do |opt|
  opt.on("-f", "--file [file]", String, "TenantConfig file") {|o| options[:file] = o }
  opt.on("-L", "--legacy", "Use legacy check") {|o| options[:legacy] = 0 }
  opt.on("-h", "--help", "Print this help") {puts opt ; puts "Usage: intCredCheck.rb [-f file]"; exit}
end.parse!

file = File.read(options[:file])
data = JSON.parse(file)
exitStatus = 0

data.each do |tenant,array|
  # Detecta se o arquivo ta no formato novo ou no velho.
  if ("#{array.class}" == "String")
    options[:legacy] = 0
  end
  # Check da plataforma ===========================================================================
  if (options[:legacy] == 0)
    # no modo legado, a variavel "array" vai estar com a string do token
    token=array
  else
    token=array["tokenPlataforma"]
  end

  uri = URI.parse("https://#{tenant}.agrotis.io/int/core/api/cidades/listar-por-nome-ibge?filtro=4106902")
  request = Net::HTTP::Get.new(uri)
  request.content_type = "application/json"
  request["X-Auth-Token"] = token
  request["X-Tenant"] = tenant

  req_options = {
    use_ssl: uri.scheme == "https",
    :read_timeout => 10
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  if (response.code != "200")
    puts "#{response.code} | #{tenant} | #{token}".red
  else
    puts "#{response.code} | #{tenant} | #{token}"
  end

 # Check da service layer ===========================================================================
  unless (options[:legacy] == 0)
    # Se não for legado, testar o service layer
    uri = URI.parse("#{array["urlServiceLayerSap"]}/b1s/v1/Login")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "application/json"
    request.body = JSON.dump({
      "UserName" => array["usernameSap"],
      "Password" => array["passwordSap"],
      "CompanyDB" => array["databaseSap"]
    })

    req_options = {
      use_ssl: uri.scheme == "https",
      :read_timeout => 20
    }

    begin
      error=1
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
    rescue Errno::EHOSTUNREACH
      error=0
      resp="NOROUTE"
    rescue Net::ReadTimeout
      error=0
      resp="TIMEOUT"
    end
    # Trata o erro Host unreachable e adiciona um erro custom
    unless (error == 0)
      resp=response.code
    end

    if (resp != "200")
      puts "#{resp} | #{tenant} | #{array["databaseSap"]} |  #{array["usernameSap"]} | #{array["urlServiceLayerSap"]}".red
      exitStatus = 1
    else
      puts "#{resp} | #{tenant} | #{array["databaseSap"]} |  #{array["usernameSap"]} | #{array["urlServiceLayerSap"]}"
    end
  end
end

exit(exitStatus)
