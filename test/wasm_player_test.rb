require "test_helper"

class WasmPlayerTest < Minitest::Test
  include OutputHelpers

  def js
    ROOT.join("frontend/javascript/wasm-player.js").read
  end

  def test_the_player_exists_and_is_imported
    assert ROOT.join("frontend/javascript/wasm-player.js").file?
    assert_includes ROOT.join("frontend/javascript/index.js").read, "wasm-player"
  end

  # Cada gancho que o partial emite precisa ser lido por alguem. Um data-*
  # renomeado so de um lado nao quebra o build nem o HTML: a demo apenas
  # deixa de funcionar em silencio.
  def test_the_player_reads_every_hook_the_partial_emits
    corpo = page_body("projects/2d-graphics/index.html")
    ganchos = corpo.scan(/data-wasm-[a-z-]+/).uniq

    ganchos.each do |gancho|
      # o dataset em JS usa camelCase; o seletor usa o nome cru
      assert_includes js, gancho, "o player nao le o gancho #{gancho}"
    end
  end

  # O botao direito pula (exigencia do enunciado). Sem cancelar o
  # contextmenu, cada pulo abre o menu do navegador em cima do jogo.
  def test_the_player_suppresses_the_context_menu
    assert_includes js, "contextmenu"
    assert_includes js, "preventDefault"
  end

  # O C++ chama fim() a cada quadro enquanto o jogo esta acabado.
  def test_the_game_over_handler_is_idempotent
    assert_includes js, "!fim.hidden",
      "fim() precisa sair cedo quando o overlay ja esta visivel"
  end

  # Reiniciar via funcao exportada, nao via KeyboardEvent sintetico.
  def test_restart_calls_the_exported_function
    assert_includes js, 'ccall("reiniciarDoNavegador"'
    refute_includes js, "KeyboardEvent",
      "o reinicio nao deve depender de evento de teclado sintetico"
  end

  def test_nothing_is_downloaded_before_the_click
    assert_includes js, 'addEventListener("click"',
      "a demo tem que carregar sob clique"
  end
end
