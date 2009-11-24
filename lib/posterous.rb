require 'rubygems'
require 'httparty'

module Posterous

  VERSION = '0.1.7'

  class AuthError < StandardError; end
  class TagError  < StandardError; end
  class SiteError < StandardError; end
  
  
  DOMAIN      = 'posterous.com'
  POST_PATH   = '/api/newpost'
  AUTH_PATH   = '/api/getsites'
  READ_PATH   = '/api/readposts'
    
  #   TODO: Include media with your post
  #   TODO: Post only a media file and get a url for it back
  
  # Posterous reader 
  # http://posterous.com/api/reading  
  class Reader
    
    include  HTTParty
    base_uri DOMAIN
    
    attr_reader :response
    
    ### Non-authenticated initialization
    def initialize hostname = "", site_id = nil, num_posts = nil, page = nil, tag = nil
      raise AuthError, 'Either Site Id or Hostname must be supplied if not using authentication.' if \
        (hostname == "" && !site_id.is_a?(Integer)) || (!hostname.is_a?(String) && site_id == nil) 
      @site_id = site_id ? site_id.to_s : site_id
      @hostname = hostname
      @num_posts = num_posts ? num_posts.to_s : num_posts
      @page = page ? page.to_s : page
      @tag = tag ? tag.to_s : tag
      @response = read_posts
      self
    end
    
    def read_posts
      self.class.get(READ_PATH, :query => build_query)["rsp"]["post"]
    end
    
    def build_query
      query   = { :site_id    => @site_id,
                  :hostname   => @hostname,
                  :num_posts  => @num_posts,
                  :page       => @page,
                  :tag        => @tag }
      query.delete_if { |k,v| !v }
      query
    end
  end
  
  
  class Client
    
    include  HTTParty
    base_uri DOMAIN

    attr_accessor :title, :body, :source, :source_url, :date
    attr_reader   :private_post, :autopost, :site_id, :tags

    ### Authenticated initialization
    def initialize user, pass, site_id = nil, hostname = ""
      raise AuthError, 'Either Username or Password is blank and/or not a string.' if \
        !user.is_a?(String) || !pass.is_a?(String) || user == "" || pass == ""
      self.class.basic_auth user, pass
      @site_id = site_id ? site_id.to_s : site_id
      @source = @body = @title = @source_url = @date = @media = @tags = @autopost = @private_post = nil
    end
    
    def site_id= id
      @site_id = id.to_s
    end

    def tags= ary
      raise TagError, 'Tags must added using an array' if !ary.is_a?(Array)
      @tags = ary.join(", ")
    end

    def valid_user?
      res = account_info
      return false unless res.is_a?(Hash)
      res["stat"] == "ok"
    end

    def has_site?
      res = account_info
      return false unless res.is_a?(Hash)
      
      case res["site"]
      when Hash
        return true unless @site_id
        return @site_id == res["site"]["id"]
      when Array
        res["site"].each do |site|
          return true if @site_id && @site_id == site["id"]
        end      
      end
      false
    end

    def primary_site
      res = account_info
      raise SiteError, "Couldn't find a primary site. Check login and password is valid." \
        unless res.is_a?(Hash) && res["stat"] == "ok" && res["site"]
      [res["site"]].flatten.each do |site|
        return site["id"] if site["primary"] == "true"
      end
      nil
    end

    def set_to on
      @private_post = 1 if on == :private
      @autopost     = 1 if on == :autopost
    end

    def build_query
      options = { :site_id    => @site_id,
                  :autopost   => @autopost,
                  :private    => @private_post,
                  :date       => @date,
                  :tags       => @tags }

      query   = { :title      => @title,
                  :body       => @body,
                  :source     => @source,
                  :sourceLink => @source_url }

      options.delete_if { |k,v| !v }
      query.merge!(options)
    end

    def account_info
      self.class.post(AUTH_PATH, :query => {})["rsp"]
    end
    
    def add_post
      self.class.post(POST_PATH, :query => build_query)
    end  
  end
end