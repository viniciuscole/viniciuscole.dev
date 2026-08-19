require "test_helper"
require "tmpdir"
require "fileutils"

# Builders::DemoHelper.partial_for e testado diretamente (sem passar por um
# build completo), entao o plugin precisa ser carregado neste processo.
# `class Builders::DemoHelper` (forma compacta) exige que o modulo `Builders`
# ja exista; em produção quem cria esse modulo e o autoload do Zeitwerk, que
# so roda quando um Bridgetown::Site sobe. Fora desse boot, pre-declaramos o
# modulo vazio para o require funcionar.
require "bridgetown"
require ROOT.join("plugins/site_builder")
module Builders; end unless defined?(Builders)
require ROOT.join("plugins/builders/demo_helper")

class DemoDispatcherTest < Minitest::Test
  include OutputHelpers

  # A lista de tipos e do plugin, nao do teste: duplicar aqui deixaria o teste
  # verde depois de alguem registrar um tipo novo sem criar o partial.
  ALLOWED_TYPES = Builders::DemoHelper::DEMO_TYPES

  # Tipos ja registrados que ainda nao tem partial. Vazia desde a Task 3 da
  # Fase 2, que criou src/_partials/demos/_jsdos.erb.
  PENDING_TYPES = %w[].freeze

  # Resource minimo o bastante para exercitar Builders::DemoHelper.partial_for
  # sem precisar de uma colecao ou de um build completo.
  FakeResource = Struct.new(:data, :relative_path)

  # Site real construido do mesmo jeito que LayoutTest.locale_helpers
  # (test/layout_test.rb): a partir da configuracao real do projeto
  # (config/initializers.rb, locales, etc), com destino descartavel. Usado so
  # para renderizar partials fora de uma pagina completa, via
  # Bridgetown::TemplateView.render — a API que o proprio bridgetown-core
  # documenta para "output partials and components outside of a specific
  # rendering context" (bridgetown-core/template_view.rb).
  def self.site
    @site ||= begin
      destination = Dir.mktmpdir("demo_dispatcher_test_output")
      at_exit { FileUtils.remove_entry(destination) if File.exist?(destination) }
      config = Bridgetown.configuration(
        "root_dir"    => ROOT.to_s,
        "source"      => ROOT.join("src").to_s,
        "destination" => destination,
        "quiet"       => true,
        "environment" => "test"
      )
      Bridgetown::Site.new(config).tap(&:read)
    end
  end

  # Antes da Task 3 da Fase 2 este teste verificava a pagina real de
  # tic-tac-toe, o unico projeto do site, que ainda nao tinha demo. Agora que
  # tic-tac-toe usa `demo: jsdos`, nao sobra nenhum projeto real sem demo para
  # observar o placeholder de ponta a ponta — entao o teste passa a exercitar
  # Builders::DemoHelper.partial_for diretamente, do mesmo jeito que os outros
  # testes de degradacao deste arquivo. Isso prova o mapeamento, mas nao que
  # _none.erb realmente renderiza esse HTML — essa prova esta no teste
  # seguinte, que renderiza o partial de verdade.
  def test_project_without_demo_renders_the_placeholder
    resource = FakeResource.new({}, "_projects/sem-demo.md")

    assert_equal "demos/none", Builders::DemoHelper.partial_for(resource)
  end

  # Cobertura de ponta a ponta do ramo "none": nenhuma pagina real do site
  # passa mais por esse ramo desde que tic-tac-toe virou `demo: jsdos`
  # (Task 3), entao nada em output/ exercitaria _none.erb sem este teste.
  # Renderiza o partial pelo mesmo motor que src/_layouts/project.erb usa —
  # `render demo_partial_for(resource)` acaba em TemplateView#partial — em
  # vez de so verificar que o mapeamento aponta para o nome certo.
  def test_the_none_partial_renders_the_placeholder_markup
    original_site = Bridgetown::Current.site
    Bridgetown::Current.site = self.class.site

    html = Bridgetown::TemplateView.render("demos/none")

    assert_includes html, 'class="demo demo-none"',
      "o partial demos/none deveria renderizar o placeholder, renderizou: #{html.inspect}"
  ensure
    Bridgetown::Current.site = original_site
  end

  def test_every_declared_demo_type_is_allowed
    Dir.glob(ROOT.join("src/_projects/*.md")).each do |path|
      file = Pathname.new(path)
      front_matter = YAML.safe_load(file.read.match(/\A---\s*\n(.*?)\n---\s*\n/m)[1])
      type = front_matter.dig("demo", "type") || "none"

      assert_includes ALLOWED_TYPES, type,
        "#{file.basename}: tipo de demo '#{type}' nao existe"
    end
  end

  def test_every_allowed_type_has_a_partial_unless_it_is_still_pending
    (ALLOWED_TYPES - PENDING_TYPES).each do |type|
      partial = ROOT.join("src/_partials/demos/_#{type}.erb")
      assert partial.file?, "falta o partial src/_partials/demos/_#{type}.erb"
    end
  end

  # Front matter malformado (demo escrito como valor escalar em vez do mapa
  # aninhado esperado, ex.: `demo: jsdos` em vez de `demo:\n  type: jsdos`)
  # nao pode derrubar o build. Sem a guarda em Builders::DemoHelper.partial_for
  # este teste levanta TypeError, porque String nao responde a `dig`/`[]` do
  # jeito que um Hash aninhado responde.
  def test_scalar_demo_front_matter_degrades_to_none_without_raising
    resource = FakeResource.new({ demo: "jsdos" }, "_projects/broken.md")

    assert_equal "demos/none", Builders::DemoHelper.partial_for(resource)
  end

  # Tipo declarado mas fora de DEMO_TYPES tambem degrada para "none" (com
  # aviso no log, verificado manualmente no relatorio da tarefa). Sem este
  # teste, um refator futuro poderia trocar o fallback silenciosamente e o
  # suite continuaria verde.
  def test_unknown_demo_type_degrades_to_none
    resource = FakeResource.new({ demo: { type: "atari" } }, "_projects/broken.md")

    assert_equal "demos/none", Builders::DemoHelper.partial_for(resource)
  end
end
