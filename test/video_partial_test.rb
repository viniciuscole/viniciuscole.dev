require "test_helper"

class VideoPartialTest < Minitest::Test
  include OutputHelpers

  EN = "projects/3d-graphics/index.html".freeze
  PT = "pt/projects/3d-graphics/index.html".freeze
  BASE = "/demos/3d-graphics/jogo3d".freeze

  # Os tres arquivos que a gravacao precisa produzir. O partial checa a
  # mesma coisa em tempo de build (File.exist? sobre
  # resource.site.in_source_dir("#{base}.webm") etc, em _video.erb); aqui o
  # teste le o mesmo caminho so para decidir qual grupo de asserções vale
  # agora.
  MEDIA_FILES = %w[jogo3d.webm jogo3d.mp4 jogo3d.jpg].map do |nome|
    ROOT.join("src/demos/3d-graphics", nome)
  end.freeze

  def media_present?
    MEDIA_FILES.all?(&:file?)
  end

  def media_missing_message
    "aguardando a gravacao do video: falta(m) #{MEDIA_FILES.reject(&:file?).join(', ')}"
  end

  def test_the_project_page_renders_the_video_demo
    [EN, PT].each do |pagina|
      corpo = page_body(pagina)
      assert_includes corpo, 'class="demo demo-video"',
        "#{pagina} nao renderizou a demo de video"
      refute_includes corpo, 'class="demo demo-none"',
        "#{pagina} ainda mostra o placeholder"
    end
  end

  def test_the_section_hook_exists_regardless_of_the_media
    assert_includes page_body(EN), "data-video"
  end

  # t("demo.label") ("Playable demo"/"Demo jogavel") esta errado aqui: este
  # projeto e exatamente o que nao e jogavel. Quem navega por leitor de tela
  # nao pode ouvir essa afirmacao falsa na entrada do bloco -- por isso o
  # partial usa uma chave propria (demo.video.label) no aria-label da
  # secao, e nao a generica que wasm/jsdos usam.
  def test_the_aria_label_is_the_video_specific_one_not_the_generic_playable_one
    { "en" => EN, "pt" => PT }.each do |idioma, pagina|
      tabela = YAML.load_file(ROOT.join("src/_locales/#{idioma}.yml")).fetch(idioma)
      rotulo_video = tabela.dig("demo", "video", "label")
      rotulo_generico = tabela.dig("demo", "label")
      corpo = page_body(pagina)

      assert_includes corpo, "aria-label=\"#{rotulo_video}\"",
        "#{pagina} deveria anunciar a secao como #{rotulo_video.inspect}"
      refute_includes corpo, "aria-label=\"#{rotulo_generico}\"",
        "#{pagina} anuncia a secao de video como #{rotulo_generico.inspect}, que e falso aqui"
    end
  end

  # Este e o teste que garante a protecao pedida: o partial checa em disco,
  # nao so o front matter, se webm, mp4 e poster existem de verdade em
  # src/demos/3d-graphics/. Enquanto a gravacao nao chegar -- que e o estado
  # real do repositorio agora -- a pagina nunca aponta <source>/poster para
  # o vazio; ela mostra o aviso de indisponibilidade. O mesmo mecanismo
  # protege a pagina depois de publicada: se o arquivo for removido ou
  # renomeado, ela volta a degradar em vez de publicar um player quebrado.
  #
  # Roda de verdade enquanto a midia nao existir (o caso de hoje) e nao
  # depende de nada alem do proprio repositorio -- ao contrario dos testes
  # mais abaixo, que so fazem sentido depois que o arquivo chegar.
  def test_without_the_media_the_page_shows_the_unavailable_state_and_emits_no_source
    skip "midia ja existe em src/demos/3d-graphics/ -- nao ha estado de ausencia para testar" if media_present?

    [EN, PT].each do |pagina|
      corpo = page_body(pagina)

      assert_includes corpo, "data-video-unavailable",
        "#{pagina} deveria mostrar o aviso de gravacao indisponivel sem a midia"
      refute_includes corpo, "<source",
        "#{pagina} emitiu <source> apontando para um arquivo que nao existe"
      refute_includes corpo, "poster=",
        "#{pagina} emitiu poster apontando para um arquivo que nao existe"
      refute_includes corpo, "data-video-player",
        "#{pagina} emitiu o player de video sem a midia existir"
    end
  end

  def test_the_unavailable_message_reaches_both_locales_without_the_media
    skip "midia ja existe em src/demos/3d-graphics/ -- nao ha estado de ausencia para testar" if media_present?

    { "en" => EN, "pt" => PT }.each do |idioma, pagina|
      tabela = YAML.load_file(ROOT.join("src/_locales/#{idioma}.yml")).fetch(idioma)
      texto = tabela.dig("demo", "video", "unavailable")

      assert_includes page_body(pagina), texto,
        "a pagina de #{idioma} nao traz demo.video.unavailable (#{texto.inspect})"
    end
  end

  # "caption" carrega os dois fatos numa frase so (e gravacao; e o motivo de
  # nao rodar embutido) -- vale independente de a gravacao especifica estar
  # presente no momento do build, ao contrario de "weight" (peso do
  # download), que so faz sentido quando ha de fato algo para baixar.
  def test_the_caption_explains_the_video_choice_in_both_locales
    { "en" => EN, "pt" => PT }.each do |idioma, pagina|
      tabela = YAML.load_file(ROOT.join("src/_locales/#{idioma}.yml")).fetch(idioma)
      texto = tabela.dig("demo", "video", "caption")
      corpo = page_body(pagina)

      assert_includes corpo, texto,
        "a pagina de #{idioma} nao traz demo.video.caption (#{texto.inspect})"
    end
  end

  # A partir daqui, os testes so fazem sentido com a gravacao publicada em
  # src/demos/3d-graphics/ -- exercitam o ramo "midia existe" do partial, que
  # a arvore de hoje nao alcanca. Pulam com mensagem clara enquanto isso nao
  # acontecer, em vez de falhar por causa de um arquivo que sabidamente ainda
  # nao chegou.

  # preload="none": sem isto o video comecaria a baixar sozinho assim que a
  # pagina carrega -- exatamente o que o botao desligado das outras duas
  # demos existe para evitar, so que aqui quem garante isso e o atributo
  # nativo do <video>, sem JavaScript nenhum.
  def test_the_video_does_not_preload_once_the_media_exists
    skip media_missing_message unless media_present?

    assert_includes page_body(EN), 'preload="none"'
  end

  def test_the_sources_and_poster_point_at_the_front_matter_base_once_the_media_exists
    skip media_missing_message unless media_present?

    corpo = page_body(EN)
    assert_includes corpo, "src=\"#{BASE}.webm\""
    assert_includes corpo, "src=\"#{BASE}.mp4\""
    assert_includes corpo, "poster=\"#{BASE}.jpg\""
  end

  # webm antes de mp4: navegadores que suportam os dois usam o primeiro
  # <source> compativel que encontram, entao a ordem decide qual formato e
  # servido por padrao.
  def test_webm_is_offered_before_mp4_once_the_media_exists
    skip media_missing_message unless media_present?

    corpo = page_body(EN)
    posicao_webm = corpo.index("#{BASE}.webm")
    posicao_mp4 = corpo.index("#{BASE}.mp4")

    refute_nil posicao_webm, "faltou a fonte webm"
    refute_nil posicao_mp4, "faltou a fonte mp4"
    assert posicao_webm < posicao_mp4, "mp4 aparece antes de webm no HTML"
  end

  def test_the_player_hooks_exist_once_the_media_exists
    skip media_missing_message unless media_present?

    corpo = page_body(EN)
    %w[data-video data-video-player data-video-error].each do |gancho|
      assert_includes corpo, gancho, "faltou o gancho #{gancho}"
    end
  end

  def test_the_weight_key_reaches_the_page_once_the_media_exists
    skip media_missing_message unless media_present?

    { "en" => EN, "pt" => PT }.each do |idioma, pagina|
      tabela = YAML.load_file(ROOT.join("src/_locales/#{idioma}.yml")).fetch(idioma)
      texto = tabela.dig("demo", "video", "weight")

      assert_includes page_body(pagina), texto,
        "a pagina de #{idioma} nao traz demo.video.weight (#{texto.inspect})"
    end
  end

  # t("demo.failed") ("O emulador nao carregou"/"The emulator could not
  # load") foi escrita para o jogo DOS emulado em DOSBox e reusada aqui so
  # por ser a chave generica de falha -- mas esta pagina nao tem emulador
  # nenhum. Quem cai neste fallback (navegador que nao toca nem webm nem
  # mp4) merece uma explicacao verdadeira, nao a de outra demo.
  def test_the_native_fallback_uses_a_video_specific_failed_message_once_the_media_exists
    skip media_missing_message unless media_present?

    { "en" => EN, "pt" => PT }.each do |idioma, pagina|
      tabela = YAML.load_file(ROOT.join("src/_locales/#{idioma}.yml")).fetch(idioma)
      texto_video = tabela.dig("demo", "video", "failed")
      texto_generico = tabela.dig("demo", "failed")
      corpo = page_body(pagina)

      assert_includes corpo, texto_video,
        "a pagina de #{idioma} nao traz demo.video.failed (#{texto_video.inspect})"
      refute_includes corpo, texto_generico,
        "a pagina de #{idioma} ainda usa demo.failed (#{texto_generico.inspect}), que fala de emulador"
    end
  end
end
