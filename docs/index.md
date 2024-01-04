---
layout: default
---

> Put your feet up and your kettle on for a brew or three---this is Sourcery, for the Sedentary

Sourcery is not a typo, but rather a play on two terms that together capture the essence of this blog.
The topics covered herein shall focus mainly around software and code, also known as _source_ code.
Creating things with software can often feel magical and, to paraphrase [the dictionary](https://dictionary.cambridge.org/dictionary/english/sorcery), _sorcery_ is a type of magic used to make things happen.

While the reader's body may presently be sedentary, I hope some of these articles will encourage you to think a little more deeply about a topic or two, or to learn something new.

I mentioned that this blog will mostly be about software, although there may be tangents into other topics at times.
Computer Science (CS) and software engineering are multi-disciplinary subjects encompassing a broad range of skills, which is what drew me to them.
My own interests centre around statistics, machine learning (ML), and ML Ops; distributed systems; and more broadly around creating robust, efficient, evolvable systems.
Languages, both natural and programmatic, have likewise long held my fascination, whether for dabbling in the esoteric and arcane or for more practical purposes.

The view and opinions expressed in this blog are those of the author and do not necessarily represent the opinions of any organisation, employer, or other party, except where stated otherwise.

This blog is made available under the terms of the [Creative Commons Attribution-NonCommercial 4.0 International](https://creativecommons.org/licenses/by-nc/4.0/) (CC BY-NC 4.0) licence.

---

{% for post in site.posts %}
* [{{ post.title }}]({{ post.url }})

  {{ post.date | date_to_string: "ordinal" }}
{% endfor %}
