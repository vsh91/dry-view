require 'dry-configurable'
require 'dry-equalizer'

require 'dry/view/path'
require 'dry/view/exposures'
require 'dry/view/renderer'
require 'dry/view/decorator'
require 'dry/view/scope'

module Dry
  module View
    class Controller
      DEFAULT_LAYOUTS_DIR = 'layouts'.freeze
      DEFAULT_CONTEXT = Object.new.freeze
      EMPTY_LOCALS = {}.freeze

      include Dry::Equalizer(:config)

      extend Dry::Configurable

      setting :paths
      setting :layout, false
      setting :template
      setting :default_encoding, 'utf-8'
      setting :default_format, :html
      setting :context, DEFAULT_CONTEXT
      setting :decorator, Decorator.new

      attr_reader :config
      attr_reader :layout_dir
      attr_reader :layout_path
      attr_reader :template_path
      attr_reader :exposures

      # @api public
      def self.paths
        Array(config.paths).map { |path| Dry::View::Path.new(path) }
      end

      # @api private
      def self.renderer(encoding, format)
        renderers.fetch(format) {
          renderers[format] = Renderer.new(paths, encoding: encoding, format: format)
        }
      end

      # @api private
      def self.renderers
        @renderers ||= {}
      end

      # @api public
      def self.expose(*names, **options, &block)
        if names.length == 1
          exposures.add(names.first, block, options)
        else
          names.each do |name|
            exposures.add(name, options)
          end
        end
      end

      # @api public
      def self.private_expose(*names, **options, &block)
        expose(*names, **options, private: true, &block)
      end

      # @api private
      def self.exposures
        @exposures ||= Exposures.new
      end

      # @api public
      def initialize
        @config = self.class.config
        @layout_dir = DEFAULT_LAYOUTS_DIR
        @layout_path = "#{layout_dir}/#{config.layout}"
        @template_path = config.template
        @exposures = self.class.exposures.bind(self)
      end

      # @api public
      def call(encoding: config.default_encoding, format: config.default_format, context: config.context, **input)
        renderer = self.class.renderer(encoding, format)

        template_content = renderer.(template_path, template_scope(renderer, context, input))

        return template_content unless layout?

        renderer.(layout_path, layout_scope(renderer, context)) do
          template_content
        end
      end

      # @api public
      def locals(locals: EMPTY_LOCALS, **input)
        exposures.locals(input).merge(locals)
      end

      private

      def layout?
        !!config.layout
      end

      def layout_scope(renderer, context)
        scope(renderer.chdir(layout_dir), context)
      end

      def template_scope(renderer, context, **input)
        scope(renderer.chdir(template_path), context, locals(input))
      end

      def scope(renderer, context, locals = EMPTY_LOCALS)
        Scope.new(
          renderer: renderer,
          context: context,
          locals: decorated_locals(renderer, context, locals)
        )
      end

      def decorated_locals(renderer, context, locals)
        decorator = self.class.config.decorator

        locals.each_with_object({}) { |(key, val), result|
          # Decorate truthy values only
          if val
            options = exposures.key?(key) ? exposures[key].options : {}

            val = decorator.(
              key,
              val,
              renderer: renderer,
              context: context,
              **options
            )
          end

          result[key] = val
        }
      end
    end
  end
end
