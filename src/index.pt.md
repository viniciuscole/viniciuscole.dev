---
layout: page
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

  <div class="project-grid">
    <% collections.projects.resources
         .select { |p| p.data.locale.to_s == resource.data.locale.to_s && p.data.featured }
         .sort_by { |p| p.data.order || 999 }
         .each do |project| %>
      <%= render "project_card", project: project %>
    <% end %>
  </div>
</section>
