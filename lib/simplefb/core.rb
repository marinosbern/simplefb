module Simplefb
  require 'net/http'
  require 'json'
  
  class Error < StandardError; end
  
  class << self
    attr_accessor :app_id, :app_secret
    attr_writer :logger
  end
  
  def self.logger
    return @logger ||= BasicLogger.new
  end
  
  def self.app_access_token
    "#{@app_id}|#{@app_secret}"
  end
  
  def self.query_endpoint(endpoint, access_token, options={})
    logger.info "Querying endpoint: #{endpoint}"
    options[:access_token]=access_token
    perform_request("https://graph.facebook.com/#{endpoint}", options)
  end
  
  def self.debug_token(access_token)
    logger.info "Debugging token"
    raise Error, "No Access Token Given" unless access_token
    response=perform_request("https://graph.facebook.com/debug_token", :input_token=>access_token, :access_token=>app_access_token)
    
    # Check that this access token belongs to our app
    raise Error if response['data']['app_id'] != @app_id
    
    # Parse Unix times for easier reading
    # From Documentation: issued_at field is not returned for short-lived access tokens (https://developers.facebook.com/docs/facebook-login/access-tokens)
    %w(issued_at expires_at).each {|field| response['data'][field]=Time.at(response['data'][field]) if response['data'].has_key?(field)}
    response
  end
  
  def self.get_access_token(code, redirect_uri)
    raise Error, "No code given" unless code
    logger.info "*** Getting access token"
    
    access_token_response = perform_request("https://graph.facebook.com/oauth/access_token", :client_id=>@app_id, :redirect_uri=>redirect_uri, :client_secret=>@app_secret, :code=>code)
        
    cracked_access_token_response=access_token_response.body.scan(/(\w+)=(\w+)+/)
    cracked_access_token_response_hash=cracked_access_token_response.reduce({}) { |hash, curr| hash[curr[0]]=curr[1];hash } 
    access_token=cracked_access_token_response_hash['access_token']
    
    return access_token
  end
  
  def self.get_login_prompt_url(redirect_uri, permissions: [:public_profile, :email, :user_friends])
    raise Error, 'No app ID provided' unless @app_id
    url="https://www.facebook.com/dialog/oauth?client_id=#{@app_id}&scope=#{permissions.join(',')}&redirect_uri=#{redirect_uri}"
    return url
  end
  
  # The token is actually sent back to the client as part of the URL Fragment. Therefore, it is not visible by the server
  def self.get_token_login_prompt_url(redirect_uri, permissions: [:public_profile, :email, :user_friends])
    raise Error, 'No app ID provided' unless @app_id
    url="https://www.facebook.com/dialog/oauth?client_id=#{@app_id}&scope=#{permissions.join(',')}&response_type=token&redirect_uri=#{redirect_uri}"
    return url
  end
  
  # Facebook will redirect to the right scheme regardless, so no redirect_uri will be required
  def self.get_app_login_prompt_url(permissions: [:public_profile, :email, :user_friends])
    raise Error, 'No app ID provided' unless @app_id
    "fbauth://authorize?client_id=#{@app_id}&scope=#{permissions.join(',')}&response_type=code"
  end
  
  def self.get_mobile_web_login_prompt_url(permissions: [:public_profile, :email, :user_friends])
    raise Error, 'No app ID provided' unless @app_id
    "https://www.facebook.com/dialog/oauth?client_id=#{@app_id}&scope=#{permissions.join(',')}&response_type=token&redirect_uri=fb#{@app_id}://authorize"
  end
  
  private
  
  def self.debug_response(response)
    logger.debug "#{response.code}"
    logger.debug response.body
    response.each do |header, value|
      logger.debug "#{header}, #{value}"
    end
  end
  
  def self.perform_request(uristring, options={})
    response=nil
    
    if options.length>0
      query=options.map {|k,v| "#{k}=#{v}"}.join('&')
      uristring+="?#{query}"
    end
    
    uri=URI(URI.escape(uristring))
    logger.debug "URI: #{uri}"
    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      req = Net::HTTP::Get.new(uri)
      # req.add_field('Accept', 'application/json')
      response = http.request(req) # Net::HTTPResponse object
    end
    
    raise Error unless response
  
    debug_response(response)
  
    raise Error, "Failed status code #{response.code} #{response.body}" unless response.code =~ /2\d+/
  
    if response['Content-Type'] =~ /^application\/json/ # Facebook likes to return 'application/json; charset=UTF-8' if no 'Accept:' is given
      logger.info "Returning a hash"
      return JSON.parse(response.body)
    else
      return response
    end
    
  end
  
  
  
end