require 'json'
module RouteUtils
  def self.show_routes
    JSON.parse(File.read('./routes.json'))
  end

  # Populate the routes.json file; should not need to be run very frequently...
  def self.fetch_all_routes
    resp = HTTParty.get("http://api.bart.gov/api/route.aspx?cmd=routes&key=MW9S-E7SL-26DU-VV8V")
    routes = resp.to_h["root"]["routes"]["route"]
    full_route_datas = {}
    routes.each do |route|
      raw_data = fetch_route_info(route["number"])
      parsed = parsed_route_data(raw_data)
      color = parsed["routes"]["route"]["color"]
      full_route_datas[color] ||= []
      full_route_datas[color] << parsed
      sleep(0.2)
    end
    f = File.open('routes.json', 'w+')
    f.puts(full_route_datas.to_json)
    f.close
    show_routes
  end

  def self.parsed_route_data(raw_data)
    raw_data = raw_data["root"]
    stations =
      raw_data["routes"]["route"]["config"]["station"]
      .each_with_index
      .map { |station, idx| [station, idx] }
      .to_h
    raw_data["stations"] = stations
    raw_data["destination"]
    raw_data
  end

  def self.fetch_route_info(route_num)
    resp = HTTParty.get("http://api.bart.gov/api/route.aspx?cmd=routeinfo&route=#{route_num}&key=MW9S-E7SL-26DU-VV8V")
    resp.to_h
  end
end
