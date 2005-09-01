module Flott
  class FlottException < StandardError
    def self.wrap(exception)
      wrapper = new(exception.message)
      wrapper.set_backtrace exception.backtrace
      wrapper
    end
  end

  autoload :Parser, 'flott/parser'
end
  # vim: set et sw=2 ts=2: 
