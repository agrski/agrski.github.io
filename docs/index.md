---
layout: default
---

Computer Science (CS) and software engineering are multi-disciplinary subjects encompassing a broad range of skills, which is what drew me to them.
These subjects range from discrete maths and linear algebra to psychology and physiology in human-computer interactions to physics, electronics, and so much more!

My own interests are around statistics, machine learning (ML), and ML Ops; distributed systems; and more broadly around creating robust, efficient, evolvable systems.
Languages, both natural and programmatic, have likewise long held my fascination, whether for dabbling in the esoteric and arcane or for more practical purposes.

The topics covered in this blog will centre around CS and software, but may at times diverge in other directions.

---

{% for post in site.posts %}
* [{{ post.title }}]({{ post.url }})

  {{ post.date | date_to_string: "ordinal" }}
{% endfor %}
