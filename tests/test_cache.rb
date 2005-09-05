#!/usr/bin/env ruby

require 'test/unit'
require 'flott'
require 'stringio'
require 'fileutils'

class TC_Cache < Test::Unit::TestCase
  include FileUtils
  include Flott

  def setup
    @cache = Cache.new('tests/templates', 2)
  end

  def test_kind
    assert_kind_of Cache, @cache
  end

  def test_get
    template = @cache.get('template')
    assert_kind_of Template, template
    assert_equal template, @cache.get('template')
    assert_equal template, @cache.get('template')
  end

  def test_reload
    template = @cache.get('template')
    assert_equal template, @cache.get('template')
    assert_equal template, @cache.get('template')
    sleep 1
    touch 'tests/templates/template'
    assert_equal template, @cache.get('template')
    sleep 2.5
    assert template != @cache.get('template')
    template = @cache.get('template')
    touch 'tests/templates/template'
    assert_equal template, @cache.get('template')
    template2 = @cache.get('template2')
    assert_kind_of Template, template2
    assert_equal template2, @cache.get('template2')
    @cache.reload_time = -1
    template = @cache.get('template')
    assert template != @cache.get('template')
  end
end
  # vim: set et sw=2 ts=2:
