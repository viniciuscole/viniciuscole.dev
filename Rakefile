require "bridgetown"

Bridgetown.load_tasks

# Run rake without specifying any command to execute a deploy build by default.
task default: :deploy

#
# Standard set of tasks, which you can customize if you wish:
#
desc "Build the Bridgetown site for deployment"
task :deploy => [:clean, "frontend:build"] do
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
      sh "docker run --rm " \
         "-v #{tmp}/assembly:/src:ro " \
         "-v #{receita}:/conf:ro " \
         "-v #{destino}:/out " \
         "viniciuscole-game-build"
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
