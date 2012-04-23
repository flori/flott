require 'test_helper'
require 'flott'
require 'stringio'
require 'fileutils'

class TC_Cache < Test::Unit::TestCase
  include FileUtils
  include Flott

  TEMPLATES_DIR = File.join(File.dirname(__FILE__), 'templates')

  def setup
    @cache = Cache.new(TEMPLATES_DIR, 2)
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
    sleep 1.0
    touch File.join(TEMPLATES_DIR, 'template')
    assert_equal template, @cache.get('template')
    sleep 3.0
    assert template != @cache.get('template')
    template = @cache.get('template')
    touch File.join(TEMPLATES_DIR, 'template')
    assert_equal template, @cache.get('template')
    template2 = @cache.get('template2')
    assert_kind_of Template, template2
    assert_equal template2, @cache.get('template2')
    @cache.reload_time = -1
    template = @cache.get('template')
    assert template != @cache.get('template')
  end

  def test_get_deep
    template = @cache.get('subdir/deeptemplate')
    assert_kind_of Template, template
    assert_equal template, @cache.get('subdir/deeptemplate')
    assert_equal template, @cache.get('subdir/deeptemplate')
    output = ''
    template.evaluate(Environment.new(output))
    assert_equal <<__EOT, output
<html>
<body>
Toplevel2

(deepincluded2)

Toplevel2

(deepincluded2)

Toplevel2
</body>
</html>
__EOT
  end
end
