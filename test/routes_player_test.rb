require "test_helper"

class RoutesPlayerTest < Minitest::Test
  include OutputHelpers

  def bundle
    corpo = page_body("projects/car-routes/index.html")
    src = corpo[/<script[^>]+src="([^"]+\.js)"/, 1]
    refute_nil src, "a pagina nao carrega o bundle"
    output(src.sub(%r{\A/}, "")).read
  end

  def test_the_bundle_mounts_the_routes_players
    %w[data-rotas data-rotas-canvas data-rotas-controles data-rotas-painel data-rotas-erro
       data-rotas-textos data-rotas-base data-rotas-estado data-rotas-caminho data-rotas-relogio
       data-rotas-aviso run_trace
       data-rotas-editor data-rotas-editor-form data-rotas-editor-lista data-rotas-editor-rodar
       data-rotas-editor-restaurar data-rotas-editor-erro].each do |gancho|
      assert_includes bundle, gancho, "o bundle nao referencia #{gancho}"
    end
  end
end
