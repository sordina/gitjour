require 'rubygems'
require 'dnssd'
require 'set'
require 'webrick'
require 'gitjour/version'

Thread.abort_on_exception = true

module Gitjour
  GitService = Struct.new(:name, :host, :port, :description)  

  class Application

    class << self
      def run(*args)
        case args.shift
          when "list"
            list
          when "clone"
            clone(*args)
          when "serve"
            serve(*args)
          when "remote"
            remote(*args);
          when "web"
            web(*args)
          when "browse"
            browse(*args)
          else
            help
        end
      end

      private
			def list
				service_list("_git._tcp").each do |service|
          puts "=== #{service.name} on #{service.host}:#{service.port} ==="
          puts "  gitjour clone #{service.name}"
          if service.description != '' && service.description !~ /^Unnamed repository/
            puts "  #{service.description}"
          end
          puts
        end
			end

      def clone(repository_name, *rest)
        dir = rest.shift || repository_name
        if File.exists?(dir)
          exit_with! "ERROR: Clone directory '#{dir}' already exists."
        end

        puts "Cloning '#{repository_name}' into directory '#{dir}'..."

        unless service = locate_repo(repository_name)
          exit_with! "ERROR: Unable to find project named '#{repository_name}'"
        end

        puts "Connecting to #{service.host}:#{service.port}"

        system "git clone git://#{service.host}:#{service.port}/ #{dir}/"
      end

      def remote(repository_name, *rest)
        dir = rest.shift || repository_name
        service = locate_repo repository_name
        system "git remote add #{dir} git://#{service.host}:#{service.port}/"
      end

      def serve(path=Dir.pwd, *rest)
        path = File.expand_path(path)
        name = service_name(rest.shift || File.basename(path))
        port = rest.shift || 9418

        if File.exists?("#{path}/.git")
          announce_git(path, name, port.to_i)
        else
          Dir["#{path}/*"].each do |dir|
            if File.directory?(dir)
              name = File.basename(dir)
              announce_git(dir, name, 9418)
            end
          end
        end

        `git-daemon --verbose --export-all --port=#{port} --base-path=#{path} --base-path-relaxed`
      end

      def web(path=Dir.pwd, *rest)
        path = File.expand_path(path)
        name = service_name(rest.shift || File.basename(path)) + '.git'
        port = rest.shift || 1234
        httpd = rest.shift || "webrick"

        if File.exists?("#{path}/.git")
          announce_web(path, name, port.to_i)
          `git-instaweb --httpd=#{httpd} --port=#{port} --browser=/dev/null`
          trap("INT") do 
            puts "Stopping instaweb..."
            `git-instaweb stop`
            exit 0
          end
          while true; sleep 30; end
        else
          $stderr.puts "You must specify a proper git project"
          exit 1
        end
      end

      def service_name(name)
        # If the name starts with ^, then don't apply the prefix
        if name[0] == ?^
          name = name[1..-1]
        else
          prefix = `git config --get gitjour.prefix`.chomp
          prefix = ENV["USER"] if prefix.empty?
          name   = [prefix, name].compact.join("-")
        end
        name
      end

      def help
        puts "Gitjour #{Gitjour::VERSION::STRING}"
        puts "Serve up and use git repositories via Bonjour/DNSSD."
        puts "\nUsage: gitjour <command> [args]"
        puts
        puts "  list"
        puts "      Lists available repositories."
        puts
        puts "  clone <project> [<directory>]"
        puts "      Clone a gitjour served repository."
        puts
        puts "  serve <path_to_project> [<name_of_project>] [<port>] or"
        puts "        <path_to_projects>"
        puts "      Serve up the current directory or projects via gitjour."
        puts
        puts "      The name of your project is automatically prefixed with"
        puts "      `git config --get gitjour.prefix` or your username (preference"
        puts "      in that order). If you don't want a prefix, put a ^ on the front"
        puts "      of the name_of_project (the ^ is removed before announcing)."
        puts
        puts "  web <path_to_project> [<name_of_project>] [<port>] [<httpd_daemon>]"
        puts "      Serve up the current directory via git instaweb for browsers."
        puts "      The default port is 1234 and the httpd_daemon is defaulted to"
        puts "      webrick. Other options are 'lighttpd' and 'apache2' (See the"
        puts "      git-instaweb man page for more details)"
        puts
        puts "  remote <project> [<name>]"
        puts "      Add a Bonjour remote into your current repository."
        puts "      Optionally pass name to not use pwd."
        puts
      end

      def exit_with!(message)
        STDERR.puts message
        exit!
      end

      class Done < RuntimeError; end

      def discover(type, timeout=5)
        waiting_thread = Thread.current

        dns = DNSSD.browse type do |reply|
          DNSSD.resolve reply.name, reply.type, reply.domain do |resolve_reply|
            service = GitService.new(reply.name,
                                     resolve_reply.target,
                                     resolve_reply.port,
                                     resolve_reply.text_record['description'].to_s)
            begin
              yield service
            rescue Done
              waiting_thread.run
            end
          end
        end

        puts "Gathering for up to #{timeout} seconds..."
        sleep timeout
        dns.stop
      end

      def locate_repo(name)
        found = nil

        discover("_git._tcp") do |obj|
          if obj.name == name
            found = obj
            raise Done
          end
        end

        return found
      end

      def service_list(type)
        list = Set.new
        discover(type) { |obj| list << obj }

        return list
      end

      def browse(*args)
        http = WEBrick::HTTPServer.new(:Port => 9850)
        http.mount_proc("/") do |req, res|
          res['Content-Type'] = 'text/html'
          res.body = <<-HTML
<html>
  <body>
    <h1>Browseable Git Repositories</h1>
    <ul>
      #{http_services.map do |s|
        "<li><a href='http://#{s.host}:#{s.port}'>#{s.name}</a></li>"
      end}
    </ul>
  </body>
</html>
HTML
        end
        trap("INT") { http.shutdown }
        http.start
      end

      def http_services
        service_list("_http._tcp").select { |s| s.name =~ /.git$/ }
      end

      def announce_git(path, name, port)
        announce_repo(path, name, port, "_git._tcp")
      end

      def announce_web(path, name, port)
        announce_repo(path, name, port, "_http._tcp")
      end

      def announce_repo(path, name, port, type)
        return unless File.exists?("#{path}/.git")

        tr = DNSSD::TextRecord.new
        tr['description'] = File.read("#{path}/.git/description") rescue "a git project"

        DNSSD.register(name, type, 'local', port, tr.encode) do |rr|
          puts "Registered #{name} on port #{port}. Starting service."
        end
      end

    end
  end
end



