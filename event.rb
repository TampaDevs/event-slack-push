# frozen_string_literal: true

require "date"

class MeetupEvent
  # Can be used like so:
  # \n:clock1: #{parse_duration(group['unifiedEvents']['edges'][0]['node']['duration'])
  def self.parse_duration(iso8601_duration)
    match = iso8601_duration.match(/PT((?<hours>\d+(?:\.\d+)?)H)?((?<minutes>\d+(?:\.\d+)?)M)?((?<seconds>\d+(?:\.\d+)?)S)?/)

    hours = match[:hours]&.to_i || 0
    minutes = match[:minutes]&.to_i || 0
    seconds = match[:seconds]&.to_i || 0

    parts = []
    parts << "#{hours} hour#{"s" unless hours == 1}" if hours > 0
    parts << "#{minutes} minute#{"s" unless minutes == 1}" if minutes > 0
    parts << "#{seconds} second#{"s" unless seconds == 1}" if seconds > 0

    parts.join(", ") + " long"
  end

  def self.format_slack(group)
    return if group["unifiedEvents"]["count"] == 0

    event_blocks = [{
      type: "section",
      text: {
        type: "mrkdwn",
        text: "*#{group["name"]}* - *#{group["unifiedEvents"]["edges"][0]["node"]["title"]}*\n:calendar: #{DateTime.parse(group["unifiedEvents"]["edges"][0]["node"]["dateTime"]).strftime("%A, %d %B %Y, %I:%M %p")}\n:busts_in_silhouette: #{group["unifiedEvents"]["edges"][0]["node"]["going"]} going"
      },
      accessory: {
        type: "image",
        image_url: group["unifiedEvents"]["edges"][0]["node"]["imageUrl"],
        alt_text: "#{group["name"]} - #{group["unifiedEvents"]["edges"][0]["node"]["title"]}"
      }
    },
      {
        type: "actions",
        elements: [
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":dart: RSVP",
              emoji: true
            },
            url: group["unifiedEvents"]["edges"][0]["node"]["eventUrl"]
          }
        ]
      },
    ]

    if group["name"] == "Tampa Devs"
      event_blocks[0][:text][:text] = ":tampadevs:" + " " + event_blocks[0][:text][:text]
    end

    if group["unifiedEvents"]["edges"][0]["node"]["venue"]
      event_blocks[0][:text][:text] += if group["unifiedEvents"]["edges"][0]["node"]["venue"]["name"] != "Online event"
        "\n\n:round_pushpin: <https://www.google.com/maps/dir/?api=1&destination=#{group["unifiedEvents"]["edges"][0]["node"]["venue"].map { |k, v| "#{k}=#{URI.encode_www_form_component(v)}" }.join("&")}|#{group["unifiedEvents"]["edges"][0]["node"]["venue"].values.join(", ")}>"
      else
        "\n\n:computer: Online event"
      end
    end

    event_blocks
  end

  def self.link_utm(url, source: "", medium: "", campaign: "")
    uri = URI(url)

    params = URI.decode_www_form(uri.query || "") << ["utm_source", source]
    params << ["utm_medium", medium]
    params << ["utm_campaign", campaign]

    uri.query = URI.encode_www_form(params)
    uri.to_s
  end
end
