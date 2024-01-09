---
title: "Seldon Core v2 Deep-Dive---Hodometer"
tags: seldon seldon-core-v2
---

Hodometer is an optional component of Seldon Core v2 responsible for collecting anonymous usage metrics.
The name comes from the [ancient device](https://en.wikipedia.org/wiki/Odometer) for measuring distance, familiar in cars as an _odometer_, because it's all about keeping track of your mileage!

Let's consider how metrics were handled in Core v1, why we opted for a different approach in Core v2, and how Hodometer actually works.

## Spartakus in Core v1

Spartakus was an open-source project created in 2016 by Tim Hockin as part of the larger Kubernetes (k8s) work.
It was designed, in its own words, for "collecting usage information about Kubernetes clusters."

Two notable points about its design were that it explicitly _did not_ collect personally identifiable information (PII) and that it was an optional add-on with no impact on the running of k8s itself.
In order to provide anonymity, the cluster ID was under the user's control and (generally) randomly generated, meaning it would change with every new deployment.
As we'll see, these design decisions influenced the design of Hodometer as well.

Despite being intended for use by the k8s developers, Spartakus supported running against one's own data collection endpoints.
Out of the box, it had support for pushing metrics to Google's BigQuery, HTTP endpoints accepting JSON documents, and the local file handle `STDOUT`.
This made it easy enough to adopt for Core v1, where it's been powering the metrics ever since on monthly active nodes and so on published by Seldon.
For details on enabling Spartakus for Core v1, please refer to the [official documentation](https://docs.seldon.io/projects/seldon-core/en/latest/workflow/usage-reporting.html).

While convenient in the sense that it had already been written and made collecting _some_ metrics straightforward, Spartakus wasn't an ideal tool for application usage monitoring.
For a start, the project was deprecated and archived in 2019.
This led to the creation of the open-source [i-am-spartakus](https://github.com/SeldonIO/i-am-spartakus) repository a few weeks later by Seldon, to retain the project in maintenance mode.
Plenty of projects are archived, however, and maintaining a fork of something stable isn't much of a burden.
The larger problem with Spartakus was that the metrics it collected made sense for k8s, but not necessarily for other applications.
For example, the number of nodes in a cluster has no relation to how many ML deployments or models are on it, or what hardware resources those are consuming.
It also doesn't provide any information on which version of Core has been installed, or anything else that's application-specific.
Spartakus does support some custom data in the form of [extensions](https://github.com/kubernetes-retired/spartakus/tree/master/docs#extensions), but this is static information.
In any case, users may not even want to share all the data on nodes in a cluster that Spartakus collects by default.
To put it concisely, Spartakus collected lots of data that _wasn't_ of interest but didn't collect lots of data that _was_ of interest!

---

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
