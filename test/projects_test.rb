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

  # Presenca, nao "nao-nil": com refute_nil, `title: ""` e `tech: []` passavam
  # e a pagina saia sem titulo e sem tecnologias.
  def test_every_project_declares_the_required_fields
    project_files.each do |file|
      front_matter = read_front_matter(file)
      REQUIRED_FIELDS.each do |field|
        assert present?(front_matter[field]),
          "#{file.basename}: campo obrigatorio '#{field}' ausente ou vazio"
      end
    end
  end

  # O README promete que um projeto e dois arquivos Markdown com exatamente os
  # cinco campos de REQUIRED_FIELDS. `layout` nao esta entre eles porque
  # `config/initializers.rb` define o default da colecao — se alguem voltar a
  # escrever `layout:` no front matter, o default para de ser exercitado e o
  # teste abaixo deixa de provar coisa alguma.
  def test_no_project_declares_a_layout_in_its_front_matter
    project_files.each do |file|
      assert_nil read_front_matter(file)["layout"],
        "#{file.basename}: `layout` no front matter — o default da colecao em " \
        "config/initializers.rb deve bastar (ver README)"
    end
  end

  # Sem o default da colecao, um projeto sem `layout` renderiza so o corpo em
  # Markdown: sem <html>, sem header, sem footer e sem CSS. Seguir o README ao
  # pe da letra tem que produzir uma pagina dentro do site.
  def test_project_without_an_explicit_layout_renders_inside_the_site_chrome
    %w[projects/tic-tac-toe/index.html pt/projects/tic-tac-toe/index.html].each do |page|
      body = page_body(page)

      assert_includes body, "<!doctype html>", "#{page}: sem documento HTML"
      assert_match %r{<html lang="(en|pt)">}, body, "#{page}: sem <html lang>"
      assert_includes body, '<header class="site-header">', "#{page}: sem header do site"
      assert_includes body, '<footer class="site-footer">', "#{page}: sem footer do site"
      assert_includes body, '<link rel="stylesheet"', "#{page}: sem folha de estilo"
      assert_includes body, '<article class="project">', "#{page}: sem o layout de projeto"
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

  def present?(value)
    case value
    when nil        then false
    when String     then !value.strip.empty?
    when Array, Hash then !value.empty?
    else true
    end
  end

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
