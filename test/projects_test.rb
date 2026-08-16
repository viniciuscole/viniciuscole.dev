require "test_helper"

class ProjectsTest < Minitest::Test
  include OutputHelpers

  REQUIRED_FIELDS = %w[title locale slug summary tech].freeze

  def test_project_pages_are_generated_in_both_locales
    assert_page "projects/tic-tac-toe/index.html"
    assert_page "pt/projects/tic-tac-toe/index.html"
  end

  def test_each_locale_page_carries_its_own_content
    assert_includes page_body("projects/tic-tac-toe/index.html"), "Tic-Tac-Toe"
    assert_includes page_body("pt/projects/tic-tac-toe/index.html"), "Jogo da Velha"
  end

  def test_every_project_declares_the_required_fields
    project_files.each do |file|
      front_matter = read_front_matter(file)
      REQUIRED_FIELDS.each do |field|
        refute_nil front_matter[field],
          "#{file.basename}: falta o campo obrigatorio '#{field}'"
      end
    end
  end

  def test_every_project_exists_in_both_locales
    by_slug = project_files.group_by { |f| read_front_matter(f).fetch("slug") }

    by_slug.each do |slug, files|
      locales = files.map { |f| read_front_matter(f).fetch("locale") }.sort
      assert_equal %w[en pt], locales,
        "o projeto '#{slug}' precisa existir em en e pt, encontrei: #{locales.join(', ')}"
    end
  end

  private

  def project_files
    Dir.glob(ROOT.join("src/_projects/*.md")).map { |p| Pathname.new(p) }
  end

  # Le apenas o bloco YAML entre os delimitadores --- do topo do arquivo
  def read_front_matter(file)
    content = file.read
    match = content.match(/\A---\s*\n(.*?)\n---\s*\n/m)
    refute_nil match, "#{file.basename}: front matter ausente ou malformado"
    YAML.safe_load(match[1], permitted_classes: [Date])
  end
end
