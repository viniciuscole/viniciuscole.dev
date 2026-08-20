require "test_helper"

class JsdosVendorTest < Minitest::Test
  include OutputHelpers

  VENDOR_FILES = %w[
    vendor/js-dos/js-dos.js
    vendor/js-dos/LICENSE.txt
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

  # Servir o wdosbox.wasm da nossa origem e distribuir uma obra GPL-2.0. O
  # pacote npm nao traz o texto da licenca, entao ele e versionado aqui e
  # publicado junto dos binarios que cobre — nao adianta o aviso na pagina se
  # o texto nao acompanha os arquivos.
  def test_the_gpl_text_travels_with_the_binaries
    licenca = output("vendor/js-dos/LICENSE.txt")
    assert licenca.file?, "o texto da GPL-2.0 nao foi publicado com o emulador"

    conteudo = licenca.read
    assert_includes conteudo, "GNU GENERAL PUBLIC LICENSE",
      "o arquivo publicado nao e o texto da licenca"
    assert_includes conteudo, "Version 2, June 1991",
      "o js-dos e o DOSBox sao GPL-2.0; o texto publicado precisa ser o da v2"
  end

  # --- Requisito derivado do js-dos, nao da nossa propria lista -----------
  #
  # A lista VENDOR_FILES acima e copia a mao do que a task jsdos:vendor
  # copia: ela so reprova se a task nao rodou. Foi assim que passou uma demo
  # que nao bootava — faltavam tres arquivos que o js-dos busca em tempo de
  # execucao e ninguem tinha escrito na lista.
  #
  # Os testes abaixo leem o js-dos vendorizado e perguntam a ELE o que ele
  # carrega. Se uma versao nova acrescentar dependencia, ou mudar a forma de
  # pedi-la, eles reprovam alto em vez de ficar verdes por construcao.

  def vendored(caminho)
    arquivo = output("vendor/js-dos/#{caminho}")
    assert arquivo.file?, "#{caminho} nao foi publicado; rode `rake jsdos:vendor`"
    arquivo.read
  end

  # js-dos.js injeta <script src="${pathPrefix}emulators.js"> quando o player
  # comeca. A mensagem de falha dele e "Unable to add emulators.js. Probably
  # you should set the 'pathPrefix' option to point to the js-dos folder."
  def test_the_script_js_dos_injects_at_boot_is_published
    injetados = vendored("js-dos.js")
                .scan(/\.src\s*=\s*\w+\s*\+\s*"([\w.\-]+)"/).flatten.uniq

    refute_empty injetados,
      "nao achei mais o <script> que o js-dos injeta a partir do pathPrefix. " \
      "O mecanismo mudou: releia o js-dos.js antes de mexer neste teste"

    injetados.each do |nome|
      assert output("vendor/js-dos/emulators/#{nome}").file?,
        "o js-dos injeta #{nome} a partir do pathPrefix e ele nao foi " \
        "publicado — no browser isso e 404 e a demo nunca aparece"
    end
  end

  # emulators.js carrega wlibzip.js (para ler o .jsdos, que e um zip) e o js
  # do backend. Os do dosboxX ficam de fora de proposito: sao 7,5 MB e o
  # projeto usa o backend dosbox — ha um teste acima garantindo que nao
  # entrem.
  def test_everything_the_dosbox_backend_loads_from_the_path_prefix_is_published
    emuladores = vendored("emulators/emulators.js")

    literais = emuladores.scan(/pathPrefix\s*\+\s*"([\w.\-]+)"/).flatten
    variaveis = emuladores.scan(/pathPrefix\s*\+\s*this\.(\w+)/).flatten
                          .reject { |nome| nome.downcase.include?("wdosboxx") }

    refute_empty literais + variaveis,
      "nao achei mais nenhuma carga relativa ao pathPrefix no emulators.js. " \
      "O mecanismo mudou: releia o fonte antes de mexer neste teste"

    resolvidas = variaveis.map do |nome|
      valor = emuladores[/#{Regexp.escape(nome)}\s*=\s*"([\w.\-]+)"/, 1]
      refute_nil valor, "nao consegui resolver o nome do arquivo em this.#{nome}"
      valor
    end

    (literais + resolvidas).uniq.each do |nome|
      assert output("vendor/js-dos/emulators/#{nome}").file?,
        "o emulators.js carrega #{nome} a partir do pathPrefix e ele nao foi " \
        "publicado"

      # Cada cola do Emscripten busca o .wasm irmao dela.
      next unless nome.end_with?(".js")

      vendored("emulators/#{nome}").scan(/"([\w.\-]+\.wasm)"/).flatten.uniq.each do |wasm|
        assert output("vendor/js-dos/emulators/#{wasm}").file?,
          "#{nome} carrega #{wasm} e ele nao foi publicado"
      end
    end
  end

  # `rake deploy` e a task padrao: `rake` sem argumento publica o site. Ela
  # nao chamava jsdos:vendor, entao publicaria uma pagina de jogo sem
  # emulador nenhum. O CI usa `rake check`, que vendoriza — por isso a
  # producao estava salva por acidente, nao por desenho.
  def test_deploy_vendors_the_emulator_too
    rakefile = ROOT.join("Rakefile").read
    prerequisitos = rakefile[/task\s+:deploy\s*=>\s*\[([^\]]*)\]/, 1]
    refute_nil prerequisitos, "nao encontrei a task deploy"

    assert_includes prerequisitos, "jsdos:vendor",
      "rake deploy (a task padrao) publicaria o site sem o emulador"
  end

  # Os .map nao sao vendorizados (1,4 MB somados). Deixar o comentario que
  # aponta para eles so rende um 404 para quem abre o devtools.
  def test_no_vendored_script_points_at_a_source_map_we_do_not_ship
    Dir.glob(OUTPUT.join("vendor/js-dos/**/*.js")).each do |arquivo|
      conteudo = File.read(arquivo)
      mapa = conteudo[/sourceMappingURL=(\S+)/, 1]
      next if mapa.nil?

      caminho = Pathname.new(arquivo).dirname.join(mapa)
      assert caminho.file?,
        "#{File.basename(arquivo)} aponta para #{mapa}, que nao e publicado: " \
        "404 no devtools de quem visita"
    end
  end
end
