require "test_helper"

class AssetsTest < Minitest::Test
  include OutputHelpers

  # `rel` de <link> que sao ponteiro, nao download: apontam para outro
  # documento sem o browser buscar nada por conta propria. Todo o resto
  # (stylesheet, icon, preload, preconnect, dns-prefetch, modulepreload,
  # prefetch...) e carregamento e cai na regra.
  NON_LOADING_LINK_RELS = %w[canonical alternate me author license prev next].freeze

  # A regra e "zero requisicoes a terceiros no site publicado". Quem decide se
  # uma URL e carregamento e o *contexto do elemento*, nunca a extensao do
  # arquivo: a violacao canonica,
  # https://fonts.googleapis.com/css2?family=Inter, nao tem ".css" nenhum na
  # URL — a versao anterior deste teste, que filtrava por extensao, deixava
  # passar ela, todo CDN com URL sem extensao e todo script de analytics.
  #
  # Link de navegacao continua permitido: o footer aponta para GitHub e
  # LinkedIn de proposito.
  def test_no_external_requests_in_the_published_html
    html_pages.each do |path|
      offenders = external_loads(File.read(path))

      assert_empty offenders,
        "#{path}: recurso externo carregado pela pagina: #{offenders.join(', ')}"
    end
  end

  def test_theme_tokens_are_defined
    css = ROOT.join("frontend/styles/tokens.css").read
    %w[--bg --fg --muted --accent --border --font-mono --font-body].each do |token|
      assert_includes css, token, "token #{token} nao definido"
    end
  end

  # O projeto nao hospeda nenhum arquivo de fonte. Nomear uma fonte que so
  # existe na maquina de quem a instalou faz o site renderizar diferente para
  # esse visitante — e some para todos os outros.
  def test_font_stacks_only_name_fonts_the_site_can_actually_serve
    css = ROOT.join("frontend/styles/tokens.css").read
    %w[--font-mono --font-body].each do |token|
      stack = css[/#{token}:([^;]*);/m, 1].to_s
      refute_empty stack, "token #{token} nao definido"

      named = stack.scan(/"([^"]+)"/).flatten
      unhosted = named - system_font_families
      assert_empty unhosted,
        "#{token} nomeia fonte que o site nao hospeda: #{unhosted.join(', ')}"
    end
    assert_includes css, "ui-monospace", "pilha monoespacada do sistema ausente"
  end

  # Se o frontend nao foi compilado (ex.: esbuild falhou, ou rake check nao
  # rodou frontend:build antes de bin/bridgetown build), Bridgetown emite o
  # placeholder "MISSING_ESBUILD_ASSET" em vez de um caminho real de asset.
  # Isso publicaria um site sem CSS e sem JS silenciosamente.
  def test_pages_reference_the_compiled_frontend_assets
    html_pages.each do |path|
      body = File.read(path)

      refute_includes body, "MISSING_ESBUILD_ASSET",
        "#{path}: referencia a um asset de frontend que nao foi compilado"

      stylesheet = body[/<link rel="stylesheet" href="([^"]+)"/, 1]
      script = body[/<script src="([^"]+)"/, 1]

      assert stylesheet, "#{path}: nenhuma folha de estilo referenciada"
      assert script, "#{path}: nenhum script referenciado"

      assert_match %r{\A/_bridgetown/static/}, stylesheet,
        "#{path}: folha de estilo nao aponta para /_bridgetown/static/: #{stylesheet}"
      assert_match %r{\A/_bridgetown/static/}, script,
        "#{path}: script nao aponta para /_bridgetown/static/: #{script}"
    end
  end

  private

  # Fontes que ja vem com o sistema operacional — nomea-las nao pede download
  # nenhum. Qualquer outro nome entre aspas na pilha e uma fonte que o site
  # nao serve: ela aparece so para quem tiver instalado.
  def system_font_families
    ["Segoe UI", "Helvetica Neue"]
  end

  def external_loads(body)
    # src= em qualquer elemento (script, img, iframe, video, audio...) e
    # sempre carregamento.
    from_src = body.scan(/<[a-zA-Z][^>]*?\ssrc="(https?:\/\/[^"]*)"/).flatten

    # href= so e carregamento dentro de <link> — e nem sempre, ver
    # NON_LOADING_LINK_RELS. Em <a> e navegacao.
    from_link = body.scan(/<link\b([^>]*)>/).flatten.filter_map do |attrs|
      href = attrs[/\shref="(https?:\/\/[^"]*)"/, 1]
      next if href.nil?

      rels = attrs[/\srel="([^"]*)"/, 1].to_s.split
      next if rels.intersect?(NON_LOADING_LINK_RELS)

      href
    end

    (from_src + from_link).uniq
  end
end
