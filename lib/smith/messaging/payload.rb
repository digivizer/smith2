# -*- encoding: utf-8 -*-
module Smith

  module ACL
    module ACLInstanceMethods
      def inspect
        "<#{self.class.to_s}> -> #{self.to_hash}"
      end

      def as_json
        Yajl.dump(self.to_hash)
      end
    end

    module ClassMethods
      def content_class(e)
        @@acl_classes ||= {:default => Default}

        e = e.to_sym

        if @@acl_classes.include?(e)
          @@acl_classes[e]
        else
          class_name = Extlib::Inflection.camelize(e)
          if ACL.constants.include?(class_name)
            logger.error { "Shouldn't get here." }
          else
            logger.debug { "#{class_name} Loaded from #{e}.pb.rb" }
            ACL.const_get(class_name).tap do |clazz|
              # Override the inspect method
              @@acl_classes[e] = clazz.send(:include, ACLInstanceMethods)
            end
          end
        end
      end
    end

    class Factory

      @@acl_classes = {:default => Default}

      class << self
        def create(type, content={}, &blk)
          type = type.to_s

          unless @@acl_classes.include?(type)
            logger.debug { "Loding ACL: #{type}" }
            # decorate the ACL class
            @@acl_classes[type] = clazz(type).send(:include, ACLInstanceMethods)
            @@acl_classes[type].send(:define_method, :_type) {type}
          end

          if blk
            if content.empty?
              @@acl_classes[type].new.tap { |m| blk.call(m) }
            else
              raise ArgumentError, "You cannot give a content hash and a block."
            end
          else
            (content.empty?) ? @@acl_classes[type].new : @@acl_classes[type].new(content)
          end
        end

        def clazz(type)
          type.split(/::/).inject(ACL) do |a,m|
            a.const_get(Extlib::Inflection.camelize(m))
          end
        end
      end
    end

    class NewPayload
      include Logger

      # content can be an existing ACL class.
      def initialize(acl, opts={})
        @acl = acl
      end

      # The type of content.
      def _type
        @acl._type
      end

      # Returns a hash of the payload.
      def to_hash
        @acl.to_hash
      end

      # Encode the content, returning the encoded data.
      def encode
        @acl.serialize_to_string
      end

      # Returns true if the payload has all its required fields set.
      def initialized?
        raise RuntimeError, "You probably forgot to call #content or give the :from option when instantiating the object." if @acl.nil?
        @acl.initialized?
      end

      # Convert the payload to a pretty string.
      def to_s
        @acl.inspect
      end

      # Decode the content using the specified decoder.
      def self.decode(payload, type=:default)
        Factory.create(type).parse_from_string(payload)
      end
    end

    class Payload
      include Logger

      include ClassMethods
      extend ClassMethods

      # content can be an existing ACL class.
      def initialize(type=:default, opts={})
        if opts[:from]
          @type = opts[:from].class.to_s.split(/::/).last.snake_case
          @content = opts[:from]
        else
          @type = type
          @clazz = content_class(type)
        end
      end

      # Add content to the content or get the content from a payload
      def content(*content, &block)
        if content.empty?
          if block.nil?
            return @content
          else
            @content = @clazz.new
            block.call(@content)
          end
        else
          @content = @clazz.new(content.first)
        end
        self
      end

      # The type of content.
      def type
        @type.to_s
      end

      # Returns a hash of the payload.
      def to_hash
        @content.to_hash
      end

      # Encode the content, returning the encoded data.
      def encode
        @content.serialize_to_string
      end

      # Returns true if the payload has all its required fields set.
      def initialized?
        raise RuntimeError, "You probably forgot to call #content or give the :from option when instantiating the object." if @content.nil?
        @content.initialized?
      end

      # Convert the payload to a pretty string.
      def to_s
        @content.inspect
      end

      # Decode the content using the specified decoder.
      def self.decode(payload, type=:default)
        content_class(type).new.parse_from_string(payload)
      end
    end
  end
end
