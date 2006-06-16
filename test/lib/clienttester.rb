$:.unshift '../lib'
require 'xmpp4r'
require 'test/unit'
require 'socket'

module Jabber
  ##
  # The ClientTester is a mix-in which provides a setup and teardown
  # method to prepare a Stream object (@client) and two methods
  # interfacing as the "server side":
  # * send(xml):: Send a stanza to @client
  # * receive:: (Wait and) retrieve a stanza sent by the client (in order)
  #
  # The server side is a stream, too: add your callbacks to @server
  #
  # ClientTester is written to test complex helper classes.
  module ClientTester
    SOCKET_PORT = 65223

    def setup
      servlisten = TCPServer.new(SOCKET_PORT)
      Thread.new {
        serversock = servlisten.accept
        servlisten.close
        serversock.sync = true
        @server = Stream.new(true)
        @server.add_xml_callback { |xml|
          if xml.prefix == 'stream' and xml.name == 'stream'
            send('<stream:stream>')
            true
          else
            false
          end
        }
        @server.start(serversock)
      }

      clientsock = TCPSocket.new('localhost', SOCKET_PORT)
      clientsock.sync = true
      @client = Stream.new(true)
      @client.start(clientsock)

      @client.send('<stream:stream>') { |reply|
        true
      }

      @state = 0
      @states = []
      @state_wait = Mutex.new
      @state_wait.lock
      @server.add_stanza_callback { |stanza|
        if @state < @states.size
          @states[@state].call(stanza)
          @state += 1
        end
        @state_wait.unlock

        false
      }
    end

    def teardown
      @client.close
      @server.close
    end

    def send(xml)
      @server.send(xml)
    end

    def receive
      @receive_lock.lock

      loop {
        @stanzas_lock.synchronize {
          if @stanzas.size > 0
            @receive_lock.unlock
            return @stanzas.shift
          end
        }

        @receive_lock.lock
        @receive_lock.unlock
      }
    end

    def state(&block)
      @states << block
    end

    def wait_state
      @state_wait.lock
    end
  end
end