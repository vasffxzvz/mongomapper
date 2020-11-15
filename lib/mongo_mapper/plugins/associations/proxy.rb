# encoding: UTF-8
require 'forwardable'

module MongoMapper
  module Plugins
    module Associations
      class Proxy
        extend Forwardable

        alias :proxy_respond_to? :respond_to?
        alias :proxy_extend :extend

        attr_reader :proxy_owner, :association, :target

        alias :proxy_association :association

        def_delegators :proxy_association, :klass, :options
        def_delegator  :klass, :collection

        def initialize(owner, association)
          @proxy_owner, @association, @loaded = owner, association, false
          Array(association.options[:extend]).each { |ext| proxy_extend(ext) }
          reset
        end

        [
          :to_mongo,
          :is_a?,
        ].each do |m|
          define_method m do |*args, &block|
            if load_target
              target.send(m, *args, &block)
            end
          end
        end

        [
          :==,
          :!=,
          :nil?,
          :blank?,
          :present?,
          # Active support in rails 3 beta 4 can override to_json after this is loaded,
          # at least when run in mongomapper tests. The implementation was changed in master
          # some time after this, so not sure whether this is still a problem.
          #
          # In rails 2, this isn't a problem however it also solves an issue where
          # to_json isn't forwarded because it supports to_json itself
          :to_json,
          # see comments to to_json
          :as_json,
        ].each do |m|
          define_method m do |*args, &block|
            load_target
            target.send(m, *args, &block)
          end
        end

        def inspect
          load_target
          "#<#{self.class.inspect}:#{object_id} #{@target.inspect}>"
        end

        def loaded?
          @loaded
        end

        def loaded
          @loaded = true
        end

        def reload
          reset
          load_target
          self unless target.nil?
        end

        # :nocov:
        def replace(v)
          raise NotImplementedError
        end
        # :nocov:

        def reset
          @loaded = false
          @target = nil
        end

        def respond_to?(*args)
          proxy_respond_to?(*args) || (load_target && target.respond_to?(*args))
        end

        def send(method, *args, &block)
          if proxy_respond_to?(method, true)
            super
          else
            load_target
            target.send(method, *args, &block)
          end
        end

        def read
          load_target
          @target
        end

        def write(value)
          replace(value)
          read
        end

      protected

        def load_target
          unless loaded?
            if @target.is_a?(Array) && @target.any?
              @target = find_target + @target.find_all { |record| !record.persisted? }
            else
              @target = find_target
            end
            loaded
          end
          @target
        rescue MongoMapper::DocumentNotFound
          reset
        end

        # :nocov:
        def find_target
          raise NotImplementedError
        end
        # :nocov:

        def flatten_deeper(array)
          array.collect do |element|
            (element.respond_to?(:flatten) && !element.is_a?(Hash)) ? element.flatten : element
          end.flatten
        end

      private

        def method_missing(method, *args, &block)
          if load_target
            target.send(method, *args, &block)
          end
        end
      end
    end
  end
end
