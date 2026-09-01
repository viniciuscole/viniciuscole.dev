require "test_helper"

class DemoStylesTest < Minitest::Test
  include OutputHelpers
  include ContrastHelpers
  include StylesheetHelpers

  def demo_css
    ROOT.join("frontend/styles/demo.css").read
  end

  def wasm_css
    ROOT.join("frontend/styles/wasm-demo.css").read
  end

  def video_css
    ROOT.join("frontend/styles/video-demo.css").read
  end

  def index_css
    ROOT.join("frontend/styles/index.css").read
  end

  # Lido aqui para cobrar que o espacamento entre filhos NAO volte a ser
  # escopado por tipo de demo dentro do crt.css.
  def crt_css
    ROOT.join("frontend/styles/crt.css").read
  end

  def test_the_shared_shell_is_imported
    assert_includes index_css, "demo.css"
    assert_includes index_css, "wasm-demo.css"
  end

  def test_the_shared_shell_owns_the_common_classes
    %w[.demo-frame .demo-start .demo-weight .demo-error
       .demo-instructions .demo-license].each do |classe|
      assert_includes demo_css, classe,
        "#{classe} e comum as duas demos e deveria viver em demo.css"
    end
  end

  def test_the_wasm_demo_has_its_own_styling
    %w[.demo-wasm .demo-over].each do |classe|
      assert_includes wasm_css, classe, "a classe #{classe} e emitida mas nao tem estilo"
    end
  end

  # O jogo nao trata resize e o enunciado fixa a janela em 500x500. Esticar
  # o canvas alem disso deformaria a arena.
  def test_the_canvas_is_capped_at_the_size_the_game_expects
    assert_includes wasm_css, "500px"
    assert_includes wasm_css, "aspect-ratio"
  end

  # A gravacao e 500x500 (1:1), e preload="none" significa que o navegador
  # so conhece as dimensoes reais do video depois que alguem da play. Sem
  # aspect-ratio declarado, o elemento nao tem tamanho intrinseco garantido
  # antes disso -- o bloco nasceria com uma altura e pularia para outra
  # quando o video carregasse, empurrando a legenda abaixo. Mesmo molde de
  # test_the_canvas_is_capped_at_the_size_the_game_expects, para o video em
  # vez do canvas.
  def test_the_video_reserves_its_space_before_play
    assert_includes video_css, "500px"
    assert_includes video_css, "aspect-ratio"
  end

  # Este jogo nao e CRT. Fosforo verde nele seria mentira estetica.
  def test_the_wasm_demo_does_not_borrow_the_crt_treatment
    refute_includes wasm_css, "--crt-phosphor"
    refute_includes wasm_css, "--vga-green"
  end

  # Guarda uma regressao que aconteceu de verdade: a regra que separa a tela do
  # jogo da legenda de controles vivia escopada em `.demo-jsdos`, e a demo wasm
  # nasceu sem equivalente — a legenda encostava na tela, sem folga.
  #
  # Nenhum teste desta suite mede espaco vertical, e nenhum vai: medir pixel
  # exigiria navegador. O que da para cobrar honestamente e que a regra exista
  # e alcance as duas demos, que e exatamente o que falhou. Um teste fraco que
  # pega a regressao real vale mais que nenhum.
  def test_child_spacing_applies_to_both_demos
    regra = demo_css[/\.demo\s*>\s*\*\s*\+\s*\*\s*\{([^}]*)\}/m, 1]
    refute_nil regra,
      "demo.css nao tem regra de espacamento entre os filhos da demo — sem " \
      "ela a legenda de controles encosta na tela do jogo"
    assert_match(/margin-top/, regra,
      "a regra de espacamento entre filhos nao define margin-top")

    # Escopada a um tipo so, ela deixa a outra demo sem espacamento: foi
    # assim que o defeito surgiu.
    refute_match(/\.demo-(jsdos|wasm)\s*>\s*\*\s*\+\s*\*/, demo_css,
      "o espacamento entre filhos nao pode ser escopado a um tipo de demo")
    refute_match(/\.demo-jsdos\s*>\s*\*\s*\+\s*\*/, crt_css,
      "crt.css voltou a escopar o espacamento entre filhos em .demo-jsdos")
  end

  # .demo-instructions e .demo-error saíram de crt.css nesta tarefa (viraram
  # casco comum), e levaram consigo a asserção que amarrava a regra ao token
  # AA-safe. Sem isto alguem poderia trocar --accent / --crt-warn de volta
  # por uma cor crua sem quebrar nada.
  def rule_body(selector_pattern)
    body = demo_css[/#{selector_pattern}\s*\{(.*?)\}/m, 1]
    flunk "regra #{selector_pattern} nao encontrada em demo.css" unless body
    body
  end

  def test_demo_instructions_code_uses_the_aa_safe_accent_token
    bloco = rule_body('\.demo-instructions code')
    assert_match(/color:\s*var\(--accent\)/, bloco,
      ".demo-instructions code deveria usar --accent, nao uma cor fixa")
  end

  def test_demo_error_uses_the_crt_warn_fallback_chain
    bloco = rule_body('\.demo-error')
    assert_match(/color:\s*var\(--crt-warn/, bloco,
      ".demo-error deveria usar --crt-warn (com fallback para --vga-amber)")
  end

  # Guarda de contraste, no molde de crt_test.rb. O overlay de fim de jogo
  # tem fundo preto proprio, entao suas cores sao fixas em vez de virem dos
  # tokens do tema -- e cor fixa e exatamente o que passa despercebido numa
  # revisao. Le os valores do arquivo, nao copiados aqui. `relative_luminance`
  # e `contrast` vem de ContrastHelpers (test_helper.rb), compartilhado com
  # crt_test.rb.
  def test_the_game_over_overlay_is_readable
    bloco = wasm_css[/\.demo-wasm\s+\.demo-over\s*\{(.*?)\}/m, 1]
    refute_nil bloco, "bloco .demo-wasm .demo-over nao encontrado"

    texto = bloco[/color:\s*(#[0-9a-fA-F]{6})/, 1]
    refute_nil texto, "a cor do texto do overlay nao foi encontrada"

    # O overlay cobre o canvas com preto a 78%; o pior caso de leitura e
    # sobre o preto puro do fundo do jogo.
    razao = contrast(texto, "#000000")
    assert razao >= 4.5,
      "o texto do overlay (#{texto}) tem contraste #{razao.round(2)}:1 sobre o " \
      "fundo escuro, abaixo do minimo 4.5:1 da WCAG para texto"
  end

  def test_the_restart_button_border_is_visible
    bloco = wasm_css[/\.demo-wasm\s+\.demo-over\s+button\s*\{(.*?)\}/m, 1]
    refute_nil bloco, "bloco do botao do overlay nao encontrado"

    borda = bloco[/border:\s*1px\s+solid\s+(#[0-9a-fA-F]{6})/, 1]
    refute_nil borda, "a cor da borda do botao nao foi encontrada"

    razao = contrast(borda, "#000000")
    assert razao >= 3.0,
      "a borda do botao (#{borda}) tem contraste #{razao.round(2)}:1, abaixo " \
      "do minimo 3:1 da WCAG para indicador nao textual"
  end

  # As folhas precisam chegar ao CSS publicado, nao so existir no fonte.
  # A build do esbuild ja publicou MISSING_ESBUILD_ASSET com a suite verde.
  def test_the_styles_reach_the_published_bundle
    assert_includes published_stylesheets, ".demo-wasm",
      "wasm-demo.css nao chegou ao bundle publicado"
  end
end
