---
title: "Seldon Core v2 Deep-Dive---Hodometer"
tags: seldon seldon-core-v2
---

Hodometer is an optional component of Seldon Core v2 responsible for collecting anonymous usage metrics.
The name comes from the [ancient device](https://en.wikipedia.org/wiki/Odometer) for measuring distance, familiar in cars as an _odometer_, because it's all about keeping track of your mileage!

---

* Hodometer is for "measuring your mileage".
* Replacement for Spartakus in SCv1.
  * Can give a bit of history on this.
* Designed to be simple, even for people new to Go.
  * Easy to see what data is (not) being collected.
* Connections:
  * Show via diagram.
  * Connects periodically to SCv2 scheduler & k8s if enabled (check this).
  * Attempts to write collated, anonymous data to MixPanel.
    * This is obvious from the use of a MixPanel client in the `publish` file.
* Data is sent anonymously--identity based on random ID on start-up and reset on every subsequent start-up.
* Multiple levels of data collection enabled by flags.
  * Levels are supersets of one another.
  * Can show via diagram.
  * Explicit decision to allow users to set level of data they are happy sharing.
  * To disable entirely, simply disable/delete Hodometer.
    * How to best do this depends on the version of SCv2 in use--it more recent versions, flag in `SeldonRuntime`.
    * Give example, e.g. based on `k8s/helm-charts/seldon-core-v2-runtime/templates/seldon-runtime.yaml`.
