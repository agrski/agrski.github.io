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

<!--
  * Far too much info to cover in a simple blog post
    * Will provide some concrete info
    * Some subjects only touched upon/discussed at high level
    * Some problems posed, but there may be no silver bullets or simple solutions -- need to select best option for use case

  * Stream vs. batch
  * Notions of time -- event time, processing time
  * Time moves forward, strictly
  * Conscious decision to hold onto state -- not accidental like in batch
  * No lookahead, consequently, unlike in batch
  * Paradigm shift -- not processing chunks of time (however small) but rather individual events
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
