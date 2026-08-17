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
