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

  private

  # Links de navegacao para fora sao permitidos; o que nao pode e a pagina
  # *carregar* recurso de terceiro (script, folha de estilo, fonte, imagem).
  def allowed_external?(url)
    !url.match?(/\.(js|css|woff2?|ttf|png|jpe?g|svg|gif)(\?|$)/)
  end
end
