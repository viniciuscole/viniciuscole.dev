require "minitest/autorun"
require "pathname"
require "yaml"
require "date" # YAML.safe_load precisa de Date liberado para ler front matter

ROOT   = Pathname.new(File.expand_path("..", __dir__))
OUTPUT = ROOT.join("output")

module OutputHelpers
  # Caminho absoluto de um arquivo dentro de output/
  def output(path)
    OUTPUT.join(path)
  end

  # Falha com mensagem util quando a pagina esperada nao foi gerada
  def assert_page(path)
    assert output(path).file?,
      "esperava a pagina #{path} dentro de output/, mas ela nao foi gerada"
  end

  # Conteudo HTML de uma pagina gerada
  def page_body(path)
    assert_page(path)
    output(path).read
  end

  # Todas as paginas HTML geradas, para as verificacoes que valem para o site
  # inteiro (nenhuma pagina fica de fora quando uma nova e criada).
  def html_pages
    pages = Dir.glob(OUTPUT.join("**/*.html")).sort
    refute_empty pages, "nenhum HTML em output/ — o site nao foi construido"
    pages
  end
end

# Guardas de contraste WCAG usadas pelas duas suites de estilo (crt_test.rb
# e demo_styles_test.rb). Viviam copiadas verbatim nos dois arquivos; aqui
# em um so lugar para nao divergirem. Cada teste continua responsavel por
# extrair a cor certa do CSS e decidir contra o que medir -- isto so faz a
# conta.
module ContrastHelpers
  def relative_luminance(hex)
    r, g, b = hex.delete("#").scan(/../).map { |c| c.to_i(16) / 255.0 }
    r, g, b = [r, g, b].map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
    (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
  end

  def contrast(hex_a, hex_b)
    la = relative_luminance(hex_a)
    lb = relative_luminance(hex_b)
    lighter, darker = [la, lb].max, [la, lb].min
    (lighter + 0.05) / (darker + 0.05)
  end
end
