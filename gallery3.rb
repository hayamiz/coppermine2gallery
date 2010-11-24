
require 'net/http'
require 'uri'
require 'json'

class Gallery3
  def initialize(entry_point, api_key)
    @entry_point = URI.parse(entry_point)
    @api_key = api_key
  end

  def get(rest_path)
    uri = @entry_point + rest_path
    path = uri.path
    req = Net::HTTP::Get.new(path)
    req["X-Gallery-Request-Method"] = "get"
    add_key_to_request_header(req)

    Net::HTTP.start(uri.host, uri.port) do |http|
      res = http.request(req)
      JSON.parse(res.body)
    end
  end

  def post(rest_path, params)
  end

  def put(rest_path, params)
  end

  private
  def add_key_to_request_header(req)
    req["X-Gallery-Request-Key"] = @api_key
  end
end

