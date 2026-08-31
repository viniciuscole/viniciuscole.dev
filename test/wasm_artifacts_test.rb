require "test_helper"

# Guarda direto contra o defeito da Fase 2, onde a vendorizacao esqueceu tres
# arquivos e a demo nao bootava com a suite inteira verde. Aqui os tres
# artefatos sao verificados no fonte E no output: o build do site copia
# src/demos/ para output/, e ja aconteceu de a suite passar sobre um output
# que nao tinha o que a pagina pede.
class WasmArtifactsTest < Minitest::Test
  include OutputHelpers

  BASE = "demos/2d-graphics".freeze

  # Tamanhos minimos, nao exatos: o .wasm muda de tamanho a cada patch, e um
  # numero exato viraria churn a cada tarefa deste plano. O que estes pisos
  # pegam e o caso que importa — artefato ausente, vazio ou truncado.
  MINIMO_WASM = 150_000
  MINIMO_JS   = 100_000
  MINIMO_DATA = 2_000

  def test_the_three_artefacts_are_versioned_in_the_repository
    %w[jogo.js jogo.wasm jogo.data].each do |nome|
      caminho = ROOT.join("src", BASE, nome)
      assert caminho.file?, "faltou src/#{BASE}/#{nome} — rode `rake demo2d:build`"
    end
  end

  def test_the_three_artefacts_are_published
    %w[jogo.js jogo.wasm jogo.data].each do |nome|
      assert output("#{BASE}/#{nome}").file?,
        "#{nome} existe em src/ mas nao chegou em output/"
    end
  end

  def test_the_wasm_is_a_real_webassembly_module
    conteudo = ROOT.join("src", BASE, "jogo.wasm").binread(4)
    assert_equal "\x00asm".b, conteudo,
      "jogo.wasm nao comeca com a assinatura \\0asm de modulo WebAssembly"
  end

  def test_the_artefacts_are_not_truncated
    {
      "jogo.wasm" => MINIMO_WASM,
      "jogo.js"   => MINIMO_JS,
      "jogo.data" => MINIMO_DATA,
    }.each do |nome, minimo|
      tamanho = ROOT.join("src", BASE, nome).size
      assert tamanho >= minimo,
        "#{nome} tem #{tamanho} bytes, esperava ao menos #{minimo}. " \
        "Artefato truncado ou build incompleta."
    end
  end

  # MODULARIZE e o que permite carregar sob clique. Sem ele o modulo sobe
  # sozinho ao carregar o script e a demo comeca antes de alguem pedir.
  def test_the_module_is_a_factory_named_criarJogo2D
    js = ROOT.join("src", BASE, "jogo.js").read
    assert_includes js, "criarJogo2D",
      "jogo.js nao expoe a factory criarJogo2D — faltou -sMODULARIZE/-sEXPORT_NAME"
  end
end
