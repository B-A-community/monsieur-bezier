# Словари двух языков: ни одна строка не забыта, плейсхолдеры совпадают,
# сборка умеет переключать язык. Запуск:  ruby test/test_lang.rb
$LOAD_PATH.unshift(__dir__)
require 'minitest/autorun'
require 'sketchup'

SRC = File.expand_path('../src/monsieur_bezier', __dir__)
require "#{SRC}/lang"

M = BACommunity::MonsieurBezier

class LangRubyTest < Minitest::Test
  def test_both_languages_have_the_same_keys
    assert_equal M::STRINGS['ru'].keys.sort, M::STRINGS['en'].keys.sort
  end

  # %d в русской строке и %s в английской уронят format в одной из сборок.
  def test_placeholders_match_between_languages
    M::STRINGS['ru'].each do |key, ru|
      en = M::STRINGS['en'][key]
      assert_equal ru.scan(/%[a-z]/), en.scan(/%[a-z]/), "плейсхолдеры в :#{key}"
    end
  end

  def test_no_empty_strings
    M::STRINGS.each do |lang, table|
      table.each { |key, s| refute_empty s.strip, "#{lang}:#{key}" }
    end
  end

  def test_format_arguments_work
    assert_includes M.t(:status, 30), '30'
    assert_includes M.t(:bad_segments, '999'), '999'
  end

  def test_unknown_key_does_not_crash
    assert_equal 'no_such_key', M.t(:no_such_key)
  end

  def test_build_can_find_the_lang_line
    text = File.read("#{SRC}/lang.rb", encoding: 'utf-8')
    assert_match(/^\s*LANG = '[a-z]{2}'$/, text, 'build.ps1 ищет ровно такую строку')
  end
end

class LangJsTest < Minitest::Test
  JS = File.read("#{SRC}/html/i18n.js", encoding: 'utf-8')

  def keys(lang)
    block = JS[/^\s*#{lang}: \{(.*?)^\s*\}/m, 1]
    refute_nil block, "нет словаря #{lang} в i18n.js"
    block.scan(/^\s*(\w+):/).flatten.sort
  end

  def test_both_languages_have_the_same_keys
    assert_equal keys('ru'), keys('en')
  end

  def test_every_data_t_in_about_has_a_string
    html = File.read("#{SRC}/html/about.html", encoding: 'utf-8')
    used = html.scan(/data-t="(\w+)"/).flatten.uniq
    missing = used - keys('ru')
    assert_empty missing, 'в about.html есть data-t без строки в i18n.js'
  end

  def test_build_can_find_the_lang_line
    assert_match(/^var LANG = '[a-z]{2}';$/, JS)
  end
end
