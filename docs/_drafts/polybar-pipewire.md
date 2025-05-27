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

## Finding the binding

With the discovery of `wpctl` as the de facto shell utility for interacting with the Pipewire ecosystem, my immediate problem was solved!
I could change my earlier, `pactl`-based i3 key bindings to the following:
```ini
bindsym XF86AudioRaiseVolume exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%+
bindsym XF86AudioRaiseVolume exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-
bindsym XF86AudioMute exec --no-startup-id wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
```

Grand, my function keys work again.
As my Polybar config was using the [ALSA module](https://github.com/polybar/polybar/wiki/Module:-alsa) for audio information, that was actually working too.
It correctly allowed me to adjust the volume with the mouse scroll wheel and mute it by clicking the status-bar icon.
However, I realised it wasn't detecting the use of headphones to change the icon, and the audio level didn't seem to be the same as what `wpctl` was reporting.
The module documentation says it should not be used if PulseAudio is in use, so it probably wasn't the right thing to use in the first place.
There is also a [Pulse module](https://github.com/polybar/polybar/wiki/Module:-pulseaudio), but this doesn't seem to expose any settings for speakers vs. headphones and by default it assumes that `pavucontrol` is installed and available.
Both modules are predicated on _polling_, meaning that either changes are slow to be displayed or there are going to be a lot of wasted CPU cycles.
Neither module seemed quite right to me...

<!-- check this -- reload ALSA module, check if no headphones icon & if vol. levels mismatched with wpctl -->

## Join the (third) party

As Polybar is quite a mature project by this stage, it seemed only natural that it should have a module that works with Pipewire already.
While it has in-built modules for both ALSA and Pulse, there isn't a provided alternative for Pipewire, unfortunately.
Although mildly disappointing, this was not too worrying overall as Polybar has support for custom modules, and there is even an official collection of third-party ones [available on GitHub](https://github.com/polybar/polybar-scripts/tree/master).

Scanning through that `polybar-scripts` repo, I did find the relevant-looking [pipewire-simple](https://github.com/polybar/polybar-scripts/tree/master/polybar-scripts/pipewire-simple).
The only problem is that this relies upon the PulseAudio utilities `pactl` and `pamixer`!

Surely someone must have tried this before me, even if they didn't integrate it into `polybar-scripts`?!
Off to a search engine to find out...
That is when I came across [this Reddit thread](https://www.reddit.com/r/Polybar/comments/mt4f0r/just_switched_to_pipewire_for_audio_is_there_a/), which a few people had helpfully responded to describing their solutions.
The creator of that `pipewire-simple` module, `vtrac` on Reddit and `victortrac` on GitHub, had linked their solution, both as a Gist and then when it was integrated into the official extensions repository.
There was also a link to `marioortizmanero`'s [polybar-pulseaudio-control](https://github.com/marioortizmanero/polybar-pulseaudio-control), which is referenced by `polybar-scripts`, noting that it should work so long as the `pipewire-pulse` compatibility layer was present.
Unfortunately for me, neither of these solutions removed the dependency on Pulse tools, so it looked as if I would have to take matters into my own hands!

## "I did it my way"

Sometimes the answer is that you just need to Do It Yourself.
I'd never written a Polybar module before, so this would be fun.

The end result of my efforts is available as a BSD-licensed GitHub repo: [polybar-pipewire-wireplumber](https://github.com/agrski/polybar-pipewire-wireplumber).
This section is going to explain how I got there, so feel free to dip into the code to follow along if you'd like!

There were multiple problems to be overcome, so let's talk through them one by one.

### The first step

Having never written a Polybar module before, the first thing to figure out was how to actually go about writing and using something that would work locally, just for me.
I wasn't worried about open-sourcing anything back to the community quite yet.

The [polybar-scripts repo](https://github.com/polybar/polybar-scripts) offered some snippets of advice, but it was mostly those aforementioned existing modules, `pipewire-simple` and to an extent `polybar-pulseaudio-control`, which provided helpful templates and indications of how to go about things.

The key idea is that you define a script, probably under `~/.config/polybar/scripts`, that will be referenced by your custom module definition.
You then add that Polybar module definition --- it should probably go under `user_modules.ini` but will equally be detected from `modules.ini`.
Finally, this can be referenced in `config.ini`; for me, my audio module is called simply `pipewire` and is placed in `modules_right`.

Each custom module needs a _type_, with the simplest probably being `type = custom/script` to invoke the script from wherever you have saved it.
Such scripts will be invoked periodically according to the `interval` module parameter, i.e. updates are provided by **polling**.

[As pointed out](https://www.reddit.com/r/Polybar/comments/mt4f0r/comment/i5qaf21/) by Reddit user `Decvai` on the previously mentioned thread, it's possible to replace polling with Polybar hooks and IPC.
This requires `enable-ipc = true` in your Polybar `config.ini` and to define the module type as `custom/ipc`, but it should be more efficient.
I'd imagine most people are not _constantly_ adjusting their volume level or switching between different output devices, so using IPC should be more efficient and potentially more responsive, as Polybar will not wait for the polling `interval` before re-evaluating the module's output.
The [official docs on IPC modules](https://github.com/polybar/polybar/wiki/Module:-ipc) are the best resource for understanding how to use this feature, but the short of it is that you define hooks which call commands/scripts when an event occurs.
An event could be a mouse action on a status bar, or it could be a message sent through `polybar-msg`.

I opted for the latter choice, the IPC approach.

### The ups and downs of volume controls

The most obvious functionality to support is the ability to display the _current_ volume level.
Beyond that, being able to adjust the volume level with mouse actions (scrolling up or down) would provide parity with the existingaudio modules.

The volume adjustments were simple to implement, as they look almost identical to the script in `pipewire-simple`, except with `wpctl` commands in place of `pactl` ones.
In fact, we know exactly what the volume up/down and mute toggle commands should look like because we saw them before when we fixed the i3 key bindings!
These can be found [here](https://github.com/agrski/polybar-pipewire-wireplumber/blob/61011719ed9546f088a085af5eac9aa945502bea/pipewire.sh#L6-L12) in my `pipewire.sh` script.

I'll just mention that the interface to `wpctl` is very similar to `pactl` for these commands --- `set-mute ... toggle`, `set-volume` instead of `set-sink-volume`, etc.
This made them fast to figure out.
The trick about device aliases (`@DEFAULT_AUDIO_SINK@`) was something I'd seen previously with `pactl`, but it was the [WirePlumber Arch wiki](https://wiki.archlinux.org/title/WirePlumber#Keyboard_volume_control) which provided the correct identifier to use.

Querying the current volume level is slightly trickier, but only slightly.
If you run `wpctl get-volume ...`, you'll see an output like:
```
Volume: 0.45
```

This has the necessary information, but not quite in the right format.
WirePlumber returns the volume as a unit-normalised quantity, i.e. in the range 0-1 rather than as a percentage from 0-100.
Unfortunately, there is no toggle for `wpctl` to change the output format.
In fact, it has no options whatsoever (at least not at the time of writing):
```bash
wpctl get-volume -h
```
returns:
```
Usage:
  wpctl [OPTION…] COMMAND [COMMAND_OPTIONS] - WirePlumber Control CLI

Command: get-volume ID
  Displays volume information about the specified node in PipeWire

Help Options:
  -h, --help       Show help options
```

My module [accounts for this](https://github.com/agrski/polybar-pipewire-wireplumber/blob/61011719ed9546f088a085af5eac9aa945502bea/pipewire.sh#L19) by using `sed` to discard the prefix up to and including the decimal separator, `.`:
```bash
wpctl get-volume @DEFAULT_AUDIO_SINK@ | sed 's|^.*0\.||'
```

In fact, `wpctl get-volume` also returns information about the mute status of the output device, so I [handle this](https://github.com/agrski/polybar-pipewire-wireplumber/blob/61011719ed9546f088a085af5eac9aa945502bea/pipewire.sh#L20-L21) by splitting out the volume and mute information using some more regular expression matching:
```bash
local volume=$( echo ${volume_and_mute} | sed 's|^\([[:digit:]]\+\).*$|\1|')
local muted=$( echo ${volume_and_mute} | grep -o MUTE )
```

At this point, the module was pretty much functional at a basic, acceptable level.
Well, apart from needing to return its findings to Polybar...

### IPC --- It's Pretty Contorted

The bash script `pipewire.sh` can return a string which Polybar will capture and use as output in its status bar(s).
This is fine for purely informational content, but it's rather awkward for formatting.

Polybar generally encourages formatting to be done by users configuring their modules, rather than by module developers.
The `polybar-scripts` [contributing advice](https://github.com/polybar/polybar-scripts/blob/master/CONTRIBUTING.md) states to use placeholders for icons, remove colours unless they perform some special function, and avoid being opinionated on the shell even, for example.
Polybar modules expose various [formatting options](https://github.com/polybar/polybar/wiki/Formatting) and the [wiki acknowledges](https://github.com/polybar/polybar/wiki/Fonts) that different fonts support different icon sets.

Unfortunately, `custom/ipc` and `custom/script` module types do not offer much in the way of outputting formatting controls.
Whereas a module like [battery](https://github.com/polybar/polybar/wiki/Module:-battery) allows for different formatting based on charging status and battery percentage with various formatting tags, even going so far as to have (dis)charging animations, using IPC pretty much limits the options to the script output itself and the ability to adjust the formatting based on which hook was called.
For our purposes, which script was called is irrelevant as we always return the _current_ audio status information.

At a basic level, that's okay as we can add in an icon to indicate that this is a volume module.
What happens if we'd like to take into account things like the mute status --- how can we change the icon to reflect this additional context?
We can't call another script and we can't define some additional processing logic within the Polybar module, which isn't particularly helpful.

All is not lost, however, because surely we can persuade the script itself to take on the responsibilities of formatting?
We can certainly include an icon in the output, assuming it is supported by whatever font is in use by Polybar, and we can select that icon depending on whether the output device is muted or unmuted.
If only it were _quite_ that simple...

### The font of all ~knowledge~ discrepancies

It is not uncommon to use different fonts for different purposes within the same Polybar bars.
In fact, the wiki has plenty of examples that show different fonts in use, such as [here](https://github.com/polybar/polybar/wiki/Fonts) and [here](https://github.com/polybar/polybar/wiki/Configuration#bar-settings).
The idea is that you might want one font for text but to use another one for icons because the first one doesn't support all the icons you'd like to use, or you might even need multiple icon fonts because different groups of icons have different sizes that need to be normalised, or they need different vertical shifts to be aligned.
Another problem is that some Nerd Fonts [do not render properly in Polybar](https://github.com/polybar/polybar/issues/991) and experience issues with overlapping or cut-off characters; this is something I was experiencing myself and can be fixed by using a suitable mix of fonts.

Now, if you have three or four or five fonts that _might_ be used to render any given icon, how does your (shell) script indicate which one is the right one?
Normally this would be something you define in your Polybar _config_, but there is an escape hatch: Polybar supports [format tags](https://github.com/polybar/polybar/wiki/Formatting#format-tags) using [lemonbar notation](https://github.com/LemonBoy/bar#formatting).
This allows you to set and reset the font using index-based notation, and even to insert colour declarations!

As a brief aside, if you need to install fonts on Linux and they are not available through your system package manager, the process to do this manually is straightforward:
0. Download the font package and, if necessary, unzip/decompress the bundle.
    For example, I downloaded `IosevkaNerdFontMono-Regular.ttf` as an uncompressed file.
0. Move the font definition files to a recognised location; I opted for `~/.local/share/fonts`:
    ```bash
    mv ~/Downloads/IosevkaNerdFontMono-Regular.ttf ~/.local/share/fonts
    ```
0. Refresh the system font cache (`-v` is optional):
    ```bash
    fc-cache -rfv
    ```
0. Check the desired font has been detected:
    ```bash
    fc-list : family | grep -i 'iosevka' | sort | uniq
    ```
    For me, this returns the following, indicating that installation was successful:
    ```
    Iosevka Nerd Font,Iosevka NF
    Iosevka Nerd Font,Iosevka NF,Iosevka NF Medium
    Iosevka Nerd Font Mono,Iosevka NFM
    ```

Returning to my custom Polybar module, [this line](https://github.com/agrski/polybar-pipewire-wireplumber/blob/61011719ed9546f088a085af5eac9aa945502bea/pipewire.sh#L51) is responsible for inserting font information.
Specifically, it is choosing font 3 (using [one-based indexing](https://github.com/polybar/polybar/wiki/Formatting#font-t)) for the icon then resetting to the default font for the textual volume level.

<!-- TODO: mention updating i3 to call Polybar hooks for volume adjustments -->

### Eavesdropping on current events

With the core functionality out of the way and a better understanding of how to work with Polybar, I wanted to add the ability to change the status bar icon depending on whether headphones were connected or not.
Put differently, I wanted the icon to reflect whether headphones or speakers were the active output device.
This turned out to be non-trivial, as some of the information was hard to come by without the PulseAudio utilities.

The first thing to figure out was how to detect if headphones are plugged in, or equivalently when they are plugged or unplugged.
Much of the advice online revolved around the venerable Pulse tools, and many other suggestions made use of DBus.
The former was obviously unconscionable given I wanted to avoid installing the Pulse stack, and the latter seemed awkward to do without invoking a full-on language instead of a shell script (and probably a bit more complexity to hook into DBus).
It wouldn't be impossible -- there's a Python DBus library, for example -- but it seemed inconvenient, especially if it meant having to control an environment and dependencies for something aiming to reduce its footprint...

Further searching indicated ACPI (Advanced Configuration and Power Interface) <a name="ref3" href="#fn3">[3]</a>  might do the trick.
On Linux, there are the executables `acpi_listen` and `acpid`.
The former is an interactive program which, as the name suggests, listens for events in the ACPI subsystem and logs them to STDOUT.
The latter is the ACPI daemon process, which is a bridge to user-space from kernel-space.
To quote the man-page, it is:
> designed to notify user-space programs of ACPI events.

_As an aside, Tim Hockin was involved in writing both `acpi_listen` and `acpid`.
I recognised the name as being involved in the Kubernetes, the container orchestration platform.
In particular, he wrote [Spartakus](https://github.com/kubernetes-retired/spartakus), a telemetry tool for Kubernetes which provided some inspiration for [Hodometer](https://github.com/SeldonIO/seldon-core/tree/a772f167229f08a13fe91c527d46e28a96399ce1/hodometer), a tool I wrote for Seldon Core v2.
The world can be a surprisingly small place at times!_

The way `acpid` goes about its duty is by reading configuration files under `/etc/acpi/events` and performing the actions defined for each event filter in these files.
The configuration format is straightforward:
```
event=jack/headphone.*
action=/path/to/command-or-script "arg1" "..."
```

The `event` is a filter for ACPI events, defined as a regular expression, which could be more or less specific:
```
# Capture headphone being plugged in or unplugged, e.g. to change an icon.
event=jack/headphone.*
# Respond to plug-in events, e.g. to automatically adjust EQ (equalization).
event=jack/headphone HEADPHONE plug
# Respond to unplug events, e.g. to pause a media player or mute the new default device.
event=jack/headphone HEADPHONE unplug
```

The `action` is then some command or invocation that should be performed whenever the event rule is triggered, called via `/bin/sh`.
There can be multiple actions for a single event or multiple events that fire a given action, so it is quite a flexible system.

<!--
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

<a name="fn3" href="#ref3">[3]</a> ACPI was developed as a collaboration between Intel, Microsoft, and Toshiba for controlling and reporting information on various hardware components, according to [the UEFI specification](https://uefi.org/sites/default/files/resources/ACPI_6_3_final_Jan30.pdf).
The same specification indicates support for Linux and Windows, among other OSes, in table 5-186.
