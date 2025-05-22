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

## Linux audio --- unravelling the (pipe)wires

The audio system on Linux is comprised of multiple, interacting parts.
Until now, I'd mostly glossed over how it worked and accepted there were some tools I could use: `amixer`, `pactl`, `pacmd`, `pavucontrol`, and so on.
Let's explore what the various terms you might hear about are and how they relate to one another.

At the core of consumer devices is **ALSA**, the Advanced Linux Sound Architecture.
It's a kernel module responsible for interacting with physical audio input and output devices, which it then exposes for other programs to use.
Some programs interact with it directly, such as VLC and Audacity, but it is important to note that ALSA assumes _exclusive control_ of hardware devices.
The `alsa-utils` package provides a set of tools for working with ALSA, such as the aforementioned `amixer` and `alsamixer`.
The [Arch wiki](https://wiki.archlinux.org/title/Advanced_Linux_Sound_Architecture) provides a detailed explanation, but the key thing to understand is that ALSA is a low-level interface for audio devices.

There's an alternative to ALSA called **JACK**, the recursively-named Jack Audio Connection Kit, which is more geared towards professional usage.
I'm mentioning it for completeness, but we're not going to discuss it much more.

For a long time, **PulseAudio** ("Pulse") was what end-user applications would interface with.
The key feature Pulse brings to the table is that it provides multiplexing --- multiple applications can use the same hardware devices, and they can even have different settings for it like per-application volume levels.
For example, you might be playing music from a native application or browser window while an email or instant messaging client wants to send notifications.
It potentially provides more user-friendly abstractions and tools for application developers than working directly with ALSA, and there are a number of helpful tools written around it.
For example, the `pulseaudio-utils` package includes `pacmd` and `pactl`, and `pavucontrol` (PulseAudio Volume Control) provides a GUI for adjusting volume settings, configuring output device, etc.
Essentially, the PulseAudio ecosystem has been the workhorse for end-user audio capabilities.

More recently, **Pipewire** has emerged as an alternative to Pulse <a name="ref2" href="#fn2">[2]</a>.
It implements a data flow-focused architecture based on processing graphs that provides much greater flexibility than Pulse's simpler approach.
For example, transforms such as equalisation (EQ) and compression can be inserted into a "filter chain", and a single source can be sent to multiple processing chains and, ultimately, sinks.
It aims to be a low-latency framework for not only audio, but also video and MIDI data, with extensibility being a [core design goal](https://docs.pipewire.org/page_design.html).
Pipewire's focus on low latency and highly configurable processing graphs makes it suitable not only for consumer applications but also for pro-audio.
To this end, it provides compatibility layers for both Pulse and JACK, and integrates with ALSA.
Essentially, Pipewire aims to be the all-in-one, centralised hub for multimedia applications that other audio subsystems can plug into.
For further reading, the [Arch wiki](https://wiki.archlinux.org/title/PipeWire) provides an overview of what Pipewire does and its extensions, while the [official project documentation](https://docs.pipewire.org/page_overview.html) goes into far more detail about its design goals, functionality, API, and so on.

The fact that Pipewire provides a compatibility layer for Pulse in `pipewire-pulse` and can communicate with ALSA through its `pipewire-alsa` package has some interesting knock-on effects.
For application developers and their users, they can keep using the Pulse API without needing to update anything --- there is continuity.
For end users, they can install all the same Pulse command-line and graphical utilities and these will work as they did before; there is no _need_ to seek out Pipewire-native alternatives.
As a consequence of this, there are relatively few dedicated, Pipewire-native applications in the same state of maturity as their Pulse-based predecessors.

While there is no _need_ to seek out alternatives, it feels anachronistic to me to be using a compatibility layer instead of dedicated tools that may be able to make better use of what Pipewire has to offer, if not now then in the future.
I am also against having more dependencies than necessary, so the idea of having to install Pulse utilities just to regain basic functionality didn't sit right with me.

**WirePlumber**

While Pipewire provides a daemon service for executing processing graphs, it is not responsible for _defining_ what these graphs should be.
That is the responsibility of a **session manager**, which is effectively a client of the Pipewire server.
There is a default session manager included in the `pipewire` package: **WirePlumber**.
Thus, whereas PulseAudio had `pactl`, Pipewire has `wpctl` (WirePlumber control).

WirePlumber exposes a number of properties and functionalities through `wpctl`, such as its overall session status and the ability to get or set the volume of a device.
Fortunately it supports similar syntax to `pactl` for referencing default devices:
```bash
# Pulse
pactl get-sink-volume @DEFAULT_SINK@
# Pipewire/WirePlumber
wpctl get-volume @DEFAULT_AUDIO_SINK@
```

Note how `wpctl` says `get-volume` because any node could have a volume level associated with it, not just sink nodes.
Note also how it complements this with `DEFAULT_AUDIO_SINK`, specifying the media format in the variable rather than assuming it in the command.

While in some ways quite informative, I have found `wpctl` frustratingly lacking in some of the details it exposes.
For example, I have not been able to determine whether the system believes headphones or speakers are the active device, which I would hope would be visible through a command like `wpctl inspect @DEFAULT_AUDIO_SINK@`.
We will revisit this limitation later.
If I am mistakenly maligning WirePlumber's capabilities and simply do not know where to look, I'd be interested to hear!

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

<a name="fn2" href="#ref2">[2]</a> Pipewire and Pulse are mutually exclusive: only one of these services should be active at once or they will conflict.
