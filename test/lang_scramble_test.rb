require "test_helper"

# A troca de idioma acontece sem recarregar: o bundle busca a pagina irma,
# pareia os nos de texto das duas arvores (mesmo template, idiomas
# diferentes) e morfa cada texto no lugar. O pareamento so funciona se a
# pagina irma existir e tiver a mesma estrutura; se nao, o JS cai na
# navegacao normal e o efeito some em silencio.
class LangScrambleTest < Minitest::Test
  include OutputHelpers

  def bundle_js
    corpo = page_body("index.html")
    src = corpo[/<script[^>]+src="([^"]+\.js)"[^>]*defer/, 1]
    refute_nil src, "a pagina nao linka o bundle JS com defer"
    caminho = OUTPUT.join(src.sub(%r{\A/}, ""))
    assert caminho.file?, "a pagina linka #{src}, que nao existe em output/"
    caminho.read
  end

  # So as tags, na ordem, fora de <noscript> (o JS pula o que esta la dentro
  # porque o documento vivo e o do DOMParser discordam sobre o conteudo).
  def esqueleto(html, classe_ou_tag)
    trecho =
      if classe_ou_tag == "main"
        html[%r{<main[\s>].*?</main>}m]
      else
        html[%r{<(\w+)[^>]*class="#{classe_ou_tag}".*?</\1>}m]
      end
    refute_nil trecho, "nao achei #{classe_ou_tag}"
    trecho.gsub(%r{<noscript>.*?</noscript>}m, "").scan(/<(\w+)[\s>\/]/).flatten
  end

  def test_o_bundle_publicado_traz_a_troca_sem_recarregar
    js = bundle_js
    assert_includes js, ".locale-switcher a", "o bundle nao escuta o alternador de idioma"
    assert_includes js, "pushState", "o bundle nao atualiza a URL ao trocar de idioma"
    assert_includes js, "popstate", "voltar no historico deixaria a pagina no idioma errado"
  end

  # O que o JS exige em tempo de execucao, verificado no build: cada pagina
  # com irma traduzida aponta para ela no alternador, e as duas tem o mesmo
  # esqueleto de tags no cabecalho, no main e no rodape. Paginas sem irma
  # (404, 500) mandam o alternador para a home do outro idioma; la o JS
  # desiste do pareamento e navega normal, e e isso mesmo.
  def test_toda_pagina_pareia_com_a_irma
    html_pages.each do |caminho|
      corpo = Pathname.new(caminho).read
      next unless corpo.include?('rel="alternate" hreflang=')
      link = corpo[%r{<nav class="locale-switcher".*?href="([^"]+)"}m, 1]
      refute_nil link, "#{caminho}: tem irma traduzida mas nao tem alternador"

      irma = OUTPUT.join(link.sub(%r{\A/}, ""), "index.html")
      assert irma.file?, "#{caminho}: o alternador aponta para #{link}, que nao foi gerado"
      corpo_irma = irma.read

      %w[site-header main site-footer].each do |raiz|
        assert_equal esqueleto(corpo, raiz), esqueleto(corpo_irma, raiz),
          "#{caminho}: #{raiz} tem estrutura diferente da irma #{link}; a troca de idioma cairia na navegacao normal"
      end
    end
  end
end
