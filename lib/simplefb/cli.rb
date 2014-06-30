module Simplefb
  module CLI
    def self.run
      require 'optparse'

      Simplefb.app_id=ENV['FB_APP_ID']
      Simplefb.app_secret=ENV['FB_APP_SECRET']

      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: simplefb [options]"
  
        opts.on('-d', '--debug', 'Debug the facebook token provided') do |d|
          options[:debug] = d
        end
  
        opts.on('-a', '--access_token ACCESS_TOKEN', 'The Access Token of the user') do |a|
          options[:access_token] = a
        end
  
      end.parse!

      options[:query] = ARGV.shift

      response=if options[:debug]
        Simplefb.debug_token(options[:access_token])
      else
        Simplefb.query_endpoint(options[:query], options[:access_token], Hash[*ARGV])
      end

      puts JSON.pretty_generate(response)
    end
    
  end
end