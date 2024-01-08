---
layout: default
---

# Tags

{% assign tags_and_posts = site.tags | sort %}
{% for tag_and_posts in tags_and_posts %}
  {% assign tag = tag_and_posts | first | slugify %}
  {% assign posts = tag_and_posts | last %}

  ## {{ tag }}

  {% for post in posts %}
  * [{{ post.title }}]({{ post.url }})

    {{ post.date | date_to_string: "ordinal" }}
  {% endfor %}

{% endfor %}
