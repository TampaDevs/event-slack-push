# frozen_string_literal: true

require "uri"
require "net/https"
require "json"

class Slack
  attr_accessor :keys, :message, :post_types, :utm_params

  def initialize
    @utm_params = {
      source: "td_slack",
      medium: "organic",
      campaign: "tampadevs_meetup_promo"
    }

    @message = []
  end

  def self.syndicate(events, announcement_type, destinations, dry_run)
    return if events.empty?

    @payload = payload(events, announcement_type)

    if dry_run
      puts message_json
    else
      post destinations
    end
  end

  def self.payload(events, announcement_type)
    header_text = case announcement_type
      when :weekly
        ":balloon: Happening This Week"
      when :daily
        ":earth_americas: Happening Today"
      when :hourly
        ":loudspeaker: Happening Soon"
    end
    header = [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: header_text,
        }
      },
      {
        type: "divider"
      }
    ]

    footer = [
      { type: "divider" },
      {
        type: "actions",
        elements: [
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":earth_americas: All Meetups",
              emoji: true
            },
            value: "see_all_meetups",
            url: "https://tampa.dev?utm_source=td_slack_syndication&utm_campaign=organic"
          },
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":calendar: Event Calendar",
              emoji: true
            },
            value: "newsletter_tampa_dev",
            url: "https://go.tampa.dev/calendar?utm_source=td_slack_syndication&utm_campaign=organic"
          },
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":zap: Events API",
              emoji: true
            },
            value: "events_api",
            url: "https://github.com/TampaDevs/events.api.tampa.dev"
          },
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":briefcase: Local Tech Jobs",
              emoji: true
            },
            value: "events_api",
            url: "https://talent.tampa.dev?utm_source=td_slack_syndication&utm_campaign=organic"
          },
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":newspaper: Newsletter",
              emoji: true
            },
            value: "newsletter_tampa_dev",
            url: "https://newsletter.tampa.dev?utm_source=td_slack_syndication&utm_campaign=organic"
          }
        ]
      }
    ]

    elements = [header, events.reduce([], :concat)]
    if @announcement_type == 'weekly'
      elements << footer
    end
    
    elements.reduce([], :concat)
  end

  def self.message_json
    {
      blocks: @payload
    }.to_json
  end

  def self.post(destinations)
    return if @payload.length == 0

    targets = destinations.map do |channel|
      ENV["#{channel}_SLACK_WEBHOOK"]
    end

    targets.each do |t|
      uri = URI.parse(t)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Accept"] = "application/json"
      request.content_type = "application/json"
      request.body = {
        blocks: @payload
      }.to_json

      response = https.request(request)
      puts "#{response.code} #{response.message}: #{response.body}"
    end
  end
end
