
require 'net/http'
require 'uri'
require 'json'
require 'mime/types'
require 'kconv'

module Gallery3
  class Item
    attr_reader :url
    attr_reader :type

    def initialize
      @url = nil
      @type = nil
    end

    class << self
      def from_json(json_entity)
        raise NotImplementedError.new
      end

      def set_entry_point(url)
        
      end
    end

    private :initialize
  end

  class Photo < Item
    def initialize(params)
      super
      @type = :photo

      unless params[:file]
        raise ArgumentError.new(":file is required for Photo")
      end
      params[:file] = File.open(params[:file]) if params[:file].is_a? String
    end
  end

  class Album < Item
    def initialize(params)
      raise NotImplementedError.new
    end
  end

  class Client
    def initialize(entry_point, api_key)
      @entry_point = URI.parse(entry_point)
      @api_key = api_key
    end

    def get(rest_path)
      uri = @entry_point + rest_path
      path = uri.path
      if uri.query
        path += "?#{uri.query}"
      end
      req = Net::HTTP::Get.new(path)
      req["X-Gallery-Request-Method"] = "get"
      req["X-Gallery-Request-Key"] = @api_key

      Net::HTTP.start(uri.host, uri.port) do |http|
        res = http.request(req)
        JSON.parse(res.body)
      end
    end

    def delete(rest_path)
      uri = @entry_point + rest_path
      path = uri.path
      req = Net::HTTP::Delete.new(path)
      req["X-Gallery-Request-Method"] = "delete"
      req["X-Gallery-Request-Key"] = @api_key

      Net::HTTP.start(uri.host, uri.port) do |http|
        res = http.request(req)
        res.body
      end
    end

    def post(rest_path, params)
      uri = @entry_point + rest_path
      path = uri.path
      req = Net::HTTP::Post.new(path)
      req["X-Gallery-Request-Method"] = "post"
      req["X-Gallery-Request-Key"] = @api_key

      if params.values.any?{|val| val.is_a? File}
        parts = params.map do |key, val|
          if val.is_a? File
            val.binmode
            mime_type = MIME::Types.of(val.path).first || MIME::Type.new("text/plain")
            ["Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{File.basename(val.path)}\"",
             "Content-Transfer-Encoding: binary",
             "Content-Type: #{mime_type.to_s}",
             "",
             val.read()].join("\r\n")
          else
            ["Content-Disposition: form-data; name=\"#{key}\"",
             "Content-Type: text/json; charset=UTF-8",
             "Content-Transfer-Encoding: 8bit",
             "",
             val.to_json()].join("\r\n")
          end
        end

        boundary = ("-" * 10) + Array.new(10).map{|_| ("a".."z").to_a[rand(26)]}.join('')
        while parts.any?{|part| part.include?(boundary)}
          boundary = ("-" * 10) + Array.new(10).map{|_| ("a".."z").to_a[rand(26)]}.join('')
        end

        req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        req.body = "--" + boundary + "\r\n" + parts.join("\r\n--" + boundary + "\r\n") + "\r\n--" + boundary + "--\r\n\r\n"
      else
        req["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = params.map{|key,val|
          URI.encode_www_form(key => val.to_json)
        }.join('&')
      end

      Net::HTTP.start(uri.host, uri.port) do |http|
        res = http.request(req)
        JSON.parse(res.body)
      end
    end

#     def put(rest_path, params)
#       uri = @entry_point + rest_path
#       path = uri.path
#       req = Net::HTTP::Post.new(path)
#       req["X-Gallery-Request-Method"] = "put"
#       req["X-Gallery-Request-Key"] = @api_key
#       req["Content-Type"] = "application/x-www-form-urlencoded"
# 
#       req.body = params.map{|key,val|
#         URI.encode_www_form(key => val.to_json)
#       }.join('&')
# 
#       puts req.body
# 
#       Net::HTTP.start(uri.host, uri.port) do |http|
#         res = http.request(req)
#         puts res.body
#         JSON.parse(res.body)
#       end
#     end
  end
end
