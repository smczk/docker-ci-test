require 'docker'
require 'serverspec'
require 'cloudstack_ruby_client'

RSpec.configure do |c|

  END_POINT = ENV['END_POINT']
  API_KEY = ENV['API_KEY']
  SECRET_KEY = ENV['SECRET_KEY']
  vmid = nil
  client = CloudstackRubyClient::Client.new(END_POINT, API_KEY, SECRET_KEY, true)

  c.before :suite do

    ZONE_NAME = 'pascal'
    OFFERING_NAME = 'light.S1'
    TEMPLATE_NAME = 'CoreOS (stable) 494.4.0 64-bit'
    USER_DATA = 'I2Nsb3VkLWNvbmZpZwpjb3Jlb3M6CiAgdW5pdHM6CiAgICAtIG5hbWU6IGRvY2tlci10Y3Auc29ja2V0CiAgICAgIGNvbW1hbmQ6IHN0YXJ0CiAgICAgIGVuYWJsZTogeWVzCiAgICAgIGNvbnRlbnQ6IHwKICAgICAgICBbVW5pdF0KICAgICAgICBEZXNjcmlwdGlvbj1Eb2NrZXIgU29ja2V0IGZvciB0aGUgQVBJCgogICAgICAgIFtTb2NrZXRdCiAgICAgICAgTGlzdGVuU3RyZWFtPTIzNzUKICAgICAgICBCaW5kSVB2Nk9ubHk9Ym90aAogICAgICAgIFNlcnZpY2U9ZG9ja2VyLnNlcnZpY2UKCiAgICAgICAgW0luc3RhbGxdCiAgICAgICAgV2FudGVkQnk9c29ja2V0cy50YXJnZXQKICAgIC0gbmFtZTogZW5hYmxlLWRvY2tlci10Y3Auc2VydmljZQogICAgICBjb21tYW5kOiBzdGFydAogICAgICBjb250ZW50OiB8CiAgICAgICAgW1VuaXRdCiAgICAgICAgRGVzY3JpcHRpb249RW5hYmxlIHRoZSBEb2NrZXIgU29ja2V0IGZvciB0aGUgQVBJCgogICAgICAgIFtTZXJ2aWNlXQogICAgICAgIFR5cGU9b25lc2hvdAogICAgICAgIEV4ZWNTdGFydD0vdXNyL2Jpbi9zeXN0ZW1jdGwgZW5hYmxlIGRvY2tlci10Y3Auc29ja2V0Cg=='

    zone = client.list_zones({
      name: ZONE_NAME
    })["zone"][0]

    service_offering = client.list_service_offerings({
      name: OFFERING_NAME
    })["serviceoffering"][0]

    template = client.list_templates({
      templatefilter: "executable",
      zoneid: zone["id"],
      name: TEMPLATE_NAME
    })["template"][0]

    response = client.deploy_virtual_machine({
      :serviceofferingid => service_offering["id"],
      :templateid => template["id"],
      :zoneid => zone["id"],
    })

    vmid = response["id"]

    loop{
      sleep 5
      virtualmachine = client.list_virtual_machines({ :id => vmid })["virtualmachine"][0]
      break if virtualmachine["state"] == "Running"
    }

    client.update_virtual_machine({ :id => vmid, :userdata => USER_DATA })
    client.reboot_virtual_machine({ :id => vmid })

    ip = client.list_virtual_machines({ :id => vmid })["virtualmachine"][0]["nic"][0]["ipaddress"]
    Docker.url = "tcp://#{ip}:2375"
    dockerfile = File.open('Dockerfile').read

    begin
      image = Docker::Image.build(dockerfile)
    rescue
      sleep 5
      retry
    end

    Specinfra.configuration.set :backend, :docker
    Specinfra.configuration.set :docker_url, "tcp://#{ip}:2375"
    Specinfra.configuration.set :docker_image, image.id
  end

  c.after :suite do
    client.destroy_virtual_machine({ :id => vmid })
  end
end
