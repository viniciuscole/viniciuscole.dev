require "test_helper"

class CrtTest < Minitest::Test
  include OutputHelpers
  include ContrastHelpers

  def css
    ROOT.join("frontend/styles/crt.css").read
  end

  def test_the_crt_stylesheet_exists
    assert ROOT.join("frontend/styles/crt.css").file?
  end

  def test_every_class_the_demo_emits_has_styling
    %w[.demo-jsdos .demo-screen .demo-keypad
       .keypad-grid .keypad-marks .keypad-actions].each do |classe|
      assert_includes css, classe, "a classe #{classe} e emitida mas nao tem estilo"
    end
  end

  def test_it_reuses_the_palette_instead_of_inventing_colours
    assert_includes css, "var(--vga-", "o CRT deveria usar os tokens VGA existentes"
  end

  def test_animation_respects_reduced_motion
    assert_includes css, "prefers-reduced-motion",
      "o tratamento CRT precisa desligar animacao para quem pede menos movimento"
  end

  def test_the_stylesheet_is_imported
    assert_includes ROOT.join("frontend/styles/index.css").read, "crt.css"
  end

  # Guarda de contraste: le as cores de verdade dos arquivos de estilo (nao
  # valores copiados aqui) e calcula o contraste WCAG para os pares que o
  # CRT realmente desenha como texto sobre o fundo da pagina. Isto e o que
  # teria pego a regressao do brief: --vga-amber sozinho passa no tema claro
  # mas falha no escuro, e --crt-phosphor cru falha nos dois.

  def tokens_css
    ROOT.join("frontend/styles/tokens.css").read
  end

  # Extrai o valor de uma custom property de dentro do bloco de um seletor.
  # Funciona mesmo quando o seletor faz parte de uma lista (":root,\n:root[...]"),
  # pois so procura o texto do seletor seguido do bloco { ... }.
  def var_in_block(css_text, selector, var_name)
    block = css_text[/#{Regexp.escape(selector)}\s*\{(.*?)\}/m, 1]
    flunk "seletor #{selector} nao encontrado" unless block
    valor = block[/#{Regexp.escape(var_name)}:\s*(#[0-9a-fA-F]{6})/, 1]
    flunk "#{var_name} nao encontrado dentro de #{selector}" unless valor
    valor
  end

  def test_text_over_the_page_background_meets_aa_contrast_in_both_themes
    bg_light = var_in_block(tokens_css, ':root[data-theme="light"]', "--bg")
    bg_dark  = var_in_block(tokens_css, ':root[data-theme="dark"]', "--bg")
    accent_light = var_in_block(tokens_css, ':root[data-theme="light"]', "--accent")
    accent_dark  = var_in_block(tokens_css, ':root[data-theme="dark"]', "--accent")
    vga_amber    = var_in_block(tokens_css, ":root", "--vga-amber")
    crt_warn_dark = var_in_block(css, ':root[data-theme="dark"]', "--crt-warn")

    # .demo-instructions code e .demo-keypad button:hover/:focus-visible usam
    # --accent como cor de texto — o mesmo token que tokens.css ja calibrou.
    assert_operator contrast(accent_light, bg_light), :>=, 4.5,
      "--accent sobre --bg no tema claro precisa passar AA (4.5:1)"
    assert_operator contrast(accent_dark, bg_dark), :>=, 4.5,
      "--accent sobre --bg no tema escuro precisa passar AA (4.5:1)"

    # .demo-error usa --vga-amber no tema claro (ja suficiente) e --crt-warn
    # no escuro, onde --vga-amber sozinho fica abaixo de AA.
    assert_operator contrast(vga_amber, bg_light), :>=, 4.5,
      "--vga-amber sobre --bg no tema claro precisa passar AA (4.5:1)"
    assert_operator contrast(crt_warn_dark, bg_dark), :>=, 4.5,
      "--crt-warn sobre --bg no tema escuro precisa passar AA (4.5:1)"
  end

  def test_raw_vga_tokens_still_pass_aa_on_the_black_crt_backdrop
    # .demo-start e o aria-pressed do teclado usam --crt-phosphor (verde VGA
    # cru) como texto, mas so porque sempre estao sobre um fundo preto solido
    # (.demo-frame / aria-pressed background). Este teste documenta por que
    # isso e seguro, para que ninguem mova esse padrao para fora do preto sem
    # perceber que a conta muda.
    vga_green = var_in_block(tokens_css, ":root", "--vga-green")
    assert_operator contrast(vga_green, "#000000"), :>=, 4.5,
      "--vga-green sobre preto precisa continuar passando AA"
  end

  # A conta acima so vale se as regras realmente usarem esses tokens. Este
  # teste liga a matematica ao CSS declarado, para que reintroduzir
  # --crt-phosphor cru como cor de texto fora do preto quebre a suite.

  def rule_body(selector_pattern)
    body = css[/#{selector_pattern}\s*\{(.*?)\}/m, 1]
    flunk "regra #{selector_pattern} nao encontrada em crt.css" unless body
    body
  end

  # .demo-instructions code e .demo-error migraram para demo.css na Task 8
  # (viraram casco comum as duas demos); as mesmas asserções sobre eles
  # vivem agora em demo_styles_test.rb. Aqui fica so o que continua sendo
  # de fato CRT.
  def test_previously_broken_rules_now_use_the_aa_safe_tokens
    keypad_hover = rule_body(
      '\.demo-keypad button:hover,\s*\.demo-keypad button:focus-visible'
    )
    assert_match(/color:\s*var\(--accent\)/, keypad_hover,
      "hover/focus do teclado deveria usar --accent, nao --crt-phosphor cru")
  end

  # Estas classes sao do js-dos, nao nossas: elas vem no HTML que ele monta
  # dentro de .demo-screen. Como o js-dos.css deixou de ser servido (118 KB
  # que comecam com o Preflight do Tailwind), sao estas regras que seguram o
  # layout — e o canvas e dimensionado em JS a partir de
  # parentElement.getBoundingClientRect(), entao sem elas a caixa mede zero.
  def test_the_kiosk_layout_rules_the_emulator_needs_are_here
    %w[.absolute .relative .w-full .h-full .flex .flex-col .flex-row
       .flex-grow .overflow-hidden .bg-black].each do |classe|
      assert_match(/\.demo-screen\s+#{Regexp.escape(classe)}\b/, css,
        "falta a regra escopada para #{classe}, usada pela arvore do js-dos " \
        "em modo kiosk; sem ela o canvas nao tem caixa para medir")
    end
  end

  # A raiz do js-dos se posiciona em absolute dentro da moldura.
  def test_the_screen_is_a_containing_block_outside_any_media_query
    fora_de_media = css.split("@media").first
    blocos = fora_de_media.scan(/\.demo-screen\s*\{(.*?)\}/m).flatten
    refute_empty blocos, "nao encontrei nenhuma regra de .demo-screen"

    assert blocos.any? { |bloco| bloco =~ /position:\s*relative/ },
      ".demo-screen precisa ser containing block sempre — a arvore do js-dos " \
      "se posiciona em absolute dentro dela. Estava so dentro do bloco de " \
      "prefers-reduced-motion, que nem todo visitante ativa."
  end

  # A moldura da demo tem `display: flex`, e regra de autor ganha do
  # `[hidden]{display:none}` da folha do agente do usuario com qualquer
  # especificidade — entao `moldura.hidden = true` nao escondia nada: depois
  # do boot o retangulo preto com o botao Jogar ja inerte continuava por cima
  # do emulador, e no caminho de erro por cima da mensagem. A regra vale para
  # o site inteiro, entao mora em base.css.
  def test_hidden_wins_over_our_own_display_rules
    base = ROOT.join("frontend/styles/base.css").read
    assert_match(/\[hidden\]\s*\{[^}]*display:\s*none\s*!important/, base,
      "base.css precisa de [hidden] { display: none !important }, senao o " \
      "display: flex de .demo-frame mantem a moldura na tela depois do boot")

    publicado = Dir.glob(OUTPUT.join("_bridgetown/static/*.css"))
                   .map { |arquivo| File.read(arquivo) }.join
    refute_empty publicado, "nenhum CSS publicado"
    assert_match(/\[hidden\][^{]*\{[^}]*display:\s*none\s*!important/, publicado,
      "a regra existe no fonte mas nao chegou ao CSS publicado")
  end

  # Substitui um teste que guardava o `grid-column` da mensagem de erro no
  # layout de duas colunas. Aquele grid deixou de existir: com tudo empilhado,
  # a mensagem nao tem como se auto-posicionar ao lado do teclado, entao o
  # guarda-corpo perdeu o objeto. O que ficou no lugar e a decisao que motivou
  # a mudanca — a demo alinhada com o resto do conteudo.
  def test_the_demo_does_not_break_out_of_the_content_width
    regra = css[/\.demo-jsdos\s*\{([^}]*)\}/, 1].to_s

    refute_match(/margin-left:\s*calc\(\s*50%/, regra,
      "a demo voltou a escapar da largura da pagina; ela deve acompanhar o " \
      "resto do conteudo")
    refute_match(/^\s*width:/, regra,
      "largura fixa em .demo-jsdos tira a demo do fluxo da pagina")
  end

  # O espacamento vertical que empilha jogo, controles e comandos mudou de
  # casa: era `.demo-jsdos > * + *` aqui, e virou `.demo > * + *` em demo.css
  # quando o site ganhou uma segunda demo. Escopado por tipo, ele deixava a
  # demo nova sem folga nenhuma — a legenda encostava na tela do jogo.
  #
  # A intencao deste teste nao mudou (a demo do jogo DOS continua empilhada,
  # com espaco entre as partes); mudou so onde a regra mora. A cobranca fica
  # em demo.css, e `test_child_spacing_applies_to_both_demos`, em
  # demo_styles_test.rb, garante que ela nao volte a ser escopada por tipo.
  def test_the_demo_stacks_the_game_above_its_controls
    comum = ROOT.join("frontend/styles/demo.css").read

    assert_match(/\.demo\s*>\s*\*\s*\+\s*\*/, comum,
      "falta o espacamento vertical entre o jogo, os controles e os comandos")
  end
end
