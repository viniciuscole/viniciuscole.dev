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

desc "Constroi o site e roda todas as verificacoes"
task :check do
  Rake::Task["frontend:build"].invoke
  sh "bin/bridgetown build"
  Rake::Task["minitest"].invoke
  Rake::Task["proof"].invoke
end
