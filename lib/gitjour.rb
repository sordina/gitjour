require 'rubygems'
require 'dnssd'
require 'set'

Thread.abort_on_exception = true

module Gitjour
  VERSION = "6.4.0"
  GitService = Struct.new(:name, :host, :port, :description)

  class Application

    class << self
      def run(*args)
        case args.shift
        when "list"
          list
        when "pull"
          pull(*args)
        when "clone"
          clone(*args)
        when "serve"
          serve(*args)
        when "remote"
          remote(*args)
        when "web"
          web(*args)
        when "browse"
          browse(*args)
        else
          help
        end
      end

      private

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

      def list
        service_list.each do |service|
          puts "=== #{service.name} on #{service.host}:#{service.port} ==="
          puts "  gitjour (clone|pull) #{service.name}"
          if service.description != '' && service.description !~ /^Unnamed repository/
            puts "  #{service.description}"
          end
          puts
        end
      end

      def pull(repository_name, branch = "master")
        service = locate_repo(repository_name) or
          abort "ERROR: Unable to find project named '#{repository_name}'"

        puts "Connecting to #{service.host}:#{service.port}"

        system "git pull git://#{service.host}:#{service.port}/ #{branch}"
      end

      def clone(repository_name, *rest)
        dir = rest.shift || repository_name
        if File.exists?(dir)
          abort "ERROR: Clone directory '#{dir}' already exists."
        end

        puts "Cloning '#{repository_name}' into directory '#{dir}'..."

        service = locate_repo(repository_name) or
          abort "ERROR: Unable to find project named '#{repository_name}'"

        puts "Connecting to #{service.host}:#{service.port}"

        system "git clone git://#{service.host}:#{service.port}/ #{dir}"
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

        `git daemon --verbose --export-all --port=#{port} --base-path=#{path} --base-path-relaxed`
      end

      def web(path=Dir.pwd, *rest)
        path = File.expand_path(path)
        name = service_name(rest.shift || File.basename(path))
        port = rest.shift || 1234
        httpd = rest.shift || "webrick"

        system("git instaweb --httpd=#{httpd} --port=#{port}") or
          abort "Unable to launch git instaweb."

        announce_web(path, name, port.to_i)

        trap("INT") do
          puts "Stopping instaweb..."
          system "git instaweb stop"
          exit
        end

        Thread.stop
      end

      def help
        puts "Gitjour #{Gitjour::VERSION}"
        puts "Serve up and use git repositories via ZeroConf."
        puts "\nUsage: gitjour <command> [args]"
        puts
        puts "  list"
        puts "      Lists available repositories."
        puts
        puts "  clone <project> [<directory>]"
        puts "      Clone a gitjour-served repository."
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
        puts "  pull <project> [<branch>]"
        puts "      Pull from a gitjour-served repository."
        puts
        puts "  remote <project> [<name>]"
        puts "      Add a ZeroConf remote into your current repository."
        puts "      Optionally pass name to not use pwd."
        puts
        puts "  web <path_to_project> [<name_of_project>] [<port>] [<httpd_daemon>]"
        puts "      Serve up the current directory via git instaweb for browsers."
        puts "      The default port is 1234 and the httpd_daemon is defaulted to"
        puts "      webrick. Other options are 'lighttpd' and 'apache2' (See the"
        puts "      git-instaweb man page for more details)"
        puts
        puts "  browse [<port>] [<browser>]"
        puts "      Browse git repositories published with the 'web' command (see"
        puts "      above). This command takes two optional arguments: the first"
        puts "      is the port for the local web server (default 9850), the second"
        puts "      is the path to your web browser (see man git-web--browse for"
        puts "      details)."
        puts
      end

      class Done < RuntimeError; end

      def discover(timeout=5)
        waiting_thread = Thread.current

        dns = DNSSD.browse "_git._tcp" do |reply|
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

        discover do |obj|
          if obj.name == name
            found = obj
            raise Done
          end
        end

        return found
      end

      def service_list
        list = Set.new
        discover { |obj| list << obj }

        return list
      end

      def browse(*args)
        require "gitjour/browser"
        Browser.new(*args).start
      end

      def announce_repo(path, name, port, type)
        return unless File.exists?("#{path}/.git")

        tr = DNSSD::TextRecord.new
        tr['description'] = File.read("#{path}/.git/description") rescue "a git project"
        tr['gitjour'] = 'true' # distinguish instaweb from other HTTP servers

        DNSSD.register(name, type, 'local', port, tr.encode) do |rr|
          puts "Registered #{name} on port #{port}. Starting service."
        end
      end

      def announce_git(path, name, port)
        announce_repo(path, name, port, "_git._tcp")
      end

      def announce_web(path, name, port)
        announce_repo(path, name, port, "_http._tcp")
      end
    end
  end
end
