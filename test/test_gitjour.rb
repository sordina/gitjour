require 'net/telnet'
require File.dirname(__FILE__) + '/test_helper.rb'

class TestGitjour < Test::Unit::TestCase
  def test_thread_friendly
    repo = File.dirname(__FILE__) + '/repo'
    port = 3289
    FileUtils.rm_rf repo
    `mkdir -p #{repo}; cd #{repo}; git init`
    
    thread = Thread.new do
      Gitjour::Application.send(:serve, repo, 'test', port)
    end

    sleep 1
    Net::Telnet::new("Host" => "localhost", "Port" => port)

    thread.kill
    assert_raises(Errno::ECONNREFUSED) do
      Net::Telnet::new("Host" => "localhost", "Port" => port)
    end
  end
end
