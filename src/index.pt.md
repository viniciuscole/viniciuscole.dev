---
layout: default
title: Vinicius Cole
locale: pt
permalink: /pt/
---

<section class="card">
  <img class="card-photo"
       src="/images/vinicius.svg"
       alt="<%= t("home.photo_alt") %>"
       width="400" height="400">

  <div class="card-text">
    <h1><%= t("site.title") %></h1>
    <p class="card-role"><%= t("site.tagline") %></p>
    <p class="card-intro"><%= t("home.intro") %></p>

    <ul class="card-links">
      <li><a href="<%= site.data.site_links.github %>" rel="me">GitHub</a></li>
      <li><a href="<%= site.data.site_links.linkedin %>" rel="me">LinkedIn</a></li>
      <li><a href="<%= site.data.site_links.email %>">E-mail</a></li>
    </ul>
  </div>
</section>

<section class="featured">
  <h2><%= t("home.featured") %></h2>

  <%= render "project_grid", featured_only: true %>
</section>

<section class="latest-posts">
  <h2><%= t("home.latest_posts") %></h2>

  <%= render "post_list", limit: 3 %>
</section>
