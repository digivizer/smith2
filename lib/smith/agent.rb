require 'pp'

module Smith
  class Agent

    include Logger

    attr_accessor :name

    def initialize(options={})
      Smith.on_error = proc {|e| pp e}

      @agent_options = {}.tap do |acc|
        acc[:monitor] = options.delete(:monitor) || true
        acc[:singleton] = options.delete(:singleton) || true
      end

      @name = self.class.to_s
      @queues = Cache.new
      @queues.operator ->(name){Messaging.new(name)}

      @default_message_options = {:ack => true, :durable => true}

      # Set up a default queue
      default_queue

      agent_queue
      acknowledge_start
      start_keep_alive

      logger.info("Starting #{name}")
    end

    def run
      raise ArgumentError, "You need to supply a default_handler" if !respond_to?(:default_handler)

      default_queue.receive_message(&method(:default_handler))
    end

    def get_message(queue, options={}, &block)
      queues(queue).receive_message(options) do |header,message|
        block.call(header, message)
      end
    end

    private

    def acknowledge_start
      agent_data = @agent_options.merge(:pid => $$, :name => self.class.to_s, :started_at => Time.now.utc)
      Smith::Messaging.new(:acknowledge_start).send_message(agent_data, message_opts)
    end

    def acknowledge_stop
      agent_data = {:pid => $$, :name => self.class.to_s}
      Smith::Messaging.new(:acknowledge_stop).send_message(agent_data, message_opts)
    end

    def start_keep_alive
      if @agent_options[:monitor]
        send_keep_alive(queues(:keep_alive))
        EventMachine::add_periodic_timer(1) do
          send_keep_alive(queues(:keep_alive))
        end
      else
        logger.debug("Not initiating keep alive agent is not being monitored: #{@name}")
      end
    end

    def agent_queue
      queue_name = "#{agent_queue_name}.control"
      logger.debug("Setting up agent queue: #{queue_name}")
      queues(queue_name).receive_message do |header, payload|
        command = payload['command']
        args = payload['args']

        logger.debug("Command received on agent control queue: #{command} #{args}")

        case command
        when 'stop'
          acknowledge_stop
          Smith.stop
        when 'log_level'
          logger.info("Setting log level to #{args} for: #{name}")
          Logger.level args
        else
          logger.warn("Unknown command: #{command} -> #{args.inspect}")
        end
      end
    end

    def message_opts(options={})
      options.merge(@default_message_options)
    end

    def default_queue
      queues(agent_queue_name)
    end

    def agent_queue_name
      "agent.#{name.sub(/Agent$/, '').snake_case}"
    end

    def queues(queue_name)
      @queues.entry(queue_name)
    end

    def send_keep_alive(queue)
      queue.consumers? do |queue|
        queue.send_message({:name => self.class.to_s, :time => Time.now.utc}, message_opts(:durable => false))
      end
    end
  end
end
