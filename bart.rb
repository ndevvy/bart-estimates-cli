#!/usr/bin/ruby
#
require 'httparty'
require 'colorize'
require 'terminal-table'

class BartEstimates
  DIRECTIONS = { n: :north, s: :south, e: :east, w: :west }.freeze
  ALT_COLORS = { orange: :light_red }.freeze

  attr_accessor :raw_estimates, :station, :estimates, :time, :station_name, :direction, :colors

  def initialize(station, direction = nil, colors = true)
    @station = station.upcase
    direction = DIRECTIONS[direction[0].downcase.to_sym] if direction
    @direction = direction
    @colors = colors
    @estimates = {}
    self
  end

  def run
    fetch_estimates
    store_estimates
    self
  end

  def self.formatted_estimate(est, colors)
    minutes_str = (est['minutes']).to_s
    destination_str = (est['destination']).to_s
    if colors
      color = est['color'].downcase.to_sym
      color = ALT_COLORS[color] || color
      destination_str = destination_str.send(color)
    end
    [minutes_str, destination_str].join(' ')
  end

  def tabify_results
    columns = []
    estimates.each do |_dir, ests|
      columns << ests.map { |e| self.class.formatted_estimate(e, colors) }
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
    table.title =  "Arrival estimates for #{station_name} @ #{time}"
    table.headings = estimates.keys.map do |k|
      direction = "#{k}bound".upcase
      direction = direction.colorize(:light_blue) if colors
      direction
    end
    table.rows = tabs
    puts table
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

  def text_results
    puts "BART arrival estimates for #{station_name}".magenta
    puts time.to_s.magenta
    puts
    estimates.each do |direction, ests|
      puts "#{direction.capitalize}bound trains".magenta
      ests.each do |est|
        puts "#{est['minutes']} minutes #{est['destination'].send(est['color'].downcase)}"
      end
      puts
    end
  end

  def self.parse_estimate_hash(estimate_hash)
    destination = estimate_hash['destination']
    estimate_hash['estimate'].map do |estimate|
      est = { 'destination' => destination }.merge(estimate)
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
    p @estimates
    @estimates = @estimates.group_by { |e| e['direction'] }
    @estimates.each { |_, ests| ests.sort_by! { |e| e['minutes'] } }
  end

  def fetch_estimates
    resp = HTTParty.get(url)
    @raw_estimates = resp.to_h
  end

  def url
    url = "http://api.bart.gov/api/etd.aspx?cmd=etd&orig=#{station}&key=MW9S-E7SL-26DU-VV8V"
    # n and s are the only valid values for the dir param
    url += "&dir=#{direction[0]}" if direction && %w(s n).include?(direction[0])
    url
  end
end

if ARGV.length > 0
  station = ARGV[0]
  direction = ARGV[1]
  colors = !ARGV.include?('--no-color')
  p station, direction, colors
  est = BartEstimates.new(station, direction, colors).run
  est.text_results_alt
end
