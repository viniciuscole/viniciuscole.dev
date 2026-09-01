require "test_helper"

class VideoPartialTest < Minitest::Test
  include OutputHelpers

  EN = "projects/3d-graphics/index.html".freeze
  PT = "pt/projects/3d-graphics/index.html".freeze
  BASE = "/demos/3d-graphics/jogo3d".freeze

  def test_the_project_page_renders_the_video_demo
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, 'class="demo demo-video"',
        "#{pagina} nao renderizou a demo de video"
      refute_includes corpo, 'class="demo demo-none"',
        "#{pagina} ainda mostra o placeholder"
    end
  end

  def test_the_hooks_the_page_depends_on_exist
    corpo = page_body(EN)
    %w[data-video data-video-player data-video-error].each do |gancho|
      assert_includes corpo, gancho, "faltou o gancho #{gancho}"
    end
  end

  # preload="none": sem isto o video comecaria a baixar sozinho assim que a
  # pagina carrega -- exatamente o que o botao desligado das outras duas
  # demos existe para evitar, so que aqui quem garante isso e o atributo
  # nativo do <video>, sem JavaScript nenhum.
  def test_the_video_does_not_preload
    assert_includes page_body(EN), 'preload="none"'
  end

  def test_the_sources_and_poster_point_at_the_front_matter_base
    corpo = page_body(EN)
    assert_includes corpo, "src=\"#{BASE}.webm\""
    assert_includes corpo, "src=\"#{BASE}.mp4\""
    assert_includes corpo, "poster=\"#{BASE}.jpg\""
  end

  # webm antes de mp4: navegadores que suportam os dois usam o primeiro
  # <source> compativel que encontram, entao a ordem decide qual formato e
  # servido por padrao.
  def test_webm_is_offered_before_mp4
    corpo = page_body(EN)
    posicao_webm = corpo.index("#{BASE}.webm")
    posicao_mp4 = corpo.index("#{BASE}.mp4")

    refute_nil posicao_webm, "faltou a fonte webm"
    refute_nil posicao_mp4, "faltou a fonte mp4"
    assert posicao_webm < posicao_mp4, "mp4 aparece antes de webm no HTML"
  end

  # Le o texto direto das tabelas de idioma (mesmo padrao de
  # wasm_partial_test.rb#test_the_legend_names_the_mouse_buttons_in_both_locales)
  # para cobrar que a informacao chegue a pagina, nao qual e a redacao dela.
  def test_the_video_keys_reach_the_page_in_both_locales
    { "en" => EN, "pt" => PT }.each do |idioma, pagina|
      tabela = YAML.load_file(ROOT.join("src/_locales/#{idioma}.yml")).fetch(idioma)
      video = tabela.dig("demo", "video")
      corpo = page_body(pagina)

      %w[weight why caption].each do |chave|
        texto = video.fetch(chave)
        assert_includes corpo, texto,
          "a pagina de #{idioma} nao traz demo.video.#{chave} (#{texto.inspect})"
      end
    end
  end

  # A gravacao ainda nao existe -- o dono do site vai captura-la depois desta
  # tarefa. Falhar aqui por causa de um arquivo que sabidamente ainda nao
  # chegou seria ruido, entao o teste pula com uma mensagem que diz
  # exatamente o que falta. Assim que os tres arquivos existirem em
  # src/demos/3d-graphics/, ele passa a exercitar de verdade (tamanho > 0,
  # e nao arquivo vazio ou corrompido).
  def test_the_recorded_media_exists_once_it_is_captured
    diretorio = ROOT.join("src/demos/3d-graphics")
    arquivos = %w[jogo3d.webm jogo3d.mp4 jogo3d.jpg].map { |nome| diretorio.join(nome) }
    faltando = arquivos.reject(&:file?)

    skip "aguardando a gravacao do video: falta(m) #{faltando.join(', ')}" if faltando.any?

    arquivos.each do |arquivo|
      assert arquivo.size > 0, "#{arquivo} existe mas esta vazio"
    end
  end
end
