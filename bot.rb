require 'sinatra/base'
require 'dotenv/load'
require 'slack-ruby-client'
require 'json'
require 'uri'
require 'net/http'
require 'metainspector'
require 'domainatrix'

Slack.configure do |config|
  config.token = ENV['SLACK_BOT_USER_TOKEN']
  fail 'Missing API token' unless config.token
end

# Slack Ruby client
$client = Slack::Web::Client.new

class API < Sinatra::Base
  # Send response of message to response_url
  def self.send_response(response_url, json_msg)
    url = URI.parse(response_url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(url)
    request['content-type'] = 'application/json'
    auth = 'Bearer ' + ENV['SLACK_BOT_USER_TOKEN']
    request['Authorization'] = auth
    # puts request
    request.body = json_msg
    response = http.request(request)
    # puts response.code
    # puts response.body
  end

  post '/slack/events' do
    request_data = JSON.parse(request.body.read) 
    case request_data['type']
      when 'url_verification'
        # URL Verification event with challenge parameter
        request_data['challenge']
      when 'event_callback'
        # Verify requests
        if request_data['token'] != ENV['SLACK_VERIFICATION_TOKEN']
          return
        end
        team_id = request_data['team_id']
        event_data = request_data['event']

        case event_data['type']
          # Link Shared event
          when 'link_shared'
            ts = event_data['message_ts']
            channel = event_data['channel']

            body_hash = Hash.new
            body_hash['channel'] = channel
            body_hash['ts'] = ts

            unfurl_hash = Hash.new

            links = event_data['links']
            links.each do |item|
              posted_url = item['url']
              parsed_url = Domainatrix.parse(posted_url)
              # puts
              rewrite_url = "https://m." + parsed_url.domain + "." + parsed_url.public_suffix + parsed_url.path
              # puts posted_url
              # puts rewrite_url
              page = MetaInspector.new(rewrite_url)
    
              title = page.meta_tags['property']['og:title'][0]
              # puts "TITLE: #{title}"
              description = page.meta_tags['name']['description'][0]
              image_url = page.meta_tags['property']['og:image'][0]
              url = page.meta_tags['property']['og:url'][0]
    
              blocks_array = []
              text_block_hash = Hash.new
              text_block_hash['type'] = "section"
              text_hash = Hash.new
              text_hash['type'] = "mrkdwn"
              text_hash['text'] = "*#{title}*\n#{description}"
              text_block_hash['text'] = text_hash
              blocks_array << text_block_hash
              image_block_hash = Hash.new
              image_block_hash['type'] = "image"
              image_title_hash = Hash.new
              image_title_hash['type'] = "plain_text"
              image_title_hash['text'] = "縮圖"
              image_title_hash['emoji'] = true
              image_block_hash['title'] = image_title_hash
              image_block_hash['image_url'] = image_url
              image_block_hash['alt_text'] = title
              blocks_array << image_block_hash
              blocks_hash = Hash.new
              blocks_hash['blocks'] = blocks_array

              unfurl_hash[posted_url] = blocks_hash
            end    

            body_hash['unfurls'] = unfurl_hash
            json_body = JSON.generate(body_hash)
            # puts
            # puts json_body
            API.send_response('https://slack.com/api/chat.unfurl', json_body)
          else
            puts "Unexpected events\n"
          end


        status 200 


    end
  end
end
