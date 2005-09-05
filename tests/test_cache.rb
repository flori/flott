#!/usr/bin/env ruby

require 'test/unit'
require 'flott'
require 'stringio'
require 'fileutils'

class TC_Cache < Test::Unit::TestCase
  include FileUtils
  include Flott

  def setup
    @cache = Cache.new('tests/templates')
  end

  def test_kind
    assert_kind_of Cache, @cache
  end

  def test_get
    template = @cache.get('template')
    assert_kind_of Template, template
p template.pathes
    assert_equal template, @cache.get('template')
    p File.stat('tests/templates/template').mtime
    touch 'tests/templates/template'
    p File.stat('tests/templates/template').mtime
    assert template != @cache.get('template')
    template2 = @cache.get('template2')
    assert_kind_of Template, template2
    assert_equal template2, @cache.get('template2')
  end
end
  # vim: set et sw=2 ts=2:
