require "test_helper"

class JsdosVendorTest < Minitest::Test
  include OutputHelpers

  VENDOR_FILES = %w[
    vendor/js-dos/js-dos.js
    vendor/js-dos/emulators/emulators.js
    vendor/js-dos/emulators/wdosbox.js
    vendor/js-dos/emulators/wdosbox.wasm
    vendor/js-dos/emulators/wlibzip.js
    vendor/js-dos/emulators/wlibzip.wasm
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

  # O js-dos.css abre com o Preflight do Tailwind e com a base do daisyUI:
  # seletores de elemento (h1..h6, a, *, html, body) e :root/[data-theme].
  # Servido depois da nossa folha, com a mesma especificidade, ele achatava
  # todo titulo e tirava cor e sublinhado de todo link do site no clique em
  # Jogar. Este teste varre TODO CSS publicado — nao so o do js-dos — porque
  # o estrago e o mesmo se alguem colar essas regras na nossa folha.
  PREFLIGHT = [
    [/h1\s*,\s*h2\s*,\s*h3\s*,\s*h4\s*,\s*h5\s*,\s*h6\s*\{[^}]*font-size:\s*inherit/,
     "o reset achata todo titulo do site para o tamanho do corpo"],
    [/(?<![\w.#\-\[])a\s*\{[^}]*text-decoration:\s*inherit/,
     "o reset tira sublinhado e cor de todo link do site"],
  ].freeze

  def published_stylesheets
    folhas = Dir.glob(OUTPUT.join("**/*.css"))
    refute_empty folhas, "nenhum CSS em output/ — o site nao foi construido"
    folhas
  end

  def test_no_published_stylesheet_carries_the_tailwind_preflight
    published_stylesheets.each do |arquivo|
      conteudo = File.read(arquivo)
      PREFLIGHT.each do |padrao, estrago|
        refute_match padrao, conteudo,
          "#{arquivo.sub(OUTPUT.to_s, "output")} traz o Preflight: #{estrago}"
      end
    end
  end

  def test_the_third_party_stylesheet_is_not_published_at_all
    refute output("vendor/js-dos/js-dos.css").exist?,
      "js-dos.css voltou a ser publicado; sao 118 KB de reset global que o " \
      "modo kiosk nao precisa (as regras usadas estao em crt.css)"
  end
end
