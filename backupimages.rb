#!/usr/bin/env ruby
require 'aws-sdk-ec2'  # gem install 'aws-sdk'
require 'optparse'

options = {:region => "sa-east-1"}
OptionParser.new do |opt|
  opt.on("-r", "--region [REGION]", String, "Region in which backup will be performed. ex: sa-east-1(default), us-east-1") {|o| options[:region] = o }
end.parse!

def timestamp()
    Time.now.strftime '%Y-%m-%d'
end
def makeImage(instance)
  name = getName(instance)
  instance.create_image({
    dry_run: false,
    name: timestamp + " - " + name,
    description: "Automated backup of " + name + " - " + timestamp,
    no_reboot: true,
  })
end
def getName(instance)
  instance.tags.each do |tag|
    return tag.value if tag.key == 'Name'
  end
end

ec2 = Aws::EC2::Resource.new(:region => options[:region])

filtros = [
  {:name => 'instance-state-name', :values => ['running'] },
  {:name => 'tag:Backup', :values => ['True']}
]
puts "-------------------------------------------"
ec2.instances({:filters => filtros}).each do |i|
  begin
    puts 'Nome   ' + getName(i)
    makeImage(i)
  rescue
    puts "The image: |" + timestamp + " - " + getName(i) + "|"
    puts "Already exists. Doing nothing"
  end
  puts "-------------------------------------------"
end
