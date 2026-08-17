---
layout: default
title: Projects
locale: en
permalink: /projects/
---

<h1><%= t("projects.title") %></h1>
<p class="page-intro"><%= t("projects.intro") %></p>

<%= render "project_grid", featured_only: false %>
