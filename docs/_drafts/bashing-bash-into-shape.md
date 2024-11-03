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

## Why bash?

Before explaining how I configure bash, it's worth taking a moment to discuss _why_ I still use it, even thought trendier alternatives exist.

The primary motivation is that _bash is ubiquitous_.
Practically every modern flavour of Linux provides bash out of the box, from container images like `busybox` to mainstream OS distros like Ubuntu and Red Hat.
Even on Windows, `git-bash` and WSL default to bash as their shell of choice.
By sticking with the default, it's easy to switch between different environments that I haven't configured, such as when interacting with coworkers or jumping into debugging issues.

Relatedly, it's much easier to find help for commonplace tools than for more niche ones!
Zsh is quite popular, so this isn't a strong argument against it, but it's always a reason to keep in mind when evaluating one's stack.

The next reason to stick with the standard option is that it's reasonably powerful.
Sure, it isn't as glitzy as some of the alternatives, but I personally prefer a functional, productive environment that looks plain than one packed with visual bells and whistles that distract me from what I'm trying to do.
This is a highly subjective point, but personally I'm not a fan of tools that throw too much information at the user and try to draw their attention to things they don't need to think about all the time.
For example, I don't include a git branch in my PS1 (de facto shell prompt) because I can query this when I'm interested in it.
Nor do I see the point in installing a plugin to tell me the time when it's as easy to write into my `bashrc` once.
The point is, you can do a lot with bash, and for plenty of common tasks it's no harder than anything else.

The final justification for sticking with bash is that it needs only a few tweaks to bring it up to par...

## Assauging Asymmetry

One of the most irritating things about a default bash setup, in my opinion, is that actions are asymmetric.
Let me explain what I mean.

Bash provides a number of keyboard shortcuts out of the box.
I'm not sure many people are even aware of this, based on the number of coworkers I've seen navigating entirely by left/right arrows and the delete key.
Bash has a rich set of movements like:
* alt-b to move back a "word",
* alt-f to move forward a "word"
* alt-d to delete forward a word
* control-w to delete back a "word"
* control-u to delete back to the beginning
* control-k to delete forward to the end

These are the ones I use the most -- practically every day, in fact!

Note how I used quotation marks around "word".
That's because I don't agree with how bash interprets that term, or rather how it interprets it _inconsistently_.
You see, moving back and forward and deleting forward obeys what I consider normal rules: punctuation delimits a word.
Deleting backwards, however, words on the basis of _whitespace_, not punctuation.

A few years ago, I ended up so fed up of this I went down the rabbit hole to figure out what could be done to fix it.
The solution, it turns out, is trivial: you just change the key bindings for whichever modes you care about.
As an aside, you might not be aware that bash has two built-in modes -- Emacs (the default) and Vim.

I now have the following in my `bashrc`:

```bash
stty werase undef
bind -m emacs "\C-w": backward-kill-word'
bind -m emacs "\e\C-w": unix-word-rubout'
```

This is frankly a bit arcane, so let's see what this means.
The command `stty` deals with _settings for the terminal_, hence the name.
This first line removes the binding it has for `werase`, or "word erase".
The second line states that control-w should use a deletion approach which respects punctuation, while the third line says that control-alt-w should use a deletion approach which respects only whitespace.
In this way, I retain the existing action (delete back to whitespace), but on a different binding; this is helpful when I have something like a URL that I want to delete.
The binding I use the most is the one which respects punctuation, and thus is symmetric with deleting forwards a "word".

There are tens of other bindings if you run:
```bash
bind -ls
```

I haven't played around with configuring many of the others, although partly that's because I'm happy with many of them.
You might find things that enormously improve your UX, so I'd encourage you to take a look!

---

* Eternal history settings
* Supercharging with fzf
  * Mention my preferred settings, e.g. colours for command types
* Using `bashrc.d/...` style to organise config
  * Allows for selectively disabling settings if unneeded
  * Keeps things separated so not just one huge blob of a file
* A few neat tricks like `^.`, `^x-u`, etc.
