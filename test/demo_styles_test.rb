require "test_helper"

class DemoStylesTest < Minitest::Test
  include OutputHelpers

  def demo_css
    ROOT.join("frontend/styles/demo.css").read
  end

  def wasm_css
    ROOT.join("frontend/styles/wasm-demo.css").read
  end

  def index_css
    ROOT.join("frontend/styles/index.css").read
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

  # Este jogo nao e CRT. Fosforo verde nele seria mentira estetica.
  def test_the_wasm_demo_does_not_borrow_the_crt_treatment
    refute_includes wasm_css, "--crt-phosphor"
    refute_includes wasm_css, "--vga-green"
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
  # revisao. Le os valores do arquivo, nao copiados aqui.
  def relative_luminance(hex)
    r, g, b = hex.delete("#").scan(/../).map { |c| c.to_i(16) / 255.0 }
    r, g, b = [r, g, b].map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
    (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
  end

  def contrast(a, b)
    la = relative_luminance(a)
    lb = relative_luminance(b)
    claro, escuro = [la, lb].max, [la, lb].min
    (claro + 0.05) / (escuro + 0.05)
  end

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

  # Deriva a(s) folha(s) publicada(s) do(s) <link> da propria pagina, em vez
  # de pegar a primeira de um glob. Builds anteriores deixam CSS antigo em
  # output/, e o glob pegaria um arquivo que ninguem serve -- o teste
  # passaria mesmo que o CSS atual nao tivesse chegado ao bundle, que e
  # justamente o que ele existe para pegar.
  def published_stylesheets
    corpo = page_body("projects/2d-graphics/index.html")
    hrefs = corpo.scan(/<link[^>]+rel="stylesheet"[^>]+href="([^"]+\.css)"/).flatten
    refute_empty hrefs, "a pagina nao linka nenhuma folha de estilo"

    hrefs.map do |href|
      caminho = OUTPUT.join(href.sub(%r{\A/}, ""))
      assert caminho.file?, "a pagina linka #{href}, que nao existe em output/"
      caminho.read
    end.join
  end

  # As folhas precisam chegar ao CSS publicado, nao so existir no fonte.
  # A build do esbuild ja publicou MISSING_ESBUILD_ASSET com a suite verde.
  def test_the_styles_reach_the_published_bundle
    assert_includes published_stylesheets, ".demo-wasm",
      "wasm-demo.css nao chegou ao bundle publicado"
  end
end
