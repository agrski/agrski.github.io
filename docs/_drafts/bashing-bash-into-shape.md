---
title: Bashing Bash Into Shape
tags: bash config
---


Bash isn't a trendy shell like `zsh` or `fish`.
It doesn't boast fancy colours and auto-complete suggestions out of the box.
Some of the syntax _is_ admittedly a bit awkward.
For all that, it's still my shell of choice.

This article explains how I configure `bash` as my daily driver to overcome some of its limitations.
If you use `bash`, you might find a few of these tips handy for improving your own experience.
If you already use another shell, you might not be persuaded to change back, but you might pick up a few ideas all the same.

---

* Bash gets a bad rap
* It's ubiquitous and reasonably powerful
* Just needs a few tweaks to make it more useful

* stty/key bindings settings to fix asymmetric behaviour
* Eternal history settings
* Supercharging with fzf
  * Mention my preferred settings, e.g. colours for command types
* Using `bashrc.d/...` style to organise config
  * Allows for selectively disabling settings if unneeded
  * Keeps things separated so not just one huge blob of a file
* A few neat tricks like `^.`, `^x-u`, etc.
