# frozen_string_literal: true

require "json"
require "net/http"
require 'optparse'
require_relative "event"
require_relative "slack"

class EventSyndicator
  attr_accessor :dry_run, :formatted_events

  def initialize
    @dry_run = ENV["SYN_ENV"] != "production"
  end

  def fetch(announcement_type, destinations)

    events_url = case announcement_type
      when :weekly
        'https://events.api.tampa.dev?within_days=7'
      when :daily
        'https://events.api.tampa.dev?within_hours=24'
      when :hourly
        'https://events.api.tampa.dev?within_hours=1'
    end

    groups = JSON.parse(Net::HTTP.get(URI(events_url)))

    sorted_events = []
    formatted_events = []

    groups.each do |group|
      sorted_events << group[1] unless group[1]["unifiedEvents"]["count"] == 0 || group[1]["unifiedEvents"]["edges"].empty?
    end

    sorted_events.sort! do |a, b| 
      DateTime.parse(a["unifiedEvents"]["edges"][0]["node"]["dateTime"]) <=> DateTime.parse(b["unifiedEvents"]["edges"][0]["node"]["dateTime"])
    end

    sorted_events.each do |group|
      event = MeetupEvent.format_slack(group)
      formatted_events << event unless event.nil?
    end

    # fencepost
    formatted_events[0...-1].each do |element|
      element << { type: "divider" }
    end

    if formatted_events.empty?
      puts "No events to post, exiting with nothing to do."
      exit
    end

    Slack.syndicate(formatted_events, announcement_type, destinations, @dry_run)
  end
end

def main
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: main.rb [options]"

    # Boolean argument for --daily, --hourly, or --weekly
    announcement_types = [:daily, :hourly, :weekly]
    opts.on("--daily", "Set announcement type to daily") do
      options[:announcement_type] = :daily
    end
    opts.on("--hourly", "Set announcement type to hourly") do
      options[:announcement_type] = :hourly
    end
    opts.on("--weekly", "Set announcement type to weekly") do
      options[:announcement_type] = :weekly
    end

    # Argument for --destinations=<destinations>
    opts.on("--destinations=DESTINATIONS", "Comma-separated list of destinations") do |destinations|
      options[:destinations] = destinations.split(',')
    end
  end.parse!

  announcement_type = options[:announcement_type] || :weekly
  destinations = options[:destinations] || ['TD', 'TBT', 'TBUX']

  syn = EventSyndicator.new
  syn.fetch(announcement_type, destinations)
end

main
