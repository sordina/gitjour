require "webrick"
require "erb"
require "set"
require "thread"

module Gitjour
  class Browser

    def initialize(*args)
      @port = args.shift || 9850
      @browser = args.shift
      @services = Set.new
      @mutex = Mutex.new
    end

    def start
      DNSSD.browse("_http._tcp,git") do |reply|
        begin
          DNSSD.resolve reply.name, reply.type, reply.domain do |resolve_reply|
            service = GitService.new(reply.name,
                                     resolve_reply.target,
                                     resolve_reply.port,
                                     resolve_reply.text_record['description'].to_s)

            @mutex.synchronize do
              if @services.member? service
                @services.delete service
              else
                @services << service
              end
            end
          end
        rescue ArgumentError # usually a jacked DNS text record
        end
      end

      http = WEBrick::HTTPServer.new(:Port => @port.to_i)
      http.mount_proc("/") { |req, res| index(req, res) }
      http.mount_proc("/style.css") { |req, res| stylesheet(req, res) }
      trap("INT") { http.shutdown }
      t = Thread.new { http.start }

      url = "http://localhost:#{@port}"
      if @browser
        `git web--browse -b '#{@browser}' http://localhost:9850`
      else
        `git web--browse -c "instaweb.browser" http://localhost:9850`
      end
      t.join
    end

    def index(req, res)
      res['Content-Type'] = 'text/html'
      res.body = index_html.result(binding)
    end

    def index_html
      @index_html ||= ERB.new(<<-HTML)
        <html>
          <body>
            <head>
              <link rel="stylesheet" href="/style.css" type="text/css" media="screen"/>
              <title>Browseable Git Repositories</title>
            </head>
            <h1>Browseable Git Repositories</h1>
            <ul>
            <% @mutex.synchronize do %>
              <% @services.map do |s| %>
                <li>
                  <a href='http://<%= s.host %>:<%= s.port %>' target="_new">
                    <%= s.name %>
                  </a>
                  <%= s.description unless s.description =~ /^Unnamed repository/ %>
                </li>
              <% end %>
            <% end %>
            </ul>
          </body>
        </html>
      HTML
    end

    def stylesheet(req, res)
      res['Content-Type'] = 'text/css'
      res.body = css
    end

    def css
      @css ||= <<-CSS
        body {
          font-family: sans-serif;
          font-size: 12px;
          background-color: #fff;
        }

        h1 {
          font-size: 20px;
          font-weight: bold;
        }

        ul {
          border: 1px dashed #999;
          padding: 10 10 10 20;
          background-color: #ccc;
        }
      CSS
    end
  end

end
