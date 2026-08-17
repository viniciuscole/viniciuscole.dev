---
layout: default
title: Vinicius Cole
locale: pt
permalink: /pt/
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

<section class="latest-posts">
  <h2><%= t("home.latest_posts") %></h2>

  <%= render "post_list", limit: 3 %>
</section>
