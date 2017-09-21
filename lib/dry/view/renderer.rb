require 'tilt'
require 'dry-equalizer'

module Dry
  module View
    class Renderer
      include Dry::Equalizer(:paths, :format)

      TemplateNotFoundError = Class.new(StandardError)

      attr_reader :paths, :encoding, :format, :engine, :tilts

      def self.tilts
        @__engines__ ||= {}
      end

      def initialize(paths, encoding:, format:)
        @paths = paths
        @encoding = encoding
        @format = format
        @tilts = self.class.tilts
      end

      def call(template, scope, &block)
        path = lookup(template)

        if path
          render(path, scope, &block)
        else
          msg = "Template #{template.inspect} could not be found in paths:\n#{paths.map { |pa| "- #{pa.to_s}" }.join("\n")}"
          raise TemplateNotFoundError, msg
        end
      end

      def render(path, scope, &block)
        tilt(path).render(scope, &block)
      end

      def chdir(dirname)
        new_paths = paths.map { |path| path.chdir(dirname) }

        self.class.new(new_paths, encoding: encoding, format: format)
      end

      def lookup(name)
        paths.inject(false) { |result, path|
          result || path.lookup(name, format)
        }
      end

      private

      def tilt(path)
        tilts.fetch(path) {
          tilts[path] = Tilt.new(path, nil, default_encoding: encoding)
        }
      end
    end
  end
end
