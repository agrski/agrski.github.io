---
title: Polybar & Pipewire --- A Practical Exploration of Modern Linux Audio
tags: linux polybar pipewire audio alsa pulseaudio
---

I recently upgraded by laptop from Ubuntu 22.04 through 24.04 to 24.10.
Between those two LTS releases, Ubuntu changed from PulseAudio to Pipewire as their default audio server implementation <a name="ref1", href="#fn1">[1]</a>.
This is a reasonable decision in itself, but as often happens during OS releases, it broke some of my custom setup!
We'll cover what broke and why, explore how I went about fixing it, and finally consider how the situation could be further improved.

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
-->

## Footnotes

<a name="fn1" href="#ref1">[1]</a> This change happened in Ubuntu 22.10, Kinetic Kudu: [https://changelogs.ubuntu.com/changelogs/pool/main/u/ubuntu-meta/ubuntu-meta_1.486/changelog](https://changelogs.ubuntu.com/changelogs/pool/main/u/ubuntu-meta/ubuntu-meta_1.486/changelog)
