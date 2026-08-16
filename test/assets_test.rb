require "test_helper"

class AssetsTest < Minitest::Test
  include OutputHelpers

  def test_no_external_requests_in_the_published_html
    Dir.glob(OUTPUT.join("**/*.html")).each do |path|
      body = File.read(path)
      offenders = body.scan(/(?:src|href)="(https?:\/\/[^"]+)"/).flatten
        .reject { |url| allowed_external?(url) }

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

  # Se o frontend nao foi compilado (ex.: esbuild falhou, ou rake check nao
  # rodou frontend:build antes de bin/bridgetown build), Bridgetown emite o
  # placeholder "MISSING_ESBUILD_ASSET" em vez de um caminho real de asset.
  # Isso publicaria um site sem CSS e sem JS silenciosamente.
  def test_pages_reference_the_compiled_frontend_assets
    Dir.glob(OUTPUT.join("**/*.html")).each do |path|
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

  # Links de navegacao para fora sao permitidos; o que nao pode e a pagina
  # *carregar* recurso de terceiro (script, folha de estilo, fonte, imagem).
  def allowed_external?(url)
    !url.match?(/\.(js|css|woff2?|ttf|png|jpe?g|svg|gif)(\?|$)/)
  end
end
