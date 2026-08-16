require "test_helper"

class DemoDispatcherTest < Minitest::Test
  include OutputHelpers

  ALLOWED_TYPES = %w[none jsdos].freeze

  def test_project_without_demo_renders_the_placeholder
    body = page_body("projects/tic-tac-toe/index.html")
    assert_includes body, 'class="demo demo-none"'
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

  def test_every_allowed_type_except_jsdos_has_a_partial
    # jsdos chega na Fase 2; os demais precisam existir agora
    (ALLOWED_TYPES - ["jsdos"]).each do |type|
      partial = ROOT.join("src/_partials/demos/_#{type}.erb")
      assert partial.file?, "falta o partial src/_partials/demos/_#{type}.erb"
    end
  end
end
