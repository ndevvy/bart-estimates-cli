#!/usr/bin/ruby
require 'httparty'
require 'colorize'
require 'terminal-table'
require 'json'


class BartEstimates
  DIRECTIONS = { n: :north, s: :south, e: :east, w: :west }.freeze
  ALT_COLORS = { orange: :light_red }.freeze

  attr_accessor :raw_estimates, :station, :estimates, :time, :station_name, :direction

  def initialize(station, direction = nil, colors = true, notify=false, destination=nil)
    @station = station.upcase
    String.disable_colorization = true unless colors
    direction = DIRECTIONS[direction[0].downcase.to_sym] if direction
    @direction, @notify, @destination = direction, notify, destination
    @estimates = {}
    self
  end

  def train_goes_to_destination?(train)
  end

  def run
    fetch_estimates
    store_estimates
    fetch_advisories
    self
  end

  def self.formatted_estimate(est)
    minutes_str = "#{est['minutes']} minutes".light_white
    destination_str = (est['destination']).to_s
    color = est['color']&.downcase&.to_sym
    color = ALT_COLORS[color] || color
    destination_str = destination_str.send(color) if color
    [minutes_str, destination_str].join(' ')
  end

  def tabify_results
    columns = []
    estimates.each do |_dir, ests|
      columns << ests.map { |e| self.class.formatted_estimate(e) }
    end
    columns = columns.reduce(&:zip)
    columns.map do |col|
      if col.is_a?(Array)
        col.flatten
      else
        [col]
      end
    end
  end

  def text_results_alt
    tabs = tabify_results
    table = Terminal::Table.new
    table.title =  "Arrival estimates for #{station_name}\n#{time.send(:black).on_light_blue}"
    table.headings = estimates.keys.map do |k|
      "#{k}bound".upcase.colorize(:light_white)
    end
    table.rows = tabs
    puts table
    if @parsed_advisories.length > 1
      @parsed_advisories.each { |p| puts p}
    end
  end

  def text_results
    puts "BART arrival estimates for #{station_name}".magenta
    puts time.to_s.magenta
    puts
    estimates.each do |direction, ests|
      puts "#{direction.capitalize}bound trains".magenta
      ests.each do |est|
        puts self.class.formatted_estimate(est)
      end
      puts
    end
  end

  def self.parse_estimate_hash(estimate_hash)
    destination = estimate_hash['destination']
    estimate_hash['estimate'].map do |estimate|
      est = { 'destination' => destination }
      if estimate.is_a?(Hash)
        est = est.merge(estimate)
      else
        est = est.merge([estimate].to_h)
      end
      est['minutes'] = est['minutes'].to_i
      est['length'] = est['length'].to_i
      est
    end
  end

  def store_estimates
    @time = raw_estimates['root']['time']
    @station_name = raw_estimates['root']['station']['name']
    if raw_estimates['root']['station']['etd'].is_a?(Hash)
      @estimates = BartEstimates.parse_estimate_hash(raw_estimates['root']['station']['etd'])
    else
      @estimates = raw_estimates['root']['station']['etd'].map do |_estimates|
        BartEstimates.parse_estimate_hash(_estimates)
      end.flatten
    end
    @estimates = @estimates.group_by { |e| e['direction'] }
    @estimates.each { |_, ests| ests.sort_by! { |e| e['minutes'] } }
  end

  def parsed_advisories
    advisories = @raw_advisories['root']['bsa']
    message = @raw_advisories['root']['bsa']['message']
    if advisories.is_a?(Array)
      advisories.map { |a| BartEstimates.parsed_advisory(a) }.concat(['', message])
    else
      [[BartEstimates.parsed_advisory(advisories)], ['', message]]
    end
  end

  ADVISORY_TYPES = { delay: :light_yellow, emergency: :light_red }.freeze

  def self.parsed_advisory(advisory)
    return advisory['description'].light_green unless advisory['station']
    color = ADVISORY_TYPES[advisory['type'].downcase.to_sym]
    [advisory['posted'], advisory["description"].send(color)]
    # "#{advisory['posted']} #{advisory['description'].send(color)}"
  end

  def fetch_estimates
    resp = HTTParty.get(url)
    @raw_estimates = resp.to_h
  end

  def fetch_advisories
    last_adv = @raw_advisories
    resp = HTTParty.get(BartEstimates.bsa_url)
    @raw_advisories = resp.to_h
    if last_adv != @raw_advisories
      last_parsed = @parsed_advisories
      @parsed_advisories = parsed_advisories
      if @notify
        new_advisories = @parsed_advisories - last_parsed
        `osascript -e 'display notification "BART advisory update: #{new_advisories.join(" ")}" with title 'BART delay'`
        notify_advisories if @notify
      end
    end
  end

  def notify_advisories(advisories)
    `osascript -e 'display notification "Lorem ipsum dolor sit amet" with title "BART delay"'`
  end

  def self.bsa_url
    'http://api.bart.gov/api/bsa.aspx?cmd=bsa&key=MW9S-E7SL-26DU-VV8V&date=today'
  end

  def self.list_stations
    stations = JSON.parse(File.read('./stations.json')).to_a
    tabs = []
    until stations.length < 3
      tabs << stations.pop(3)
    end

    until stations.length == 3
      stations << nil
    end

    tabs << stations
  end

  def url
    url = "http://api.bart.gov/api/etd.aspx?cmd=etd&orig=#{station}&key=MW9S-E7SL-26DU-VV8V"
    # n and s are the only valid values for the dir param
    url += "&dir=#{direction[0]}" if direction && %w(s n).include?(direction[0])
    url
  end
end

class EstimatePoller
  def initialize(estimator, refresh_rate=30)
    @estimator, @refresh_rate = estimator, refresh_rate
  end

  def run
    loop do
      count = @refresh_rate
      @estimator.run
      while count > 0
        system('clear')
        @estimator.text_results_alt
        if count <= 10
          puts  "Refreshing in #{count}"
        end
        count -= 1
        sleep(1)
      end
    end
  end
end

if ARGV.length > 0
  if ARGV.include?("list")
    BartEstimates.list_stations
  end
  station = ARGV[0]
  direction = ARGV[1]
  destination = ARGV[2]
  colors = !ARGV.include?('--no-color')
  polling = ARGV.include?('--polling')
  notify = ARGV.include?('--notify')
  if notify && !polling
    puts "--notify only works with polling".red
    sleep(1)
  end
  est = BartEstimates.new(station, direction, colors, destination).run
  if polling
    EstimatePoller.new(est).run
  else
    est.text_results_alt
  end
end
