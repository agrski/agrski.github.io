---
title: Principles of Stream Processing
tags: streams architecture concepts
---

Stream processing is the idea of treating data as a continuous flow, rather than as a singular block.
The idea has been around for a while, but it has found mainstream adoption as a standard approach in the last five years or so.
Covering every facet and detail of this topic is beyond the scope of any single article, so I shall not attempt to do so.
Instead, this article will discuss the key concepts and challenges and aim to provide a foundation for further exploration.
Many things will only be covered at a high level, and many problems will be posed with only hints provided for possible solutions.

There are no silver bullets or sweeping generalisations to fall back upon; this is a topic of trade-offs.
The simple answer is that we need to understand the problem, understand the available solutions, and select the best option for each use case we encounter.

## Disclaimer

_This is by no means the first article to cover this material, nor is it intended to be the most comprehensive.
I am writing it to provide a basis for further discourse, as a set of principles to be referred back to in the future.
It is convenient, therefore, to state my own views on the matter and have material which I know will not change or disappear and, in doing so, leave a gap in understanding.

The content is informed by my own experiences and discussions, and loosely inspired by previous talks I have given at universities and workplaces on the subject._

## Introducing "Emily"

It is often easier to grasp new concepts with the aid of an example, so let's meet the fictitious company we'll be following along with to learn about stream processing: MLE Technologies Ltd.
MLE (pronounced "Emily") is a new ML/AI start-up, racing to catch up with the big players like OpenAI and Huggingface.
Their business model is focused on serving infrastructure: they host third-party and user-provided models on GPUs, and charge for the resources consumed.
The differentiating factor is that they will have adaptive pricing, meaning the price of hosting a model can change throughout the day.

As MLE has only just been founded, the pricing is even simpler.
They offer a pre-defined set of the best open-source models, and users pay for the number of API requests they make.
All the models are charged at the same rate.

### Billing Monthly

As requests are made to each model, MLE records the following details in a relational database (RDBMS):
* UTC timestamp
* User ID
* Model ID

At the end of each calendar month, they run a query against the database to count up how many requests were made by each user and send them a bill accordingly.
This might look like the following:
```sql
SELECT user_id, COUNT(*)
FROM dbo.api_requests
WHERE timestamp >= @month_start AND timestamp <= @month_end
GROUP BY user_id
```

Note that model IDs are recorded for each API request.
While pricing isn't affected by the model ID right now, the team at MLE want to be able to run analytics so they know which models are the most and least popular.
This will help them with provisioning enough instances of each model, and deprecating models that are falling out of popularity.

This isn't a very sophisticated system, but it works, it was fast to develop, and it's easy to work with.
Until a company has found good product-market fit, this is an expedient decision and one that many start-ups opt for in practice.

### Limiting Factors

While it is conventional to bill customers monthly, the finance team at MLE want a more up-to-date view on usage for forecasting demand and operational costs.
Sometimes the executives ask for the latest numbers just before board meetings and the data analysts have to run arbitrary queries on the fly.
This is fine for business purposes -- the analysts can pull the data they need -- but it can cause slow-downs on the database when it's already under load.

In fact, as the company grows and is seeing many more users each month, those end-of-month queries for finance and reporting are starting to become quite slow themselves and are affecting the responsiveness of the model API.
The problem, fundamentally, is that the database receives a big batch of work that is has to get through in one go -- it has a spiky workload.
Spiky workloads are not efficient, as you need enough resources to handle the spikes in a reasonable time-frame but are over-provisioned the rest of the time -- relational databases don't tend to like scaling up and down all the time.

### Harder, Better, Faster, Stronger

<!-- Add graphics indicating how each approach works -->
There are a few solutions to this that the engineers at MLE propose.
* One engineer recommends sharding the API requests by model, so different database instances are responsible for different models.
  This improves the fault tolerance between models, but slows down the end-of-monthly queries because they now have to query multiple instances.
* Another engineer suggests replicating the database to separate transactional and analytical workloads.
  This is a common strategy and it makes a big difference to responsiveness for the transactional side.
  However, replication isn't completely free and needs to be set up and monitored, not to mention risking some staleness of the data on the analytical side.
  In any case, this solution hasn't actually fixed the problem that the end-of-month queries generate big spikes of work and can still lock up ad-hoc analytics during that time.
* Partitioning or indexing by timestamp would help to speed up the queries, but likewise doesn't change that the end-of-month queries produce a spiky workload.
  Partitioning may also slow down queries over longer time periods, as data has to be fetched and collated from multiple instances;
  shuffling data adds overheads.
