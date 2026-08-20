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
      "enter" => 257, "shift" => 340,
    }.each do |tecla, codigo|
      assert_match(/#{Regexp.escape(tecla)}:\s*#{codigo}\b/, fonte,
        "o mapa de teclas deveria associar #{tecla} ao codigo #{codigo} do js-dos")
    end
  end

  # O codigo do modulo sem os comentarios. Os testes abaixo procuram chamadas
  # de verdade: sem isto, um comentario explicando o bug ("simulateKeyPress(a,
  # b, c) engole a tecla repetida") reprovaria o arquivo que ja esta certo.
  def codigo_do_teclado
    ROOT.join("frontend/javascript/jsdos-keypad.js")
        .read
        .lines
        .map { |linha| linha.sub(%r{//.*$}, "") }
        .join
  end

  # O ci.simulateKeyPress(a, b, c) do js-dos pressiona todos os argumentos no
  # mesmo timestamp, e o addKey interno so emite quando o estado da tecla muda
  # — o segundo digito repetido de X11 e engolido. Uma tecla por chamada e o
  # que faz 11, 22 e 33 (a diagonal principal, com o C22 do painel) chegarem
  # ao jogo.
  def test_no_key_press_carries_more_than_one_key
    fonte = codigo_do_teclado

    chamadas = fonte.scan(/simulateKeyPress\(([^)]*)\)/)
    refute_empty chamadas, "nao encontrei nenhuma chamada a simulateKeyPress"

    chamadas.each do |(argumentos)|
      refute_includes argumentos, ",",
        "simulateKeyPress(#{argumentos}) manda mais de uma tecla na mesma " \
        "chamada; o addKey do js-dos engole a segunda ocorrencia de um digito " \
        "repetido e 11/22/33 ficam injogaveis"
    end
  end

  # O VCA.EXE compara o comando com 'X' (0x58) e 'C' (0x43) maiusculos, e um
  # codigo de tecla nao carrega caixa: sem KBD_leftshift a jogada de circulo
  # manda 'c', que e o comando de reiniciar.
  def test_the_mark_is_typed_with_shift_held
    fonte = codigo_do_teclado

    assert_match(/sendKeyEvent\(\s*TECLAS\.shift\s*,\s*true\s*\)/, fonte,
      "a marca da jogada precisa ser digitada com shift pressionado")
    assert_match(/sendKeyEvent\(\s*TECLAS\.shift\s*,\s*false\s*\)/, fonte,
      "o shift precisa ser solto depois da marca, senao os digitos saem shiftados")
  end

  # 'c' (reiniciar) e 's' (sair) o jogo compara em minusculo. Se o shift
  # vazasse para essas duas, os botoes de acao parariam de funcionar.
  def test_restart_and_quit_are_not_shifted
    fonte = codigo_do_teclado

    trecho = fonte[/\[data-action\].*\z/m]
    refute_nil trecho, "nao encontrei o bloco que liga os botoes de acao"

    refute_match(/shift|maiuscul/i, trecho,
      "os botoes de reiniciar e sair mandam 'c' e 's' em minusculo; shift ali " \
      "(direto ou via a rotina que digita maiusculas) quebraria os dois")
    assert_match(/digitar\(ci,/, trecho,
      "os botoes de acao deveriam digitar direto, sem passar pelo caminho " \
      "que segura o shift")
  end

  # Um segundo ci-ready religaria todos os botoes e cada clique mandaria o
  # comando duas vezes.
  def test_mounting_twice_is_a_no_op
    fonte = codigo_do_teclado

    assert_match(/dataset\.montado/, fonte,
      "montarTeclado precisa de guarda de idempotencia contra um segundo ci-ready")
  end
end
