require "test_helper"

# A troca de idioma embaralha o texto em duas pontas: a pagina que sai (JS no
# clique) e a pagina que chega. A chegada depende de tres pecas que vivem em
# arquivos diferentes e falham em silencio quando uma se perde: o script
# inline de _head.erb (le a chave e poe a classe), o CSS (segura o texto
# escondido ate o bundle rodar) e o bundle (troca o texto e tira a classe).
class LangScrambleTest < Minitest::Test
  include OutputHelpers
  include StylesheetHelpers

  CHAVE = "lang-scramble"

  def css_comprimido
    published_stylesheets
      .gsub(/\s+/, " ")
      .gsub(/\s*([{};:,])\s*/, '\1')
  end

  def bundle_js
    corpo = page_body("index.html")
    src = corpo[/<script[^>]+src="([^"]+\.js)"[^>]*defer/, 1]
    refute_nil src, "a pagina nao linka o bundle JS com defer"
    caminho = OUTPUT.join(src.sub(%r{\A/}, ""))
    assert caminho.file?, "a pagina linka #{src}, que nao existe em output/"
    caminho.read
  end

  # O script precisa vir antes da folha de estilo e do bundle: e ele que
  # decide, antes do primeiro paint, se o texto nasce escondido.
  def test_toda_pagina_le_a_chave_antes_do_primeiro_paint
    html_pages.each do |caminho|
      corpo = Pathname.new(caminho).read
      head = corpo[%r{<head>.*?</head>}m]
      refute_nil head, "#{caminho}: sem <head>"

      inline = head.index(%(sessionStorage.getItem("#{CHAVE}")))
      folha = head.index(%(rel="stylesheet"))
      refute_nil inline, "#{caminho}: o <head> nao le a chave #{CHAVE}"
      refute_nil folha, "#{caminho}: o <head> nao linka a folha de estilo"
      assert inline < folha, "#{caminho}: o script da chave vem depois da folha de estilo"

      assert_includes head, %(sessionStorage.removeItem("#{CHAVE}")),
        "#{caminho}: a chave nao e consumida — um F5 embaralharia de novo"
      assert_includes head, %(classList.add("#{CHAVE}")),
        "#{caminho}: o script nao poe a classe que o CSS usa"
      assert_includes head, "prefers-reduced-motion: reduce",
        "#{caminho}: quem pediu menos movimento tambem seria embaralhado"
    end
  end

  def test_o_css_publicado_segura_o_texto_ate_o_bundle_rodar
    css = css_comprimido

    %w[.site-header main .site-footer].each do |alvo|
      assert_match(/html\.lang-scramble [^{]*#{Regexp.escape(alvo)}[^{]*\{[^}]*animation:lang-scramble-espera 1s step-end both/, css,
        "#{alvo} nao fica escondido enquanto a pagina chega embaralhada")
    end

    assert_match(/@keyframes lang-scramble-espera\{(from|0%)\{visibility:hidden\}(to|100%)\{visibility:visible\}\}/, css,
      "a espera precisa comecar escondida e terminar visivel — e o que devolve o texto se o bundle nunca rodar")
  end

  def test_o_bundle_publicado_traz_o_embaralhador
    js = bundle_js
    assert_includes js, %("#{CHAVE}"), "o bundle nao conhece a chave #{CHAVE}"
    assert_includes js, ".locale-switcher a", "o bundle nao escuta o alternador de idioma"
  end
end
