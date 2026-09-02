require "test_helper"

# O botao de tema nao tinha nenhuma cobertura: era um caractere fixo que nunca
# mudava. Agora ele traz dois SVGs e o CSS decide qual aparece, entao ha duas
# coisas que podem quebrar em silencio e que estes testes seguram.
#
# A primeira e a marcacao: se um dos icones sumir do partial, o botao fica
# vazio em algum tema e ninguem percebe olhando so o tema em que trabalhou.
#
# A segunda e a troca em CSS. Ela e feita em CSS de proposito — o bundle JS e
# `defer` e o tema ja foi aplicado antes do primeiro paint pelo script inline
# de _head.erb, entao um icone que dependesse de JS piscaria o sol antes de
# virar lua para quem esta no escuro. As tres condicoes precisam acompanhar as
# do tokens.css; se uma se perder, o icone passa a mentir sobre o que o clique
# vai fazer, e isso e invisivel num teste que so olhe o HTML.
class ThemeToggleTest < Minitest::Test
  include OutputHelpers
  include StylesheetHelpers

  # O botao inteiro, do <button> ao </button>, para as asercoes olharem so
  # dentro dele e nao acharem "icone-sol" em qualquer outro canto da pagina.
  def botao_de_tema(corpo)
    corpo[%r{<button[^>]*class="theme-toggle".*?</button>}m]
  end

  # Espaco em branco varia entre o build de desenvolvimento e o minificado que
  # a CI produz, entao as asercoes comparam uma forma normalizada.
  #
  # O espaco some so em volta de `{ } ; : ,`. O espaco entre dois seletores tem
  # de sobreviver: `.theme-toggle .icone-sol` (descendente) e
  # `.theme-toggle.icone-sol` (o mesmo elemento com as duas classes) sao coisas
  # diferentes, e um teste que apagasse tudo aceitaria o seletor errado.
  #
  # Parenteses ficam de fora pelo mesmo motivo: apagar o espaco depois deles
  # transformaria `:root:not([data-theme=light]) .theme-toggle` no composto
  # `:root:not([data-theme=light]).theme-toggle`, que nunca casa com nada.
  # A unica diferenca que sobra e o espaco em `@media (`, e o teste da media
  # query trata dela com uma expressao regular.
  def css_comprimido
    published_stylesheets
      .gsub(/\s+/, " ")
      .gsub(/\s*([{};:,])\s*/, '\1')
  end

  def test_todo_cabecalho_traz_os_dois_icones
    encontrados = 0

    html_pages.each do |caminho|
      corpo = Pathname.new(caminho).read
      next unless corpo.include?("theme-toggle")

      encontrados += 1
      marcacao = botao_de_tema(corpo)
      refute_nil marcacao, "#{caminho}: o botao de tema nao fecha, o HTML esta quebrado"
      # A classe inteira, entre aspas: "icone-sol" sozinho casaria por dentro
      # de qualquer classe que apenas comece assim, e o teste passaria com o
      # icone renomeado.
      assert_includes marcacao, %(class="icone-lua"), "#{caminho}: falta o icone da lua no botao"
      assert_includes marcacao, %(class="icone-sol"), "#{caminho}: falta o icone do sol no botao"
    end

    refute_equal 0, encontrados,
      "nenhuma pagina gerada tem o botao de tema — o cabecalho sumiu do site"
  end

  # O nome acessivel vem do aria-label. O title existe so para dar o tooltip
  # visivel a quem usa mouse, que e o que faltava. Os dois carregam a mesma
  # string traduzida, entao um sem o outro e sinal de meio caminho.
  def test_o_botao_tem_nome_acessivel_e_tooltip
    html_pages.each do |caminho|
      corpo = Pathname.new(caminho).read
      next unless corpo.include?("theme-toggle")

      marcacao = botao_de_tema(corpo)
      rotulo = marcacao[/aria-label="([^"]+)"/, 1]
      titulo = marcacao[/title="([^"]+)"/, 1]

      refute_nil rotulo, "#{caminho}: o botao de tema ficou sem aria-label"
      refute_nil titulo, "#{caminho}: o botao de tema ficou sem title (o tooltip)"
      assert_equal rotulo, titulo,
        "#{caminho}: aria-label e title divergiram; devem ser a mesma string traduzida"
    end
  end

  # Se os SVGs deixarem de ser aria-hidden, eles entram no nome acessivel do
  # botao e o leitor de tela passa a anunciar o desenho junto com o rotulo.
  def test_os_icones_ficam_fora_da_arvore_de_acessibilidade
    html_pages.each do |caminho|
      corpo = Pathname.new(caminho).read
      next unless corpo.include?("theme-toggle")

      svgs = botao_de_tema(corpo).scan(/<svg[^>]*>/)
      assert_equal 2, svgs.length, "#{caminho}: esperava exatamente dois SVGs no botao"
      svgs.each do |svg|
        assert_includes svg, 'aria-hidden="true"',
          "#{caminho}: um SVG do botao de tema nao esta aria-hidden"
      end
    end
  end

  def test_o_css_publicado_esconde_o_sol_no_tema_claro
    assert_includes css_comprimido, ".theme-toggle .icone-sol{display:none}",
      "o sol deixou de ser escondido no tema claro — os dois icones aparecem juntos"
  end

  def test_o_css_publicado_troca_os_icones_na_escolha_explicita
    css = css_comprimido

    assert_includes css, ":root[data-theme=dark] .theme-toggle .icone-lua{display:none}",
      "quem escolheu o tema escuro continua vendo a lua"
    assert_includes css, ":root[data-theme=dark] .theme-toggle .icone-sol{display:inline-block}",
      "quem escolheu o tema escuro nao ve o sol"
  end

  # A condicao que atende quem nunca clicou no botao. E a mais facil de
  # esquecer, porque so aparece para quem tem o sistema no escuro.
  def test_o_css_publicado_troca_os_icones_pelo_prefers_color_scheme
    css = css_comprimido

    assert_match(/@media\s*\(prefers-color-scheme:dark\)/, css,
      "o CSS publicado nao tem a media query de tema escuro")
    assert_includes css,
      ":root:not([data-theme=light]) .theme-toggle .icone-lua{display:none}",
      "no sistema escuro, sem escolha salva, a lua continua aparecendo"
    assert_includes css,
      ":root:not([data-theme=light]) .theme-toggle .icone-sol{display:inline-block}",
      "no sistema escuro, sem escolha salva, o sol nao aparece"
  end
end
