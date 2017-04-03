require 'inflecto'
require 'dry/view/part'

module Dry
  module View
    class Decorator
      attr_reader :config

      # @api public
      def call(name, value, renderer:, context:, **options)
        klass = part_class(name, value, **options)

        if value.respond_to?(:to_ary)
          singular_name = Inflecto.singularize(name).to_sym
          arr = value.to_ary.map { |obj| klass.new(name: singular_name, value: obj, renderer: renderer, context: context) }
          klass.new(name: name, value: arr, renderer: renderer, context: context)
        else
          klass.new(name: name, value: value, renderer: renderer, context: context)
        end
      end

      # @api public
      def part_class(name, value, **options)
        options.fetch(:as) { Part }
      end
    end
  end
end
