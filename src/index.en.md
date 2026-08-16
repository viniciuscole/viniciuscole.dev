---
layout: page
title: Vinicius Cole
locale: en
# Sem `permalink:` de proposito. Um valor literal "/" faz o
# PermalinkProcessor do Bridgetown 2.2.2 resolver `relative_url` para "//"
# em vez de "/" (a divisao de "/" por "/" produz uma lista de segmentos
# vazia, e a normalizacao de "/index/" para "/" nunca dispara), quebrando
# todo link de volta para a home em ingles. A resolucao padrao da colecao
# `pages` (`/:locale/:path/`) ja produz "/" corretamente aqui, entao nao
# adicione `permalink: /` de volta. Ver task-6-report.md para o
# rastreamento completo do bug.
---

<section class="hero">
  <h1><%= t("site.title") %></h1>
  <p class="tagline"><%= t("site.tagline") %></p>
  <p class="intro"><%= t("home.intro") %></p>
</section>

<section class="featured">
  <h2><%= t("home.featured") %></h2>

  <%= render "project_grid", featured_only: true %>
</section>
