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

## Principle 2 -- State Retention is Intentional

Following on from the previous principle, in stream processing it is always a conscious, **active** decision to record an event in state.

In other paradigms, particularly when we know we have the full dataset available, there is a temptation to hold onto everything.
This may be because the full dataset fits in memory, or it may be because we think intermediate results could be useful, so we do not want to dispose of them just yet.
How many Jupyter notebooks have you seen with cells scattered around with ideas and little experiments that are not used in the current process?

If we abuse this in a streaming context, however, we are liable to exploding our memory usage and running out of capacity.
As we can never be sure, in general, how many events we are going to see, we cannot assume we will have enough space to store everything indefinitely.
There are times we do need to hold onto data, but we need to be more careful and considered in when and how we do this to avoid the memory-hoarding problem.

When operating in a streaming context, it is common to use _aggregates_ instead of keeping all the raw events.
Perhaps we offload the raw events to some separate, persistent store.
Perhaps we leave them in whatever streaming storage we consume them from -- the New York Times stores their [entire history of articles in Kafka](https://www.confluent.io/en-gb/blog/publishing-apache-kafka-new-york-times/), for example.
Perhaps we hold onto a fixed amount of data (by time window or number of events) and discard these as their relevance expires.

<!-- Process one event at a time.  Might mean putting an event in state while we wait for more context. -->

## The Batch-Stream Continuum

We have touched upon "other paradigms", but if we are to speak of _stream_ processing then we should clarify what we are contrasting this with.
If this were the only viable approach, we would simply refer to it as "data processing", but that is not the case.

### What's in a Batch?

The antithesis of _stream_ processing is _batch_ processing, or _batching_ for short.
Put simply, batching is taking a chunk of data -- multiple data points -- and processing it all at once.
Plenty of real-world systems work in this way, from older banks processing financial transactions overnight to salary payment runs to stock-keeping reconciliations [[1](https://www.moderntreasury.com/learn/what-is-batch-processing)][[2](https://www.moderntreasury.com/learn/what-is-batch-processing)].
Shops "cashing up" at the end of the day is an example of a manually-run batch process.
In fact, plenty of computer algorithms work in an implicitly batch fashion, such as the sorting algorithms taught into schools and universities.

Batching is simple to understand, straightforward to implement, and offers a great deal of flexibility.
It is also likely to be more efficient on compute resources because it can benefit from locality of reference for memory accesses and vectorisation and reliable branch prediction for CPU instructions.

### Forward Thinking

However, that flexibility comes at a price.
Batch-oriented systems are prone to **look-ahead**, which is when the processing of data uses information which happened logically _after_ the data being processed.
This is commonly cautioned against in data science courses, when a system might be tested with data it was trained upon.
It is much easier to train a financial model for predicting end-of-day prices when the model has access to those very prices!

Put differently, look-ahead is when the interpretation of an event depends upon one or more subsequent events.
Care is needed in batch processing to prevent this from causing erroneous results -- it may or may not be acceptable to use look-ahead.
In streaming, however, it is necessarily a conscious decision to wait for further events, because those events have not been seen yet!

### A Paradigm Shift

Many descriptions of batching only discuss how it is focused on dealing with multiple data points at once.
They neglect to mention look-ahead and the ability to reorder and filter data down to only those of interest.
In that light, it is easy to see streaming as a specialisation of batch in which we deal with batches of just a single item.
Equally, batching looks like a generalisation of streaming in which we work on windows of more than one event at once.
This is not unreasonable, but it misses the key, differentiating factors.

Batch processing operates on a periodic or ad-hoc, manually-triggered schedule and treats data as a big blog that can be re-ordered and sliced up as desired.
Stream processing, conversely, works on a continuous timeline and treats events as an ordered sequence to be processed one at a time.
This is a fundamental difference in understanding and completely changes what operations are or are not applicable.

With that said, the previous description of overlap between batch- and stream-oriented systems is generally useful.
They do work in different ways, they do model problems differently, but there _is_ something of a continuum between them.
You may have noticed the use of terms like "stream-oriented" and "batch-focused", which is a tacit acknowledgement that real-world systems are not theoretical archetypes -- they borrow ideas from multiple approaches and obey some, but not necessarily all, the rules of any particular paradigm.
"Pragmatism over dogmatism" is a good mantra for people who like to get things done.

## Back to MLE

The team at MLE have realised that a streaming approach for billing would meet their needs nicely.
In fact, their API already works on the same principles!
It handles each request as it arrives, indepedently of any others, and holds onto the last X tokens of each conversation in a user session that expires after a period of inactivity.

They have decided to write the tuple of (timestamp, model ID, user ID) into a log store and maintain the count of requests made per user in the last calendar month.
This sum -- this aggregation -- is keyed by user, which provides plenty of scope for horizontal scaling.

## One Step at a Time

The team at MLE want to calculate usage over the period of a calendar month.
This requirement for interval-based results is a common one, and one that is not out of keeping with the approach of stream processing.

In streaming, we call these intervals **windows**.
There are three main types of windows we can apply:
* Tumbling windows
* Sliding windows
* Session windows

The first two are examples of **fixed interval** windows, whereas the latter is an **adaptive** window.

Tumbling windows are non-overlapping windows of a fixed duration, e.g. 10 seconds.
Non-overlapping means that an event appears in one, and only one, window.
You might have intervals for 12:00 to 12:15, 12:15 to 12:30, 12:30 to 12:45, and 12:45 to 13:00, and so on for example, with the upper limit being non-inclusive.
This is the best fit for billing use cases, because a customer should only be charged once for each request they make.

In the below example, events are represented by blue circles.
Events `a` and `b` are in the first window, `c` is in the second, `d` and `e` are in the third, and the fourth and final window is empty.

![tumbling window](./streaming_processing_tumbling_window.jpg)

Sliding windows allow for events to be used for more than one result.
The idea is that the start and end of the window gradually increment, whether triggered by new events arriving or wall-clock time.
Sliding windows are a good fit for metrics, where you might want to look at a value over the last X minutes/hours/days, not just this week or last week.

In the following example, the orange window includes events `a` and `b`, the yellow window includes `b` and `c`, the melon-red window has `c`, `d`, and `e`, the pink window shared `d` and e`, and the purple one contains only event `e`.
In this example, time moves forward and a new window is created for every event; this is one way to implement sliding windows.

![tumbling window](./streaming_processing_rolling_window.jpg)

Session windows start with an event and end when no event has been observed for some period of time.
For this to work, there needs to be some idea of a key to associate the events for a particular session.
Different sessions are obviously not aligned with one other because they have different keys.
This is a very flexible idea, and one that works for more event-driven requirements.
For example, session windows are useful for user sessions, timing out transactions, and defining event groups.

In the below example, there are four, non-intersecting session windows, each with their own events (blue circles).

![session window](./streaming_processing_session_window.jpg)

## State of Affairs

In talking about windows of events, we are implicitly assuming the ability to hold onto potentially many events and associate them in a group.
This is an example of holding **state**.
State is another way of saying "data", information that a program needs to hold onto in order to make future decisions.

We briefly discussed state earlier, in Principle 2, but let's go into a bit more detail now.
State management is one of the two hard problems of stream processing; the other is handling time correctly (we'll come back to this later).

A **stateless** function is one that does not use any information except its current inputs for processing.
A **stateful** one, by contrast, keeps track of additional information, be that from external data sources or previous inputs.
Anything which is keeping track of multiple events _must_ be stateful because events are independent, as discussed in Principle 1.
So, any kind of aggregate or window-based application will necessarily be stateful.

### Keeping Track Of It All

State might be held in memory in an application, but normally there will be some form of persistence for it.
This might involve a persistent event store or replayable data source (such as Apache Kafka), some kind of checkpointing of progresses, and/or an aggregate store.

Persistence is important in the event of application restarts, so that the application can pick up where it left off without missing anything.
Restarts can happen for many reasons, such as:
* Rolling out a new application version.
* Scaling up or down the number of application instances.
* Hardware failures.
* Application/system crashes, such as out-of-memory errors or logic bugs.
* Connectivity issues disconnecting an instance, meaning another instance needs to pick up the work.

Most of these are unforeseen circumstances that cannot be planned for explicitly -- the application has to be resilient to them by design.
Keeping track of what has been processed and what the results of that are is a key part of system **recovery** after a failure scenario.

### Seeing Double

When a failure does happen, there's a real risk of either missing events that should have been processed or re-processing events that have already been seen.

Consider a system that records periodic checkpoints, let's say every 5 minutes.
In this scenario, when a failure happens there could be up to 5 minutes' worth of events that have _already_ been processed, but which the application does not _know_ it has seen and therefore thinks are new.
Would it be safe for the application processes them again, i.e. there are no negative consequences except having to spend some time performing the reprocessing?
The answer will be specific to every system and the downstream data consumers.

What would happen if there is a bug in the network, perhaps a faulty router, and a message were duplicated some number of times?
This is a rare scenario for most companies, but when operating at scale such problems _can_ arise, and can be highly problematic if there is no handling for them!

Let's consider a different example -- an HTTP API.
While the API is down, no requests are recorded and saved into state, which is to say they will be _lost_.
When the API starts up again, it has no knowledge of those missed requests so cannot process them.
This system is entirely dependent on the client retrying for long enough for the API to be accessible again.
If we wanted to track the number of requests to each API endpoint, for example, we would be missing these data.

We might also miss data when using a message queue!
If the application acknowledges messages as soon as it retrieves them from the queue, but before it has actually processed them, then any messages in-process during a failure would not be retried on recovery.

All of these scenarios are about **delivery semantics**.
The Holy Grail of delivery semantics is **exactly-once** semantics, which is when an event which reaches a system will definitely be processed, but it will not be processed more than once.
This is an ideal we strive towards, but in reality we are approximating it.
Many real-world systems provide **at-most-once** semantics, **at-least-once** semantics, or a configuration parameter for the end user to decide.

At-most-once means there will be an _attempt_ to deliver each event, but some events may be missed.
This is acceptable for low-importance data such as usage analytics, when it would be helpful to have the information but it is auxiliary to primary purpose of an application.
Analytics in general can be impacted by many different factors leading to suboptimal data quality, such as firewalls and request blockers, flaky network connectivity, and unsupported devices.
In any case, analytics is about big-picture statements and general trends, not individual data points.

At-least-once means every message in the system _will_ be delivered, but it is possible it could be delivered two, three, or even more times.
This is a poor choice for payment systems, for example, when a user expects to be charged once for a product or service, not potentially multiple times!
With that said, this risk can be mitigated by applying **idempotency** -- defining actions in such a way that their re-application produces the same result.
For example, "add one" is a non-idempotent operation, whereas "set value to five" _is_ idempotent -- performing the update twice in a row will leave the value as five.
Idempotency can be achieved in different ways, but one common trick is to have a special key so that duplicated messages -- ones with the same key -- can be ignored.

Delivery semantics and approximating exactly-once delivery is an extensive topic, so any further exploration is left as an exercise for the reader.

## Transforming Streams

So far we have been talking about streams and stream processing without actually discussing what sorts of processing we can perform!

Recall that a stream is nothing more than a sequence of events -- timestamps associated with data values.
If a stream has a finite number of elements, we refer to it as **bounded**, and otherwise we describe it as **unbounded**.

The simplest thing we can do to a stream is to do nothing at all, i.e. to apply the identity transformation.
For more practical usage, we can apply a function to each event on the stream, outputting a new value for each event
This is conventionally known as a **map**/**select** operation.

If we have an event that contains sub-entries, we could expand this single event into multiple new ones.
This could be relevant for online retailers, for example, converting a basket of products into events per product.
Conversely, we could take multiple events and combine them together to output a single result.
This process is aggregation or **batching**.
If those batches are defined over a time interval, they become **windows**.

When we have batches of events, we do not have to produce a single output for the entire batch.
We could collect multiple events and reorder them, perhaps into a priority or key order, then re-emit all the events individually.

Applying the idea of producing fewer outputs than inputs in a different way, we can **filter** streams to items of interest, whether that is on the basis of a time range, a key, or anything else.
Filtering a stream implies discarding some of its events, but we could instead see this as **splitting** the stream and handling each branch of it separately.

If we can split streams, it seems only natural that we should also be able to **join** them as well.
Joining streams might mean applying a temporal merge, matching keys (within a time window or otherwise), concatenation (assuming at least one finite stream), or something other combining strategy.

Concatenating streams works like the below:
![stream concatenation](./stream_processing_concat.jpg)

Performing a temporal merge looks like this:
![temporal stream merge](./stream_processing_merge.jpg)

Matching keys, equivalent to a (windowed) inner join in SQL, looks roughly like the following.
Note that the magenta item from the top stream does not match with anything.
In practice, that might mean the event is not emitted or that it might be marked as a partial/incomplete result.
![stream key matching](./stream_processing_inner_join.jpg)

Of course, we are not limited to applying a single transformation to a stream.
So long as the output of a transformation is also a stream, we can compose it with other transformations to produce streaming **pipelines**.

### Relationship to SQL

If the above operations seem familiar, that is because they bear remarkable similarity to the things one can do in SQL.
This is not accidental -- the relational model is a model of _data_ transformation in general, and as such is not limited to a specific set of database management systems.
SQL, while ostensibly intended for this specific set of database systems, provides what has become a ubiquitous vocabulary for conveying the ideas of relational theory.
It is not the only model for data processing, but the concepts translate well enough to the streaming world.

Consider how the transformations outlined above correspond to SQL operations:
* map -- `SELECT`
* filter -- `WHERE`
* expand sub-entries -- `UNNEST`
* batch -- `GROUP BY`
* join -- `INNER JOIN`, `LEFT JOIN`, `OUTER JOIN`

So great is the allure of SQL as a conceptual basis that stream processing tools like Apache Kafka Streams and Apache Flink offer operators with naming heavily reminiscent of SQL terminology, and both even offer SQL interfaces: [ksqlDB from Confluent](https://github.com/confluentinc/ksql) and [Flink SQL](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/table/sql/overview/).

In fact, Confluent (the company formed by the founders of Kafka) takes the synergy between streams and SQL databases a step further.
Back in 2018, they published [a paper](https://www.confluent.io/blog/streams-tables-two-sides-same-coin/) on **stream-table duality**, the idea that streams and tables are interchangeable manifestations of the same, underlying resource.
Much like matter and energy or waves and particles in the world of physics, this is a unifying model for computation.

### Same Difference

Thus far we have been talking of streams as if they all look the same and compose neatly together.
This has been a convenient simplification.
While it is not uncommon for streams to be comprised of homogeneous events -- events of the same type/structure -- it is perfectly possible for the events to be heterogenous.

This may be more complex for (de)serialisation logic to handle, but can also make streams more expressive and easier to work with from a semantic perspective.
As a simple example, consider multiple applications all writing to the same stream.
If the stream is required to be homogeneous, performing a version upgrade to the message format must be co-ordinated between all producers and consumers and any older messages purged or otherwise ignored.
Allowing different versions of a message schema on the same stream is a form of heterogeneity.

Whether to allow multiple types to be published to the same stream or to mandate them to be on different streams is an organisational and design decision.
If there is any ordering requirement or interplay between messages of different types, such as a customer account creation message and an order message specifying a customer ID, this favours multiplexing the message types onto the same stream.

## Back to MLE (again)

The engineers at MLE have learnt about state management in streaming contexts and the idea of stream homogeneity.
They have decided to use a single message schema for usage tracking for the time being with a single stream for usage messages.
They do not need to worry about user IDs being used before they have propagated all the way through the system because bills are only sent at the end of the month, so small amounts of latency do not present a serious risk.
From the perspective of usage tracking, user ID is purely a correlation ID and holds no further semantics.

As users should only be charged one for each request, they do not want to risk at-least-once semantics, but they also want to make sure users are billed appropriately, otherwise they risk losing money -- serving large ML models is not cheap!
They are aiming for exactly-once semantics, but will err towards at-least-semantics with the guardrail of idempotency provided by request IDs.
This way, if the system somehow duplicates a message then users will not be charged twice, but if a user resends a request then it a fair reflection of their usage to count it.
In the future, they will implement response caching and use a hash of the request content as an idempotency key to reflect the fact cached responses do not incur inference costs.

Their processing pipeline involves grouping by user ID, followed by a simple tumbling window with summation as the aggregation function.

<!-- I often think physical analogies are effective for reasoning about networks. -->
<!-- Horses and riders -->

<!--
  * Notions of time -- event time, processing time
  * Time moves forward, strictly
  * Conscious decision to hold onto state -- not accidental like in batch
  * Events are handled independently -- we simply cannot know if another event will ever arrive
    * May need to defer processing until some later event has happened, e.g. in approximating transactions

  * Systems for streaming -- obviously Kafka is a popular one, but it's not the only one

  * Ultimately, we don't want to hold onto things forever BUT we may need to, which blocks processing

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
