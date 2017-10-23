# -*- encoding: utf-8 -*-
module Smith
  module Messaging

    module Util

      def number_of_messages
        status do |num_messages, _|
          yield num_messages
        end
      end

      def number_of_consumers
        status do |_, num_consumers|
          yield num_consumers
        end
      end

      private

      include AmqpErrors
      include Logging

      def open_channel(opts={}, &blk)
        AMQP::Channel.new(Smith.connection) do |channel,ok|
          logger.debug { "Opened channel: #{"%x" % channel.object_id}" }

          # Set up auto-recovery. This will ensure that amqp will
          # automatically reconnet to the broker if there is an error.
          channel.auto_recovery = true
          logger.debug { "Channel auto recovery set to ture" }

          # Set up QOS. If you do not do this then any subscribes will get
          # overwhelmed if there are too many messages.
          prefetch = opts[:prefetch] || Smith.config.agent.prefetch

          channel.prefetch(prefetch)
          logger.debug { "AMQP prefetch set to: #{prefetch}" }

          blk.call(channel)
        end
      end

      def random(prefix = '', suffix = '')
        "#{prefix}#{SecureRandom.hex(8)}#{suffix}"
      end

      def option_or_default(options, key, default, &blk)
        if options.is_a?(Hash)
          if options.key?(key)
            v = options.delete(key)
            (blk) ? blk.call(v) : v
          else
            default
          end
        else
          raise ArguementError, "Options must be a Hash."
        end
      end
    end
  end
end
