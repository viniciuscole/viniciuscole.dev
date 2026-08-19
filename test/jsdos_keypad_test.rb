require "test_helper"

class JsdosKeypadTest < Minitest::Test
  include OutputHelpers

  EN = "projects/tic-tac-toe/index.html".freeze
  PT = "pt/projects/tic-tac-toe/index.html".freeze

  def test_the_keypad_is_rendered_in_both_locales
    [EN, PT].each do |pagina|
      assert_includes page_body(pagina), "data-jsdos-keypad",
        "#{pagina} nao tem o teclado na tela"
    end
  end

  def test_the_keypad_offers_every_cell_of_the_board
    corpo = page_body(EN)
    (1..3).each do |linha|
      (1..3).each do |coluna|
        assert_includes corpo, %(data-cell="#{linha}#{coluna}"),
          "faltou o botao da celula #{linha}#{coluna}"
      end
    end
  end

  def test_the_keypad_labels_come_from_the_locales
    assert_includes page_body(EN), "Restart"
    assert_includes page_body(PT), "Reiniciar"
  end

  # Antes de qualquer clique, nada dizia (visualmente ou na arvore de
  # acessibilidade) qual marca uma jogada na celula ia jogar. O JS assume
  # marcaAtual = "X" desde o inicio, entao a marcacao precisa concordar com
  # isso: exatamente um botao de marca com aria-pressed="true", e tem que
  # ser o X.
  def test_the_x_mark_starts_selected
    corpo = page_body(EN)
    marcas = corpo.scan(/<button[^>]*data-mark="([^"]+)"[^>]*aria-pressed="([^"]+)"/)

    refute_empty marcas, "nao encontrei botoes de marca com data-mark e aria-pressed"

    pressionadas = marcas.select { |_marca, estado| estado == "true" }
    assert_equal 1, pressionadas.size,
      "deveria haver exatamente um botao de marca com aria-pressed=\"true\" no estado inicial"
    assert_equal "X", pressionadas.first.first,
      "a marca selecionada no estado inicial deveria ser X, para bater com marcaAtual no JS"
  end

  # Le o FONTE, nao o bundle minificado. Procurar "49" no bundle passaria
  # sempre: numeros curtos aparecem em qualquer JavaScript minificado, e o
  # teste ficaria verde mesmo com o mapa de teclas errado.
  def test_the_key_codes_are_the_ones_js_dos_expects
    fonte = ROOT.join("frontend/javascript/jsdos-keypad.js").read

    # Constantes KBD_* do js-dos: ASCII maiusculo para letras e digitos,
    # codigos proprios acima de 256 para teclas especiais.
    {
      "X" => 88, "C" => 67, "S" => 83,
      "1" => 49, "2" => 50, "3" => 51,
      "enter" => 257,
    }.each do |tecla, codigo|
      assert_match(/#{Regexp.escape(tecla)}:\s*#{codigo}\b/, fonte,
        "o mapa de teclas deveria associar #{tecla} ao codigo #{codigo} do js-dos")
    end
  end
end
