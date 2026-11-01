---
layout: default
title: Blog
locale: en
permalink: /blog/
---

<h1><%= t("blog.title") %></h1>
<p class="page-intro"><%= t("blog.intro") %> <a href="<%= feed_url(resource.data.locale) %>" class="feed-link"><%= t("blog.feed") %></a></p>

<%= render "post_list" %>
