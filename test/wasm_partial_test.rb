require "test_helper"

class WasmPartialTest < Minitest::Test
  include OutputHelpers

  EN = "projects/2d-graphics/index.html".freeze
  PT = "pt/projects/2d-graphics/index.html".freeze

  def test_the_project_page_renders_the_wasm_demo
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, 'class="demo demo-wasm"',
        "#{pagina} nao renderizou a demo wasm"
      refute_includes corpo, 'class="demo demo-none"',
        "#{pagina} ainda mostra o placeholder"
    end
  end

  def test_the_demo_points_at_the_artefacts
    assert_includes page_body(EN), 'data-wasm-base="/demos/2d-graphics/jogo"'
  end

  def test_the_hooks_the_player_depends_on_exist
    corpo = page_body(EN)
    %w[data-wasm data-wasm-base data-wasm-frame data-wasm-start
       data-wasm-screen data-wasm-canvas data-wasm-error
       data-wasm-over data-wasm-over-message data-wasm-restart].each do |gancho|
      assert_includes corpo, gancho, "faltou o gancho #{gancho}"
    end
  end

  # A janela e 500x500 por exigencia do enunciado do trabalho ("a janela de
  # visualizacao sera quadrada ... exibida em uma janela de 500x500 pixel").
  # Nao e preferencia visual, e conformidade com a especificacao avaliada.
  def test_the_canvas_keeps_the_size_the_assignment_requires
    corpo = page_body(EN)
    assert_includes corpo, 'width="500"'
    assert_includes corpo, 'height="500"'
  end

  # As teclas n, t, l, virgula e ponto sao roteiro de apresentacao para a
  # banca, nao controles de jogo. Foi decidido nao expo-las.
  #
  # Varre a pagina inteira, nao um bloco isolado por regex: isolar
  # `<div class="demo-instructions">.*?</div>` com regex nao-gulosa parava no
  # primeiro `</div>` interno, entao envolver a lista numa div para estilizar
  # faria o teste passar a ignorar o resto do bloco silenciosamente. Checar a
  # pagina toda expressa a decisao real ("nao expor em lugar nenhum") sem
  # depender da estrutura HTML.
  def test_the_presentation_shortcuts_are_not_documented_on_the_page
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)

      ["<code>N</code>", "<code>T</code>", "<code>L</code>",
       "<code>,</code>", "<code>.</code>"].each do |tecla|
        refute_includes corpo, tecla,
          "#{pagina} expoe #{tecla}, que e atalho de apresentacao e nao controle"
      end
    end
  end

  # A decisao do dono do site foi nao ter controles na tela nem detectar toque,
  # justamente porque a legenda carregaria essa informacao. Sem este teste,
  # uma edicao em qualquer uma das tres chaves do item de pulo faria a legenda
  # parar de nomear os botoes do mouse sem nada acusar -- que foi exatamente o
  # defeito corrigido aqui. Le o texto direto das tabelas de idioma (mesmo
  # padrao de test/layout_test.rb#test_footer_shows_the_contact_links) para
  # cobrar que a informacao chegue a pagina, nao qual e a redacao dela.
  def test_the_legend_names_the_mouse_buttons_in_both_locales
    { "en" => EN, "pt" => PT }.each do |idioma, pagina|
      tabela = YAML.load_file(ROOT.join("src/_locales/#{idioma}.yml")).fetch(idioma)
      controles = tabela.dig("demo", "wasm", "controls")
      corpo = page_body(pagina)

      %w[jump_mouse shoot aim].each do |chave|
        texto = controles.fetch(chave)
        assert_includes corpo, texto,
          "a legenda de #{idioma} nao traz #{chave} (#{texto.inspect}) — " \
          "o visitante fica sem saber qual botao do mouse usar"
      end
    end
  end

  def test_the_page_credits_the_vendored_parser
    assert_includes page_body(EN), "tinyxml2"
  end
end
