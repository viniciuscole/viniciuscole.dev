require "test_helper"

class RoutesArtifactsTest < Minitest::Test
  include OutputHelpers

  BASE = "demos/car-routes".freeze
  MINIMO_WASM = 20_000
  MINIMO_JS   = 8_000

  def test_the_two_artefacts_are_versioned_in_the_repository
    %w[rotas.js rotas.wasm].each do |nome|
      assert ROOT.join("src", BASE, nome).file?, "faltou src/#{BASE}/#{nome} — rode `rake routes:build`"
    end
  end

  def test_the_two_artefacts_are_published
    %w[rotas.js rotas.wasm].each do |nome|
      assert output("#{BASE}/#{nome}").file?, "#{nome} existe em src/ mas nao chegou em output/"
    end
  end

  def test_the_artefacts_are_not_truncated
    assert_operator output("#{BASE}/rotas.wasm").size, :>=, MINIMO_WASM
    assert_operator output("#{BASE}/rotas.js").size, :>=, MINIMO_JS
  end

  def test_the_loader_exports_run_trace
    js = output("#{BASE}/rotas.js").read
    assert_includes js, "criarRotas", "o loader nao define a factory criarRotas"
    assert_includes js, "_run_trace", "run_trace nao foi exportada"
  end
end
