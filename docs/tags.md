---
layout: default
---

# Tags

{% assign tags_and_posts = site.tags | sort %}
{% for tag_and_posts in tags_and_posts %}
  {% assign tag = tag_and_posts | first %}
  {% assign posts = tag_and_posts | last %}

  ## {{ tag }}

  {% for post in posts %}
    * [{{ post.title }}]({{ post.url }})
  {% endfor %}

{% endfor %}
