# run via: ruby mql4zmq_sub.rb 10.18.16.5:2027 tick [channel 2] [channel 3]...
require 'zmq'

# Check for help requested
if ARGV[0] == "-h" || ARGV[0] == "--help"
        puts "Usage: ruby mql4zmq_sub.rb [MetaTrader IP Address]:[MQL4ZMQ EA Port Number default 2027] [channel 1] [channel 2] [channel 3]..."
        puts "Example:\nruby zma_ploutos_sub.rb 10.18.16.16:2027 tick trades\n=> subscribes to the 'tick' and 'trades' channels coming from the MetaTrader EA at 10.18.16.16."
else
        # Initialize the ZeroMQ context.
        context  = ZMQ::Context.new

        # Store the location of the server in a variable.
        server   = ARGV[0]

        # Retrieve the list of channels to subscribe to. We drop the first value because that is the server address.
        channels = ARGV.drop(1)

        # Configure the socket to be of type subscribe.
        sub = context.socket ZMQ::SUB

        # Connect to the server using the subscription model.
        sub.connect "tcp://#{server}"

        # Subscribe to the requested channels.
        channels.each do |ch| 
                sub.setsockopt ZMQ::SUBSCRIBE, ch 
        end

        # Do something when we receive a message.
        while line = sub.recv
          channel, bid, ask, time = line.split ' ', 4
          puts "##{channel} [#{time}]: #{bid[0..7]} #{ask[0..7]}"
        end
end