require "test_helper"

class JsdosVendorTest < Minitest::Test
  include OutputHelpers

  VENDOR_FILES = %w[
    vendor/js-dos/js-dos.js
    vendor/js-dos/js-dos.css
    vendor/js-dos/emulators/wdosbox.js
    vendor/js-dos/emulators/wdosbox.wasm
  ].freeze

  def test_emulator_assets_are_published
    VENDOR_FILES.each do |path|
      assert output(path).file?,
        "faltou #{path} em output/ — a task jsdos:vendor rodou?"
    end
  end

  def test_the_wasm_is_the_real_emulator_not_a_stub
    wasm = output("vendor/js-dos/emulators/wdosbox.wasm")
    assert wasm.file?, "wdosbox.wasm nao foi publicado"
    assert wasm.size > 1_000_000,
      "wdosbox.wasm tem #{wasm.size} bytes; o emulador real passa de 1 MB"
  end

  def test_the_heavy_dosboxx_backend_is_not_shipped
    refute output("vendor/js-dos/emulators/wdosbox-x.wasm").exist?,
      "wdosbox-x.wasm (7,5 MB) foi publicado; o projeto usa o backend dosbox"
  end
end
