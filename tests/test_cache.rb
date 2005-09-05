#!/usr/bin/env ruby

require 'test/unit'
require 'flott'
require 'stringio'

class TC_Cache < Test::Unit::TestCase
  include Flott

  def setup
    @cache = Cache.new('tests/templates', 5)
  end

  def test_kind
    assert_kind_of Cache, @cache
  end

  def test_foo
    @cache.get('template')
  end
end
  # vim: set et sw=2 ts=2:
