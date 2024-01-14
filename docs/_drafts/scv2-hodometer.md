---
title: "Seldon Core v2 Deep-Dive---Hodometer"
tags: seldon seldon-core-v2
---

Hodometer is an optional component of Seldon Core v2 responsible for collecting anonymous usage metrics.
The name comes from the [ancient device](https://en.wikipedia.org/wiki/Odometer) for measuring distance, familiar in cars as an _odometer_, because it's all about keeping track of your mileage!

Let's consider how metrics were handled in Core v1, why we opted for a different approach in Core v2, and how Hodometer actually works.

## Spartakus in Core v1

[Spartakus](https://github.com/kubernetes-retired/spartakus/tree/master/docs#extensions) was an open-source project created in 2016 by Tim Hockin as part of the larger Kubernetes (k8s) work.
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

## Designing Hodometer

Core v2 is a very different kettle of fish from Core v1, and the sorts of metrics we'd want are no exception.
Core v2 has multiple Kubernetes custom resources --- models, servers, pipelines, and experiments --- compared to just single one in Core v1 --- deployments.
It furthermore introduces fundamentally new features in the form of multi-model serving (MMS) and over-commit.
When you consider these things, it should be clear that the metrics for Core v2 will want to be correspondingly more granular and domain-focused.

While Spartakus didn't provide ideal metrics even for Core v1, it did make a number of sensible design decisions to use as a basis for implementing usage metrics in Core v2.
Specifically, these were:
* Anonymity via randomised, non-persistent identifiers.
* Explicitly no collection of PII.
* Non-integral component.
* Low periodicity reporting of metrics.
* Push-based reporting of metrics.
* Flexibility to configure additional metrics receivers.

Being an optional part of the system means Hodometer can safely and easily be enabled or disabled without any impact.
It is only reliant on (some of) the APIs exposed by the scheduler and some minimal information from k8s about the server version.

Not collecting any PII or otherwise potentially sensitive information avoids having to deal with things like the UK's GDPR regulations.
That's convenient from a business perspective, but it's also about building trust with end users that Hodometer isn't trying to spy on them.
The metrics Hodometer defines are about understanding adoption, seeing how widely particular versions are in use and if users upgrade quickly or if old versions still need to be supported, and about understanding if features are being utilised.
Do users actually make use of MMS?
If so, to what extent are they employing over-committing of servers?

The use of ephemeral cluster IDs benefits anonymity, but was also done for simplicity of implementation.
The user can specify a cluster ID which Hodometer wil read from its environment, but if none is provided it will simply generate a new one at random.
In this latter case, whenever Hodometer restarts it will report metrics as being from a new "cluster".
That's a bit unhelpful for anyone wondering what the average age of clusters is or trying to count the number of active clusters in a given time period, but makes installations simpler and can inadvertently prevent longitudinal collection on long-lived clusters.

Push-based metrics might seem like an odd thing to tout as a sensible design decision.
After all, Prometheus, one of the most popular metrics collection solutions, uses a [pull-based model](https://prometheus.io/docs/introduction/overview/) and justifies this briefly in its [FAQ](https://prometheus.io/docs/introduction/faq/#why-do-you-pull-rather-than-push?) and in more depth [in its blog](https://prometheus.io/blog/2016/07/23/pull-does-not-scale-or-does-it/).
In the case of Hodometer, however, the situation is very different.
While Prometheus wants to be aware of which services should be active and can employ service discovery, it would likely be very unpopular if an open-source tool were to have, or to need, these things to a third party.
In any case, it'd be rather impractical for the third party!
Instead, Core v2 is the active party and creates an outbound connection, which might be more acceptable from an administrative perspective than allowing inbound connections; if not, it can simply be disabled or blocked by a network policy.
By configuring the metrics receivers on the client side, it furthermore has the benefit that users can direct metrics to their own endpoints.

Low periodicity is likewise an unusual thing to desire --- lots of systems are about collecting all the metrics, all the time!
Prometheus collects aggregated metrics but is often configured with a scrape interval between 10 seconds and one minute and will commonly be capturing tens to hundreds of time series per target, while some other systems are event-based and therefore even more granular, collecting information on every single things that happens.
In contrast, Hodometer runs infrequently --- only once every eight hours [at the time of writing](https://github.com/SeldonIO/seldon-core/blob/d3502062bbbb18a08032201917ceea07e124be41/hodometer/cmd/hodometer/main.go#L31).
There are a few reasons for this.
First of all, it should impose an absolutely minimal burden on user's networks and hardware resources.
Many cloud providers charge network egress costs, and Hodometer shouldn't be consuming compute resources that could be better used by the user's processes.
Aside from that, more frequent usage metrics aren't necessarily very useful.
As the point is to provide an _indication_ of how Core v2 is being adopted and which features are (not) being used, this level of granularity is sufficient.
Whether someone spins up a handful of extra inference servers for a few hours between Hodometer's runs or creates a new version of a pipeline before removing the old one doesn't fundamentally change the scale of adoption.
Indeed, many of the metrics should be naturally slow-changing, such as the versions of Kubernetes and Core, or tend to oscillate within stable ranges, such as the number of servers deployed at any given time.
I should note that this is based on assumptions and previous experience rather than hard data, but the nature of the problem means that precise data would be difficult and potentially controversial to attempt to collect.
Sampled and/or aggregated data are always subject to missing data points and loss of detail.
In any case, the collected metrics are generally further aggregated and assessed to identify _trends_, so inaccuracies in any given sample are highly unlikely to be significant in the grand scheme of things.

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
