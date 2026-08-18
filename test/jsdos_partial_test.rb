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
end
