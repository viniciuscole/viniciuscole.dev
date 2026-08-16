---
layout: page
title: Projetos
locale: pt
permalink: /pt/projects/
---

<h1><%= t("projects.title") %></h1>
<p class="page-intro"><%= t("projects.intro") %></p>

<div class="project-grid">
  <% collections.projects.resources
       .select { |p| p.data.locale.to_s == resource.data.locale.to_s }
       .sort_by { |p| p.data.order || 999 }
       .each do |project| %>
    <%= render "project_card", project: project %>
  <% end %>
</div>