* The engineers then consider running the queries more frequently.
  Instead of waiting a full month, the queries are set to run every week, then the monthly queries just aggregate these weekly results.
  This is still a bit spiky, so the team reduces the frequency to daily counts with monthly aggregations.

## Honey, I Shrunk the Data

Let's take that last idea and extend it even further.
We could handle a day's worth of data, or an hour's worth, or even just a minute.
At the limit of precision for commodity hardware, we could handle the data for a single nanosecond.

This approach is taking us in the right direction, but is still fundamentally flawed.
There are many, many nanoseconds in a month and the vast majority of them will contain no data whatsoever for any given customer.
Of course, it would also be completely impractical to run a query against the database after every single nanosecond!
Rather than thinking in terms of decreasing time-steps, why don't we flip this round and instead think of what happens _within_ a time step at the limit?

What we're really trying to capture is an **event**.
An event comprises a point in time and some piece of information.
It is simply a description of something that happens, as the name suggests.
Events are the crux of stream processing and the related topic of event-driven design.

This might sound trivial -- it is a straightforward concept -- but the idea of events necessitates a paradigm shift.
Rather than conceiving of the world in fixed blocks of time, like a step-wise simulation, events model the dynamics of a system in real-time.
Events are the atoms of streaming systems, swirling through a void of empty time-steps.
They are the things we want to observe, the things that are interesting, the things that interact and change the state of the world.
By paying attention to the things that happen, as they happen, we can build far more responsive systems than would otherwise be possible.

## Principle 1 -- Independence of Events

One of the most important things to remember is that events are completely independent of one another.

This is fairly intuitive for events from different sources, such as two people sending requests to MLE's API.
However, it is also true of events from the same logical source.
Just because something happened does not mean something else _will_, even if it should.
Consequently, the presence of one event tells us nothing, in general, about the (non-)existence of other events.
In specific circumstances, we might be able to infer something due to mutual exclusivity or other enforced properties, but this is assuming the entire system is operating correctly.

Consider, for example, that a source S sends a message saying that it will send a further 10 messages but then goes down before it can send those other messages.
It might take seconds, hours, or days before S comes up again, if it ever does.
All we know was that, at some point, S was active and sent a message.

You might think that if multiple messages were sent from a single source, then at least we can tell the order in which they were sent.
Even this may not be true.
If a source S sends messages M1, M2, and M3 in that order, there are multiple possible outcomes.
We might receive M1 then M2 then M3, but we might equally receive M1 and M2, or M1 and M3 because the network dropped some messages due to a transient overload or a temporary failure in routing.
We might receive M3, then M1 and M2 because of a software bug or because M3 took a faster route through the network and managed to arrive first.

There are many things that can happen and many occasions when we need to use "should" rather than "will".
We will come back to these sorts of strange occurrences later, when we discuss reliable transmission.

The upshot of all this is that we need to handle events as they arrive, based on the information contained in that event.
Handling an event may mean deliberately putting it to one side and deferring processing, because there is insufficient information available right now to do anything more intelligent.
The crucial idea here is that it is a conscious decision to wait.
We will revisit this later as well.

<!-- I often think physical analogies are effective for reasoning about networks. -->
<!-- Horses and riders -->

<!--
  * Stream vs. batch
  * Notions of time -- event time, processing time
  * Time moves forward, strictly
  * Conscious decision to hold onto state -- not accidental like in batch
  * No lookahead, consequently, unlike in batch
  * Events are handled independently -- we simply cannot know if another event will ever arrive
    * May need to defer processing until some later event has happened, e.g. in approximating transactions
  * Systems for streaming -- obviously Kafka is a popular one, but it's not the only one
  * Streams can be homogeneous or heterogeneous
  * Streams can split, join, or potentially even be reordered
  * Windows -- fixed windows (tumbling, sliding) or adaptive (sessions, transactions, event groups)
  * Ultimately, we don't want to hold onto things forever BUT we may need to, which blocks processing

  * State & stream-table duality (link to Confluence docs here)
    * Encountered idea in Kafka Summit 2022
  * Persistence of state
  * Recovery of state

  * Handling error scenarios (reordering, delays, repetitions)
    * Key question: accept imprecision vs. require it?
    * Drop data
    * Recalculate windows
      * How to propagate knowledge of this?
      * Can downstream decisions be reversed?
      * Do we even know what downstream processes are and how they might behave?
    * Recalculate windows after-the-effect, e.g. in an end-of-day batch process when all available data has been collected?
    * Stop system and require human intervention?!
  * Detecting potential issues
    * Heartbeats
    * Sequence numbers (from source processes vs. from intermediate brokers)
    * Problem: how to key sequences if there are (potentially) multiple sources?
-->
