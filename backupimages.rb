require 'aws-sdk-ec2'  # v2: require 'aws-sdk'

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

ec2 = Aws::EC2::Resource.new(region: 'sa-east-1')

filtros = [
  {name: 'instance-state-name', values: ['running'] },
  {name: 'tag:Backup', values: ['True']}
]
puts '--------------------------'
ec2.instances({filters: filtros}).each do |i|
  puts 'Nome   ' + getName(i)
  puts 'ID:    ' + i.id
  puts 'State: ' + i.state.name
  puts '--------------------------'

  makeImage(i)
end
