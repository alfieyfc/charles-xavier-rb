require './bot'

# Initialize the app and create the API (bot) object
run Rack::Cascade.new([Rack::File.new("public"),API])