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

## The task at hand

When I updated my OS to a newer version, I expected i3 and Polybar to pick up their existing configurations and _just work_.
Unfortunately, it was not to be so.
The volume up/down/mute function keys were not having any effect, which was odd as I had the following bindings for them in my i3 config:
```ini
bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +3%
bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -3%
bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle
```

Those `XF86...` terms correspond to the key-codes for the function keys, and each line is saying to bind a particular key-press to a shell script that performs the appropriate action.
These scripts assume the use of `pactl`, which stands for "PulseAudio control", one of the suite of shell utilities provided for PulseAudio set-ups.

Well that was funny, because these had been working prior to the OS update...
The problem, obviously, was that `pactl` was no longer installed.
In itself, this would be straightforward to rectify --- just install `pactl` with:
```bash
sudo apt-get install pulseaudio-utils
```

(Yes, I still prefer typing `apt-get` and `apt-cache` to just `apt`.)

However, it seemed odd to me that this package had been removed and not reinstalled, so I decided to find out what was up with that.
A bit of searching online showed that Ubuntu had switched from PulseAudio to some thing called Pipewire.
Well, if the tools have changed then I should probably update my set-up to future-proof it and be compliant, right?
So I set off to find out how to work with Pipewire.

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
    * Update to use concise footnote syntax -- may need to explore footnote plugin for Jekyll to render this properly/nicely.
-->

## Footnotes

<a name="fn1" href="#ref1">[1]</a> This change happened in Ubuntu 22.10, Kinetic Kudu: [https://changelogs.ubuntu.com/changelogs/pool/main/u/ubuntu-meta/ubuntu-meta_1.486/changelog](https://changelogs.ubuntu.com/changelogs/pool/main/u/ubuntu-meta/ubuntu-meta_1.486/changelog)
