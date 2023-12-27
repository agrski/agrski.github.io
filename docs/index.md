---
layout: default
---

Computer Science (CS) and software engineering are multi-disciplinary subjects encompassing a broad range of skills, which is what drew me to them.
These subjects range from discrete maths and linear algebra to psychology and physiology in human-computer interactions to physics, electronics, and so much more!

---

{% for post in site.posts %}
* [{{ post.title }}]({{ post.url }})

  {{ post.date | date_to_string: "ordinal" }}
{% endfor %}
