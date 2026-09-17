require "bridgetown"

Bridgetown.load_tasks

# Run rake without specifying any command to execute a deploy build by default.
task default: :deploy

#
# Standard set of tasks, which you can customize if you wish:
#
desc "Build the Bridgetown site for deployment"
task :deploy => [:clean, "jsdos:vendor", "frontend:build"] do
  Bridgetown::Commands::Build.start
end

desc "Build the site in a test environment"
task :test do
  ENV["BRIDGETOWN_ENV"] = "test"
  Bridgetown::Commands::Build.start
end

desc "Runs the clean command"
task :clean do
  Bridgetown::Commands::Clean.start
end

namespace :frontend do
  desc "Build the frontend with esbuild for deployment"
  task :build do
    sh "npm run esbuild"
  end

  desc "Watch the frontend with esbuild during development"
  task :dev do
    sh "npm run esbuild-dev"
  rescue Interrupt
  end
end

namespace :jsdos do
  desc "Copia o js-dos do node_modules para src/vendor, servido da nossa origem"
  task :vendor do
    require "fileutils"

    origem = "node_modules/js-dos/dist"
    destino = "src/vendor/js-dos"

    unless Dir.exist?(origem)
      raise "js-dos nao encontrado em #{origem}. Rode `npm install` primeiro."
    end

    FileUtils.rm_rf(destino)
    FileUtils.mkdir_p("#{destino}/emulators")

    FileUtils.cp("#{origem}/js-dos.js", destino)

    # Servir o wdosbox.wasm da nossa origem e distribuir uma obra GPL-2.0, e o
    # pacote npm nao traz o texto da licenca. Este e o LICENSE do
    # caiiiycuk/emulators, de onde vem o binario do DOSBox, versionado em
    # build/jsdos/ e publicado ao lado dos arquivos que ele cobre.
    FileUtils.cp("build/jsdos/LICENSE-GPL-2.0.txt", "#{destino}/LICENSE.txt")

    # O js-dos.css NAO e copiado de proposito. Sao 118 KB que abrem com o
    # Preflight do Tailwind (`h1..h6{font-size:inherit}`, `a{color:inherit;
    # text-decoration:inherit}`, `*{border-width:0}`) e com a base do daisyUI
    # (`:root,[data-theme]{background-color;color}`). Servido depois da nossa
    # folha, com a mesma especificidade, ele reestilizava o site inteiro no
    # clique em Jogar. As poucas regras que a arvore do modo kiosk usa estao
    # em frontend/styles/crt.css, escopadas em .demo-screen.

    # Tudo que o js-dos busca em tempo de execucao a partir do pathPrefix,
    # lido no fonte dele:
    #
    #   js-dos.js  injeta <script src="${pathPrefix}emulators.js"> no start
    #              ("Unable to add emulators.js" e a mensagem de falha dele);
    #   emulators.js  carrega ${pathPrefix}wlibzip.js para ler o .jsdos (zip)
    #              e ${pathPrefix}wdosbox.js para o backend dosbox;
    #   wlibzip.js e wdosbox.js  carregam o .wasm irmao de cada um.
    #
    # Faltando qualquer um deles a demo 404 e nunca aparece. Apenas o backend
    # dosbox: o wdosbox-x tem 7,5 MB e serve para Windows 9x e 3Dfx, nada que
    # este jogo use.
    %w[emulators.js wdosbox.js wdosbox.wasm wlibzip.js wlibzip.wasm].each do |arquivo|
      FileUtils.cp("#{origem}/emulators/#{arquivo}", "#{destino}/emulators/#{arquivo}")
    end

    # Os .map tem 1,4 MB somados e nao sao vendorizados. Sem tirar o
    # comentario, quem abre o devtools na pagina do jogo leva um 404 por
    # arquivo.
    %W[#{destino}/js-dos.js #{destino}/emulators/emulators.js].each do |arquivo|
      conteudo = File.read(arquivo)
      File.write(arquivo, conteudo.sub(%r{\n?//# sourceMappingURL=\S+\s*\z}, "\n"))
    end
  end
end

namespace :game do
  desc "Reconstroi o bundle do jogo a partir do fonte em assembly (exige Docker)"
  task :build do
    require "fileutils"
    require "tmpdir"

    repositorio = "https://github.com/viniciuscole/tic-tac-toe-assembly"
    destino = File.expand_path("src/demos/tic-tac-toe")
    receita = File.expand_path("build/game")

    FileUtils.mkdir_p(destino)

    Dir.mktmpdir do |tmp|
      sh "git clone --depth 1 #{repositorio} #{tmp}/assembly"
      sh "docker build -t viniciuscole-game-build #{receita}"
      # Sem --user o container escreve o vca.jsdos como root dentro do
      # repositorio, e a proxima reconstrucao precisa de sudo.
      sh "docker run --rm " \
         "--user #{Process.uid}:#{Process.gid} " \
         "-v #{tmp}/assembly:/src:ro " \
         "-v #{receita}:/conf:ro " \
         "-v #{destino}:/out " \
         "viniciuscole-game-build"
    end
  end
end

namespace :demo2d do
  # SHA fixo, nao `main`. Um upstream que andou faria os patches aplicarem
  # torto em silencio, e o resultado seria um .wasm que aborta no primeiro
  # quadro em vez de um erro de build.
  REPO_2D = "https://github.com/viniciuscole/2D-Computer-Graphics".freeze
  SHA_2D  = "5910e9a0bf780dc739bc85cfe8a520851e7774cc".freeze

  desc "Reconstroi o jogo 2D em WebAssembly a partir do fonte (exige Docker)"
  task :build do
    require "fileutils"
    require "tmpdir"

    destino = File.expand_path("src/demos/2d-graphics")
    receita = File.expand_path("build/2d")

    FileUtils.mkdir_p(destino)

    Dir.mktmpdir do |tmp|
      fonte = "#{tmp}/2d"
      sh "git clone #{REPO_2D} #{fonte}"
      sh "git -C #{fonte} checkout --detach #{SHA_2D}"
      sh "docker build -t viniciuscole-2d-build #{receita}"
      # Sem --user o container escreve os artefatos como root dentro do
      # repositorio, e a proxima reconstrucao precisa de sudo.
      sh "docker run --rm " \
         "--user #{Process.uid}:#{Process.gid} " \
         "-v #{fonte}:/src " \
         "-v #{receita}:/patches:ro " \
         "-v #{destino}:/out " \
         "viniciuscole-2d-build"
    end
  end

  IMAGEM_PLAYWRIGHT = "mcr.microsoft.com/playwright:v1.56.0-noble".freeze

  desc "Verifica em navegador de verdade que o jogo 2D desenha e responde (exige Docker)"
  task :verify do
    require "fileutils"
    require "tmpdir"

    receita = File.expand_path("build/2d")
    artefatos = File.expand_path("src/demos/2d-graphics")

    Dir.mktmpdir do |tmp|
      # A bancada precisa dos artefatos e da pagina no mesmo diretorio, porque
      # jogo.js busca jogo.wasm e jogo.data como irmaos.
      FileUtils.cp(Dir["#{artefatos}/jogo.*"], tmp)
      FileUtils.cp("#{receita}/bench.html", "#{tmp}/index.html")
      FileUtils.cp("#{receita}/verify.js", tmp)

      # python3 -m http.server, dentro do proprio container: a imagem
      # mcr.microsoft.com/playwright:v1.56.0-noble ja traz Python 3.12 (e
      # Node 22), entao nao ha necessidade de inventar um servidor em Node
      # nem de rodar um processo a parte no host.
      sh "docker run --rm --network host " \
         "--user #{Process.uid}:#{Process.gid} " \
         "-v #{tmp}:/work -w /work " \
         "-e ALVO=http://localhost:4123/ " \
         "#{IMAGEM_PLAYWRIGHT} " \
         "bash -c 'npm install --silent playwright@1.56.0 && " \
         "(python3 -m http.server 4123 &) && sleep 2 && node verify.js'"
    end
  end

  namespace :verify do
    desc "Verifica a demo na pagina do site de verdade (exige Docker e output/)"
    task :site do
      require "fileutils"
      require "tmpdir"

      saida = File.expand_path("output")
      receita = File.expand_path("build/2d")

      unless File.directory?(saida)
        raise "output/ nao existe — rode `bin/bridgetown build` primeiro."
      end

      Dir.mktmpdir do |tmp|
        FileUtils.cp("#{receita}/verify.js", tmp)

        # output/ entra so leitura (:ro) e o npm install roda num diretorio a
        # parte: montar output/ como /work e instalar o playwright ali dentro
        # deixava node_modules/, package.json e package-lock.json espalhados
        # por cima do site gerado -- um `rake proof` avulso depois varreria
        # HTML de dentro do node_modules. python3 -m http.server aceita
        # --directory desde o 3.7, entao serve /site sem precisar copiar nada
        # para dentro do diretorio de trabalho.
        sh "docker run --rm --network host " \
           "--user #{Process.uid}:#{Process.gid} " \
           "-v #{saida}:/site:ro " \
           "-v #{tmp}:/work -w /work " \
           "-e ALVO=http://localhost:4124/projects/2d-graphics/ " \
           "-e CANVAS=[data-wasm-canvas] " \
           "#{IMAGEM_PLAYWRIGHT} " \
           "bash -c 'npm install --silent playwright@1.56.0 && " \
           "(python3 -m http.server 4124 --directory /site &) && sleep 2 && node verify.js'"
      end
    end
  end
end

namespace :routes do
  REPO_ROUTES = "https://github.com/viniciuscole/car-routes-optimazing".freeze
  SHA_ROUTES  = "eed710fe57c00679bd3165ad5e29a635cdf289a7".freeze

  desc "Reconstroi o simulador de rotas em WebAssembly a partir do fonte (exige Docker)"
  task :build do
    require "fileutils"
    require "tmpdir"

    destino = File.expand_path("src/demos/car-routes")
    receita = File.expand_path("build/routes")
    FileUtils.mkdir_p(destino)

    Dir.mktmpdir do |tmp|
      fonte = "#{tmp}/routes"
      sh "git clone #{REPO_ROUTES} #{fonte}"
      sh "git -C #{fonte} checkout --detach #{SHA_ROUTES}"
      sh "docker build -t viniciuscole-routes-build #{receita}"
      sh "docker run --rm " \
         "--user #{Process.uid}:#{Process.gid} " \
         "-e SHA_ESPERADO=#{SHA_ROUTES} " \
         "-v #{fonte}:/src " \
         "-v #{destino}:/out " \
         "viniciuscole-routes-build"
    end
  end
end

#
# Add your own Rake tasks here! You can use `environment` as a prerequisite
# in order to write automations or other commands requiring a loaded site.
#
# task :my_task => :environment do
#   puts site.root_dir
#   automation do
#     say_status :rake, "I'm a Rake tast =) #{site.config.url}"
#   end
# end

require "rake/testtask"

Rake::TestTask.new(:minitest) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

desc "Verifica links internos e imagens no HTML gerado"
task :proof do
  require "html_proofer"

  HTMLProofer.check_directory(
    "output",
    disable_external: true,          # links externos nao devem quebrar o build
    check_img_http: true,
    enforce_https: false,
    allow_missing_href: false,
    ignore_missing_alt: false
  ).run
end

# Depende de :clean de proposito. Sem limpar o output/, uma pagina renomeada
# ou removida deixa o arquivo antigo para tras: `assert_page` acha o arquivo
# velho e o html-proofer checa HTML que o build atual nao produz mais — verde
# falso exatamente na hora em que se mais precisa de vermelho.
desc "Constroi o site e roda todas as verificacoes"
task :check => :clean do
  Rake::Task["jsdos:vendor"].invoke
  Rake::Task["frontend:build"].invoke
  sh "bin/bridgetown build"
  Rake::Task["minitest"].invoke
  Rake::Task["proof"].invoke
end
