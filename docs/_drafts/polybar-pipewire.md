---
title: Polybar & Pipewire --- A Practical Exploration of Modern Linux Audio
tags: linux polybar pipewire audio alsa pulseaudio
---

I recently upgraded by laptop from Ubuntu 22.04 through 24.04 to 24.10.
Between those two LTS releases, Ubuntu changed from PulseAudio to Pipewire as their default audio server implementation <a name="ref1", href="#fn1">[1]</a>.
This is a reasonable decision in itself, but as often happens during OS releases, it broke some of my custom setup!
We'll cover what broke and why, explore how I went about fixing it, and finally consider how the situation could be further improved.

## Off the beaten track

For a number of years, I have used a non-standard set-up.
That is to say, while I use a standard Ubuntu installation because I am familiar with it and it offers a number of conveniences, I prefer a minimal desktop experience.
While I'll admit that recent versions of Gnome are fairly slick and things work out-of-the-box, and that there are various Gnome tweaks that can be applied, I am very attached to having a tiling window manager.

Specifically, I use [i3](https://i3wm.org/) as a light but powerful, highly configurable tiling window manager (WM).
As i3 is a _window_ manager, rather than a full _desktop environment_, it doesn't provide as smooth an experience from the get-go.
That is something I've accepted and, over time, I've fixed many of the little irritations and inconveniences of not having a fully pre-configured environment.

As it's useful to have various pieces of status information, i3 has its own accompanying status bar: [i3status](https://i3wm.org/docs/i3status.html).
While I used this for a time, I migrated to the graphically richer and arguably more featureful [Polybar](https://github.com/polybar/polybar) a few years ago.
Polybar offers colourful themes, plenty of customisation options, and a large number of **modules** that display system information and/or enable interactions.
For example, there is a WiFi module, a battery module, and audio modules for ALSA (the Advanced Linux Sound Architecture) and PulseAudio, a more user-friendly layer written atop ALSA.
It is these latter ones we'll be most interested in for this article.

The key thing is that unlike using the pre-packaged, pre-configured Gnome installation that comes with Ubuntu, i3 and Polybar need to be configured to perform certain tasks.
Say, just for instance, understanding that pressing the volume up and down function keys should adjust the level of the default audio output ("sink")...

<!--
    * intro -- motivate problem -- new Ubuntu installation, installed i3wm & Polybar... but wait, my keyboard shortcuts aren't working!
    * background sections on ALSA, Pulse, Pipewire history, and compatibility layers
    * explain Polybar config/modules -- existing support for Pulse API, but didn't want to have to install these dependencies now pipewire is the default & wireplumber exists
    * reddit thread with some hints/suggestions
    * troubles with:
        * formatting (needed lemonbar tags)
        * detecting headphone (dis)connection -- ACPI listener
        * ACPI events (could gen. ACPI logs, fixed so no errors, but script not invoking IPC...)
        * fix using XDG_RUNTIME_DIR -- bit of a dirty hack, but it works
    * scraping /proc/asound as could not find where else to get info from
        * difficulty here with inferring correct statuses
        * include code snippets of bash & explain why broken
    * reference git repo & mention PR to polybar-scripts repo
    * conclude with goals for future -- improving robustness re. /proc/asound, adding colour formatting, ability to switch physical output device, etc.
        * suggested functionality for wireplumber to be more user-friendly (PW can do a lot, but WP can be a bit confusing and limited compared to what's already out there for PA)
-->

## Footnotes

<a name="fn1" href="#ref1">[1]</a> This change happened in Ubuntu 22.10, Kinetic Kudu: [https://changelogs.ubuntu.com/changelogs/pool/main/u/ubuntu-meta/ubuntu-meta_1.486/changelog](https://changelogs.ubuntu.com/changelogs/pool/main/u/ubuntu-meta/ubuntu-meta_1.486/changelog)
