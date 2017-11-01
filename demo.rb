$:.unshift File.expand_path("../lib", __FILE__)

require "cookbook-omnifetch"
require "chef/server_api"
require "fileutils"

p CookbookOmnifetch::VERSION

Dep = Struct.new(:name)

chef_server_url = "https://api.chef.io/organizations/chef-oss-dev"

cb_name = "runit"
cb_identifier = "09d43fad354b3efcc5b5836fef5137131f60f974"

FileUtils.rm_rf("runit-09d43fad354b3efcc5b5836fef5137131f60f974")

dep = Dep.new(cb_name)

class ServerApiMulti

  def initialize(url, opts={})
    @url = url
    @opts = opts
  end

  def get(*args)
    client_for_thread.get(*args)
  end

  def streaming_request(*args)
    client_for_thread.streaming_request(*args)
  end

  def client_for_thread
    Thread.current[:server_api] ||= Chef::ServerAPI.new(@url, @opts)
  end

end

http_client = ServerApiMulti.new(chef_server_url,
                                 client_name: 'kallistec',
                                 signing_key_filename: '/Users/ddeleo/opscode-ops/chef-oss-dev/.chef/kallistec.pem',
                                 keepalives: true)

fetcher = CookbookOmnifetch.init(dep, chef_server_artifact: chef_server_url, identifier: cb_identifier, http_client: http_client)

#p fetcher

CookbookOmnifetch.configure do |c|
  c.cache_path = Pathname.new(Dir.pwd)
  c.storage_path = Pathname.new(Dir.pwd)
end

fetcher.install

