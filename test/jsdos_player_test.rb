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

  # O player injetava o js-dos.css no <head> no clique. Como ele abre com o
  # Preflight do Tailwind e vinha depois da nossa folha, o clique em Jogar
  # reestilizava o site inteiro. O modo kiosk nao precisa dele: as regras que
  # a arvore do js-dos usa estao em crt.css, escopadas em .demo-screen.
  def test_the_player_does_not_inject_a_third_party_stylesheet
    fonte = ROOT.join("frontend/javascript/jsdos-player.js").read
           .lines.map { |linha| linha.sub(%r{//.*$}, "") }.join

    refute_match(/\.css/, fonte,
      "o player nao deveria carregar folha de estilo do js-dos")
    refute_match(/rel\s*=\s*"stylesheet"/, fonte,
      "o player nao deveria anexar <link rel=stylesheet> nenhum")
  end

  def fonte_do_player
    ROOT.join("frontend/javascript/jsdos-player.js").read
  end

  # O window.Dos() volta na hora, entao o catch so cobria falha de carregar o
  # script. Bundle 404, wasm que nao instancia, arquivo faltando no
  # pathPrefix: tudo isso morre dentro do js-dos, que nao emite evento de erro
  # (o onEvent dele so dispara emu-ready, ci-ready e fullscreen-change). Sem
  # relogio, o visitante fica com um retangulo preto e nenhuma explicacao.
  def test_an_async_failure_still_reaches_the_visitor
    fonte = fonte_do_player

    assert_match(/setTimeout\(/, fonte,
      "o player precisa armar um relogio ao chamar Dos(); sem ele uma falha " \
      "assincrona do js-dos nunca vira mensagem")
    assert_match(/clearTimeout\(/, fonte,
      "o relogio precisa ser desarmado quando o emulador fica pronto")
    assert_match(/ci-ready/, fonte,
      "o desarme tem que estar preso ao ci-ready")
    assert_match(/erro\.hidden\s*=\s*false/, fonte,
      "quando o relogio estoura, a mensagem traduzida precisa aparecer")
  end

  def test_the_player_gives_up_before_the_visitor_does
    limite = fonte_do_player[/LIMITE_DE_BOOT_MS\s*=\s*(\d+)/, 1]
    refute_nil limite, "nao encontrei o limite de boot"
    assert_operator limite.to_i, :>=, 10_000,
      "limite curto demais reprova conexao lenta antes de o emulador chegar"
    assert_operator limite.to_i, :<=, 60_000,
      "limite longo demais deixa o visitante olhando um retangulo preto"
  end

  # O catch desreferencia moldura/tela/erro: com um partial reorganizado, ele
  # estouraria por cima do erro original.
  def test_the_player_checks_the_markup_before_touching_it
    assert_match(/if\s*\(!moldura\s*\|\|\s*!tela\s*\|\|\s*!erro\)\s*return/,
      fonte_do_player,
      "bootJsdos precisa desistir cedo quando o markup esperado nao esta la")
  end

  # O botao vem `disabled` do HTML para nao existir botao morto sem
  # JavaScript. Quem liga e quem sabe atender o clique.
  def test_the_player_enables_the_start_button
    assert_match(/\.disabled\s*=\s*false/, fonte_do_player,
      "o player precisa ligar o botao que o HTML entrega desligado")
  end
end
