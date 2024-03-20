# frozen_string_literal: true

require "json"
require "net/http"
require_relative "event"
require_relative "slack"

class EventSyndicator
  attr_accessor :dry_run, :formatted_events

  def initialize
    @dry_run = ENV["SYN_ENV"] != "production"
  end

  def fetch
    groups = JSON.parse(Net::HTTP.get(URI("https://events.api.tampa.dev/")))

    sorted_events = []
    formatted_events = []

    groups.each do |group|
      sorted_events << group[1] unless group[1]["eventSearch"]["count"] == 0
    end

    sorted_events.sort! { |a, b| DateTime.parse(a["eventSearch"]["edges"][0]["node"]["dateTime"]) <=> DateTime.parse(b["eventSearch"]["edges"][0]["node"]["dateTime"]) }

    sorted_events.each do |group|
      event = MeetupEvent.format_slack(group)
      formatted_events << event unless event.nil?
    end

    if formatted_events.empty?
      puts "No events to post, exiting with nothing to do."
      exit
    end

    Slack.syndicate(formatted_events, @dry_run)
  end
end

syn = EventSyndicator.new
syn.fetch
