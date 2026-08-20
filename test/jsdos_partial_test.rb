require "test_helper"

class JsdosPartialTest < Minitest::Test
  include OutputHelpers

  EN = "projects/tic-tac-toe/index.html".freeze
  PT = "pt/projects/tic-tac-toe/index.html".freeze

  def test_the_project_page_renders_the_emulator_demo
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, 'class="demo demo-jsdos"',
        "#{pagina} nao renderizou a demo jsdos"
      refute_includes corpo, 'class="demo demo-none"',
        "#{pagina} ainda mostra o placeholder"
    end
  end

  def test_the_demo_points_at_the_bundle_and_at_our_own_emulator_path
    corpo = page_body(EN)
    assert_includes corpo, 'data-bundle="/demos/tic-tac-toe/vca.jsdos"'
    assert_includes corpo, 'data-path-prefix="/vendor/js-dos/emulators/"'
  end

  def test_the_hooks_the_player_and_keypad_depend_on_exist
    corpo = page_body(EN)
    %w[data-jsdos data-jsdos-frame data-jsdos-start
       data-jsdos-screen data-jsdos-error].each do |gancho|
      assert_includes corpo, gancho, "faltou o gancho #{gancho}"
    end
  end

  # O readme do repositorio do jogo diz "Type OLC ... to play O", mas o codigo
  # compara com 'C' (vca.asm:80) e foi C22 que funcionou nos testes manuais.
  # Este teste impede que alguem "corrija" as instrucoes seguindo o readme.
  def test_the_circle_command_is_documented_as_C
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, "<code>C22</code>",
        "#{pagina} deveria documentar C22 como o comando do circulo"
      refute_includes corpo, "<code>O22</code>",
        "#{pagina} documenta O22, que nao existe no jogo"
    end
  end

  def test_both_locales_render_their_own_instructions
    assert_includes page_body(EN), "Commands"
    assert_includes page_body(PT), "Comandos"
  end

  # Sem JavaScript o botao nao faz nada. Oferecer um botao morto e pior do que
  # nao oferecer nenhum: ele nasce desligado e o player o liga no boot.
  def test_the_start_button_is_disabled_until_the_player_enables_it
    [EN, PT].each do |pagina|
      botao = page_body(pagina)[/<button[^>]*data-jsdos-start[^>]*>/]
      refute_nil botao, "#{pagina} nao tem o botao de iniciar"
      assert_includes botao, "disabled",
        "#{pagina} entrega um botao clicavel que so o JavaScript sabe atender"
    end
  end

  def test_without_javascript_the_page_says_where_the_game_is
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      trecho = corpo[/<noscript>.*?<\/noscript>/m]
      refute_nil trecho, "#{pagina} nao explica nada para quem esta sem JavaScript"
      assert_match(%r{href="https://github\.com/[^"]+"}, trecho,
        "#{pagina}: o aviso de noscript precisa apontar para o repositorio")
    end
  end

  # O teclado ficava fora do if/else, so indentado como se estivesse dentro:
  # um projeto sem bundle renderizava a mensagem de erro E um teclado que nao
  # tinha emulador nenhum para comandar.
  def test_the_keypad_only_exists_where_there_is_a_bundle
    fonte = ROOT.join("src/_partials/demos/_jsdos.erb").read

    corpo_do_else = fonte[/<% else %>(.*?)<% end %>/m, 1]
    refute_nil corpo_do_else, "nao encontrei o ramo do else no partial"
    assert_includes corpo_do_else, "data-jsdos-keypad",
      "o teclado precisa estar dentro do ramo que tem bundle"

    depois_do_end = fonte[/<% end %>(.*)/m, 1]
    refute_includes depois_do_end.to_s, "data-jsdos-keypad",
      "o teclado esta fora do if/else e aparece ate sem bundle"
  end

  # Servir o wdosbox.wasm e distribuir uma obra GPL-2.0. O aviso precisa levar
  # ao texto da licenca — que agora viaja junto dos binarios — e ao repositorio
  # de onde vem o DOSBox, que nao e o do front-end do js-dos.
  def test_the_license_notice_links_the_text_and_both_upstreams
    [EN, PT].each do |pagina|
      aviso = page_body(pagina)[/<p class="demo-license">.*?<\/p>/m]
      refute_nil aviso, "#{pagina} nao tem o aviso de licenca"

      assert_includes aviso, 'href="/vendor/js-dos/LICENSE.txt"',
        "#{pagina}: o aviso precisa linkar o texto da GPL-2.0 servido por nos"
      assert_includes aviso, "https://github.com/caiiiycuk/js-dos",
        "#{pagina}: falta o link para o front-end do js-dos"
      assert_includes aviso, "https://github.com/caiiiycuk/emulators",
        "#{pagina}: o binario do DOSBox vem do caiiiycuk/emulators, nao do js-dos"
    end
  end
end
