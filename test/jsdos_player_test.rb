require "test_helper"

class JsdosPlayerTest < Minitest::Test
  include OutputHelpers

  # Apenas o JavaScript que nos escrevemos. O js-dos vendorizado e codigo de
  # terceiro e contem a URL da CDN dele como padrao — o que importa e que o
  # NOSSO codigo sobrescreva esse padrao.
  def nosso_javascript
    Dir.glob(OUTPUT.join("_bridgetown/static/*.js"))
  end

  def test_our_javascript_is_published
    refute_empty nosso_javascript, "nenhum bundle JavaScript foi gerado"
  end

  def test_the_player_overrides_the_emulator_path
    encontrou = nosso_javascript.any? do |arquivo|
      File.read(arquivo).include?("/vendor/js-dos/emulators/")
    end

    assert encontrou,
      "o pathPrefix nao aparece no JavaScript publicado; sem ele o js-dos " \
      "baixa o emulador da CDN dele"
  end

  # Le o FONTE. No bundle minificado a palavra "dosbox" ja aparece dentro do
  # pathPrefix, entao procura-la la passaria mesmo sem o backend configurado.
  def test_the_player_asks_for_the_light_dosbox_backend
    fonte = ROOT.join("frontend/javascript/jsdos-player.js").read

    assert_match(/backend:\s*"dosbox"/, fonte,
      "o player precisa pedir o backend dosbox explicitamente")
    refute_match(/backend:\s*"dosboxX"/, fonte,
      "o backend dosboxX tem 7,5 MB e nao e usado por este projeto")
  end

  def test_the_player_hides_the_third_party_ui
    fonte = ROOT.join("frontend/javascript/jsdos-player.js").read

    assert_match(/kiosk:\s*true/, fonte,
      "sem kiosk o js-dos desenha a interface dele por cima da nossa moldura")
  end

  def test_our_javascript_makes_no_third_party_requests
    nosso_javascript.each do |arquivo|
      urls = File.read(arquivo).scan(%r{https?://[^\s"'`)]+})
      externas = urls.reject { |u| u.start_with?("http://www.w3.org/") }

      assert_empty externas.uniq,
        "#{File.basename(arquivo)} referencia URL externa: #{externas.uniq.first(3).join(', ')}"
    end
  end
end
