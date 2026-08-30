require "test_helper"

class LocalesTest < Minitest::Test
  include OutputHelpers

  def test_both_home_pages_are_generated
    assert_page "index.html"
    assert_page "pt/index.html"
  end

  def test_html_lang_attribute_matches_the_locale
    assert_includes page_body("index.html"), 'lang="en"'
    assert_includes page_body("pt/index.html"), 'lang="pt"'
  end

  def test_translations_resolve_per_locale
    assert_includes page_body("index.html"), "Projects"
    assert_includes page_body("pt/index.html"), "Projetos"
  end

  def test_locale_tables_have_identical_key_sets
    en = flatten_keys(YAML.load_file(ROOT.join("src/_locales/en.yml")).fetch("en"))
    pt = flatten_keys(YAML.load_file(ROOT.join("src/_locales/pt.yml")).fetch("pt"))

    assert_equal [], en - pt,
      "chaves presentes em en.yml e ausentes em pt.yml: #{(en - pt).join(', ')}"
    assert_equal [], pt - en,
      "chaves presentes em pt.yml e ausentes em en.yml: #{(pt - en).join(', ')}"
  end

  # Renomear chaves de traducao falha em silencio: o Rails I18n devolve
  # "translation missing: ..." dentro do HTML e o build passa. Este teste le
  # os partials, extrai cada t("...") e cobra que a chave exista nos dois
  # idiomas.
  def test_every_translation_key_used_by_the_demo_partials_exists
    tabelas = {
      "en" => YAML.load_file(ROOT.join("src/_locales/en.yml")).fetch("en"),
      "pt" => YAML.load_file(ROOT.join("src/_locales/pt.yml")).fetch("pt"),
    }

    Dir.glob(ROOT.join("src/_partials/demos/*.erb")).sort.each do |arquivo|
      chaves = File.read(arquivo).scan(/\bt\("([a-z0-9_.]+)"/).flatten.uniq

      chaves.each do |chave|
        tabelas.each do |idioma, tabela|
          valor = chave.split(".").reduce(tabela) do |nivel, parte|
            nivel.is_a?(Hash) ? nivel[parte] : nil
          end
          refute_nil valor,
            "#{File.basename(arquivo)} usa t(\"#{chave}\"), que nao existe em #{idioma}.yml"
        end
      end
    end
  end

  private

  # ["nav.home", "nav.projects", ...] a partir de um hash aninhado
  def flatten_keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      full = [prefix, key].compact.join(".")
      value.is_a?(Hash) ? flatten_keys(value, full) : [full]
    end.sort
  end
end
