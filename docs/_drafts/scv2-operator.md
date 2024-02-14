---
title: Seldon Core v2 Deep Dive---Operator
tags: seldon seldon-core-v2 architecture kubernetes
---

This article is part of a series about [Seldon Core v2](https://github.com/SeldonIO/seldon-core/tree/v2).

Seldon Core v2 is largely platform agnostic by design, with the **operator** existing to help integrate it natively into Kubernetes.
It's responsible for managing the Kubernetes resources related to Core v2, and acts as an adapter between those resources and Core v2's internal representation.

This article discusses the operator's role in more detail, including what those Kubernetes resources are, how it handles them, and how it was built.
Of particular interest is the operator's use of **meta-resources**, i.e. resources that define other resources.

You might be interested in this article if:
* You're interested in Seldon Core v2 and understanding its components in depth;
* You're considering writing an operator to integrate your own (open-source) project into Kubernetes; or
* You're interested in how Kubernetes resources and operators work and how to reason about them.

## Core v1 & Kubernetes --- a match made in heaven?

The original version of Seldon Core, now usually referred to as Core v1, was built specifically for Kubernetes.
At the time, Kubernetes was still a bit of an up-and-coming technology, promising portability for application workloads by abstracting the underlying infrastructure.
The idea was to enable widespread adoption by using a powerful, flexible container orchestration system while avoiding vendor lock-in to cloud providers.
However, this coupling runs deep, with various aspects of ML deployments understood in the form of Kubernetes resources and with no support for other container orchestrators.

Let's briefly cover how Core v1 manages deployments.
The sole Kubernetes custom resource is the [SeldonDeployment](https://github.com/SeldonIO/seldon-core/blob/46ef14e60e1f8c5b4c30320b06293e8b60f721fa/operator/apis/machinelearning.seldon.io/v1/seldondeployment_types.go#L226), which acts as a wrapper around all the functionality.
A `SeldonDeployment` comprises one or more [predictors](https://github.com/SeldonIO/seldon-core/blob/46ef14e60e1f8c5b4c30320b06293e8b60f721fa/operator/apis/machinelearning.seldon.io/v1/seldondeployment_types.go#L229), such as a main deployment and a shadow or canary.
Each predictor is an independently-deployed inference graph composed of so-called [predictive units](https://github.com/SeldonIO/seldon-core/blob/46ef14e60e1f8c5b4c30320b06293e8b60f721fa/operator/apis/machinelearning.seldon.io/v1/seldondeployment_types.go#L245) arranged in a tree structure.
Each predictive unit represents some [type of functionality](https://github.com/SeldonIO/seldon-core/blob/46ef14e60e1f8c5b4c30320b06293e8b60f721fa/operator/apis/machinelearning.seldon.io/v1/seldondeployment_types.go#L539) and can have zero or more [children](https://github.com/SeldonIO/seldon-core/blob/46ef14e60e1f8c5b4c30320b06293e8b60f721fa/operator/apis/machinelearning.seldon.io/v1/seldondeployment_types.go#L601), which are also predictive units.
Entire predictors are represented by Kubernetes pods, with each predictive unit deployed as its own container within that pod.
There is typically an additional container in each predictor's pod for an executor component, which acts as an **orchestrator** for how requests traverse that predictor's inference graph.
Note that components defined outside a predictor's graph, such as explainers, are deployed in separate pods.

In itself, this orchestrated workflow could be deployed in something other than Kubernetes -- the executor just needs to be able to communicate with each of its predictor's containers.
However, the way this executor is implemented, it demands to be in a Kubernetes environment.
We can see [here](https://github.com/SeldonIO/seldon-core/blob/46ef14e60e1f8c5b4c30320b06293e8b60f721fa/operator/apis/machinelearning.seldon.io/v1/seldondeployment_types.go#L539) that it wants to know the name of its `SeldonDeployment` (or `SDep` for short) and will [fail](https://github.com/SeldonIO/seldon-core/blob/46ef14e60e1f8c5b4c30320b06293e8b60f721fa/operator/apis/machinelearning.seldon.io/v1/seldondeployment_types.go#L539) to start up without this or the Kubernetes namespace.
Even were this not the case, the endpoints the executor uses to call predictive units may be the Kubernetes `Service` names created automatically by the Core v1 operator, for example when the executor (or "engine") is deployed separately from its predictor.
There are numerous code paths and configuration options around how routing and endpoints are configured, which would be deserving of a blog post in its own right!
The key thing here is that the executor is, to a greater or lesser extent, dependent on Kubernetes.

Zooming back out to Core v1 as a system, there are a number of other hard dependencies on Kubernetes infrastructure.
The operator not only creates deployments, but also services (internal network configuration) and auto-scaling rules in the form of KEDA or HPA resources.
Crucially, it handles advanced functionality, like traffic splitting for canaries and shadows, via service mesh configuration for Istio or Ambassador.
At a fundamental level, Core v1 is locked into this ecosystem.

## Core v1 & Kubernetes --- a tale of Icarus?

In the intervening time, Kubernetes has proven itself to be a popular and capable, if complex, technology.
The goal of Seldon Core is to make deploying and managing ML workloads simple and intuitive, but exposing users to the complexities of Kubernetes doesn't feel like a great way of achieving that.

The first hurdle for any prospective user of Core v1 is to set up a Kubernetes cluster.
In itself, that's a pretty big hurdle!
While users may already have Docker or an alternative container solution, they'd still need to select and install a Kubernetes provider like `kind` or `k3s`.
There's an [Ansible setup](https://github.com/SeldonIO/seldon-core/tree/2712c4204bf8146015435e01d23938899bc693a5/ansible) provided for convenience, but this means _yet another_ tool to install and learn before properly getting started.
It's worth mentioning that those Ansible scripts are not intended for production use (as stated in the accompanying README), so users might not feel comfortable having to invest more heavily in something they know they'll need to redo later.

With installation out the way, users need to be reasonably familiar with Kubernetes in order to have visibility into their deployments and any dependencies.
Having spent a few years as a heavy Kubernetes user on the application side, I'm pretty comfortable navigating through those layers of resource definitions, events, and logs, but that's a lot to ask of someone who just wants to run a couple of models and build up to more complex pipelines.
Why should they have to be aware of all these incidental levels of complexity to figure out where their model's logs are?

The definition of an `SDep` is a bit involved, even once someone is comfortable with the base Kubernetes types.
It's a large, complicated CRD (custom resource definition) full of embedded (partial) specifications for pods, containers, and services.
Add on to that various labels, annotations, resource requirements, service accounts, endpoints, probes and progress deadlines, and storage initializers.
Those are there to allow high levels of configuration and customisability, but they're allow predominantly operational concerns with little relevance to ML concepts.
Imagine being seated at a restaurant and given a menu awash with choices of culinary accoutrements, pots and pans of different sizes and materials, and various condiments.

This is a little hyperbolic and [the docs](https://github.com/SeldonIO/seldon-core/blob/2712c4204bf8146015435e01d23938899bc693a5/doc/source/workflow/quickstart.md#productionise-your-first-model-with-seldon-core) show a basic `SDep` specification can be quite concise (shown below).
With that said, even this basic example forces the user to be aware of concepts like predictors, a graph structure, and model runtime implementations.

```yaml
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: iris-model
  namespace: model-namespace
spec:
  name: iris
  predictors:
  - graph:
      implementation: SKLEARN_SERVER
      modelUri: gs://seldon-models/v1.16.0-dev/sklearn/iris
      name: classifier
    name: default
    replicas: 1
```

The [very next example in the docs](https://github.com/SeldonIO/seldon-core/blob/2712c4204bf8146015435e01d23938899bc693a5/doc/source/workflow/quickstart.md#wrap-your-model-with-our-language-wrappers) swaps the simple definition in the `graph` field for one in `componentSpecs` with different attributes.

```yaml
apiVersion: machinelearning.seldon.io/v1
kind: SeldonDeployment
metadata:
  name: iris-model
  namespace: model-namespace
spec:
  name: iris
  predictors:
  - componentSpecs:
    - spec:
      containers:
      - name: classifier
        image: sklearn_iris:0.1
  - graph:
      name: classifier
    name: default
    replicas: 1
```

There's a degree of simplicity in having a single YAML manifest that defines an entire, potentially complex deployment, but I'd argue it also makes it hard to see the wood for the trees.
Is it really beneficial to intermingle domain and operational concerns to such an extent?

What happens when you want to roll out some changes to your inference graph?
Perhaps you've just come up with the v2 of a model and you're excited to try it?
Maybe you're adding an auxilliary component like a post-processor or cache?
Well, Core v1 is going to decide that your deployment spec has changed and that it needs to roll out a new one.
Part of the issue is that the inference graph is _hard-coded_ into the executor via an [environment variable](https://github.com/SeldonIO/seldon-core/blob/46ef14e60e1f8c5b4c30320b06293e8b60f721fa/executor/predictor/utils.go#L29) or a [file](https://github.com/SeldonIO/seldon-core/blob/46ef14e60e1f8c5b4c30320b06293e8b60f721fa/executor/predictor/utils.go#L50).
Now you have to wait for your _entire inference graph_ for that predictor to start up in a new pod, even if just one, single model URI was changed.
Wouldn't it be nice if only the affected containers were restarted, or even models in a container were updated instead?

None of this has been considering the impact of dependencies.
There are a number of integrations for Core v1, some of which are Kubernetes-native and thus aren't supported in other environments.
Prime examples are service meshes like Istio and Ambassador, and Knative Eventing and Serving.
These can also be polarising, and what happens when users want an alternative or they reach end-of-life?
While it's nice to have integrations for extra functionality, it can be frustrating to be locked into opinionated choices.
Even if you're a fan of the options, more dependencies mean more setup, more to manage, and more potential points of failure.
A system with fewer dependencies, and especially more _portable_ ones, is going to be easier for people to pick up.

We've largely been considering things from an end-user perspective, but many of the same points apply as a developer or open-source contributor.
It wouldn't surprise me if developers are in fact the most affected by the slow-down of waiting for dependencies to install.
For my part, I regularly applied Ansible configurations for minimal installations related to whatever to whatever I was working on, with `kind` clusters spun up for each new feature or bug to avoid configuration drift.
Testing updates to Core v1 itself is pretty involved, with the need to build new containr images, potentially push them to a container registry, load them into Kubernetes, and patch the appropriate resources before being able to actually _test_ anything.
Having fast iterations really boosts developer experience, but all in all, that's a slow feedback loop.

Kubernetes is a good environment to support for large-scale users, but loose coupling provides a number of advantages.

## Decoupling from Kubernetes

From the outset, we knew we'd want Core v2 to integrate nicely with Kubernetes.
At the same time, we didn't want it to _only_ work on Kubernetes.

The immediate use cases were for:
* Plain old Docker, if we wanted to test components in isolation or via a test harness.
* Docker Compose, for local setups for developers and end users, and potentially for production scenarios.
* Kubernetes, for production scenarios.

Down the line, there could be support for other container orchestration systems like Docker Swarm or Hashicorp Nomad.
The key thing was that, if the system worked in stand-alone Docker or Compose, it should be able to work with other tools that might emerge.

If you look at the Protocol Buffer (Protobuf) APIs [for the scheduler](https://github.com/SeldonIO/seldon-core/blob/d3502062bbbb18a08032201917ceea07e124be41/apis/mlops/scheduler/scheduler.proto), you can see there are few fields that are Kubernetes-specific.
Where there are, like [including Kubernetes metadata](https://github.com/SeldonIO/seldon-core/blob/d3502062bbbb18a08032201917ceea07e124be41/apis/mlops/scheduler/scheduler.proto#L61), this tends to be treated as an optional field, as in [status responses](https://github.com/SeldonIO/seldon-core/blob/d3502062bbbb18a08032201917ceea07e124be41/apis/mlops/scheduler/scheduler.proto#L108).
This remains the case in the Kubernetes resource definitions for [models](https://github.com/SeldonIO/seldon-core/blob/d3502062bbbb18a08032201917ceea07e124be41/operator/apis/mlops/v1alpha1/model_types.go), [pipelines](https://github.com/SeldonIO/seldon-core/blob/d3502062bbbb18a08032201917ceea07e124be41/operator/apis/mlops/v1alpha1/pipeline_types.go), and so on.

You might be wondering why there are Protobuf schemata for Core v2 but nothing similar has been mentioned for Core v1?
This is a crucial aspect of how Core v2 is decoupled from any particular container orchestration system.
The scheduler, effectively the entrypoint to the Core v2 control plane, exposes its own gRPC APIs with its own domain model.
The operator then acts as a **shim/adapter to translate** between the Kubernetes definitions and the internal representation.
The same idea could just as well be applied to another system, with some Seldon-provided or third-party component providing this conversion.

There's an additional benefit to this approach: it's easy to write your own integrations with Core v2.
You can connect directly to the scheduler's [admin interface](https://github.com/SeldonIO/seldon-core/blob/d3502062bbbb18a08032201917ceea07e124be41/scheduler/cmd/scheduler/main.go#L74) to create new resources or query it.
In fact, for extracting information this may even be preferable on account of having access to streaming RPCs and potentially a higher level of granularity.
While the Kubernetes status information should be a good reflection of what the scheduler knows, there might be details that aren't well captured such as around the statuses of different models versions during a rollout.
Just be careful not to overload the scheduler with too many requests, as it has to do quite a lot of work to generate snapshots in a form for external consumption.

Hodometer, the optional usage metrics collector for Core v2, uses precisely this approach to calculate statistics about Core v2.
Like the rest of the system, it has no strong opinions about Kubernetes and will operate happily inside or outside it.
You can learn more about Hodometer in another blog post in this series.

One big caveat around this is NOT to mix different sources of truth to the same scheduler instance.
If you create a model directly, for example, then Kubernetes won't have anything to reconcile and in all likelihood won't even display that this model exists.
Conversely, if you try to delete a model created through Kubernetes, the operator is going to recreate it as soon as it learns the model has gone, because that's what reconciliation is for!

"Fine!" you say, "I wasn't going to write my own controller anyway."
The thing is: you don't have to.
The `seldon` CLI that's provided with releases of Core v2 is _also_ platform-agnostic and relies on being able to talk directly to the scheduler's APIs.
This is great for local usage, but has caused more than one incident of subverted expectations, where someone has been pinged me in a state of befuddlement about why things aren't doing what they thought.

As a result of this direct approach, there are three ways to use Core v2 compared to just one with Core v1: outside Kubernetes, inside Kubernetes with the operator, and inside Kubernetes _without_ the operator and CRDs.
This last one might sound unusual, but I mention it for completeness.
It is the scheduler, not the operator, which is responsible for creating and managing models, pipelines, and routing rules (but not servers) and reconciling these when things change.
These concerns are normally handled by an operator in Kubernetes, but in order to decouple we needed to extract these responsibilities.
As the operator is, ironically, therefore largely incidental to the operation of the system, one could discard it and use an alternative mechanism for managing inference servers and communicating with the scheduler.
That alternative mechanism could be some git-ops approach or, even more simply, static manifests for servers and infrastructural components like dataflow engines; the native capabilities in Kubernetes could be used for scaling these and liveness probes.

## Reuniting with Kubernetes

Maintaining loose dependencies on your environment can be advantageous, but sometimes it makes sense to have tighter integration.

As has been mentioned, Kubernetes is pretty much _the_ choice for larger organisations deploying containerised workloads --- it's dominant, it's ubiquitous.
Given that these organisations are also the ones most likely to need solutions for managing ML workloads at scale, it wouldn't make sense not to provide convenient integration into Kubernetes.
At any scale, users shouldn't have to jump through hoops.

A large part of that is around defining custom resources to represent domain types and having an operator to manage reconciliation, even if it delegates to the scheduler in many cases.
While the operator isn't ultimately responsible for everything, it does still serve a valuable role!

* Servers, infra components, conversion of SeldonRuntime to infra, comms with potentially many schedulers across namespaces


* Nice to have operator as it manages k8s CRDs for a Kube-native experience
* Many components have some awareness of k8s in the form of watching secrets
  * Don't want to go into this _too_ much
  * Watching can be faster than waiting for secret updates to propagate through the filesystem, supposedly
    * Find articles discussing this as motivating factor
  * Some k8s metadata also passed around as relevant and if available
    * Link to parts of CRDs which do this
  * BUT the key thing about k8s integration is having custom resources... Segue

## Customising Kubernetes/Systems with semantics

* One of the most powerful aspects of k8s is its ability to define custom resources
  * Not limited by what it provides out of the box
  * The fundamental building blocks (deployments, services, persistent volumes, etc.) are very powerful and useful
    * But utilitarian
    * But they don't express domain concepts or business logic
    * Bit like writing code in assembly compared to Python -- all the primitives are available to you and you can be very precise in how you use them, but it's harder to express business logic when you're always having to drop down into that lower level
      * Do you generally care if you're using an 8-bit, 32-bit, or 64-bit integer, or just that it behaves like an integer?
  * Also without having to integrate these into some central location
* Custom resources represent some higher level concept, such as routing rules for a reverse proxy or SDN, a database cluster, or even a full application comprising multiple components and a cache
* Custom resources are represented by CRDs (Custom Resource Definitions)
  * This is a contract of what can be configured
  * Some CRDs are rather large, as they embed others
    * Pod specs in particular are an already large resource definition

## Modelling ML

* CRDs in SCv2
* Splitting up single large CRD from SCv1 into multiple in SCv2
  * Be brief -- this should be covered in the post about SCv1 vs SCv2, so just want to recap key info
* Emphasis on defining more modular components that can be combined together in interesting (or simple!) ways
* List out CRDs
* Mention that these don't magically interact -- there needs to be logic in one or more components to orchestrate these workflows
  * (Or choreograph, in terms of the data plane...  According to Neal Ford's taxonomy)
  * Mention various components need to be aware of models & pipelines to process them appropriately
  * Clearly we need some way to convert between the k8s representation and the internal one understood by SCv2
    * Internal repr. exists due to platform agnosticism, cf. earlier point

## Translation & delegation

* The operator translates CRDs to the internal model used by the scheduler
  * Adaptor between CRDs & SCv2
  * This in turn informs other components, but that's a topic for another blog post
* Add Mermaid diagram(s) showing operator's interactions with other systems
  * Context diagram of user -> k8s API -> operator -> (SCv2/scheduler & k8s)
* For models, pipelines, and experiments, the operator delegates the responsibility for actually managing these to Core v2 via the scheduler
* For servers, the operator is directly responsible for managing these in terms of lower-level resources
* Translation not just of resource definitions, but also of comms protocols
  * k8s API is REST/HTTP-based
  * Operators are informed on an event basis as things change in the system
    * Again REST-based?  Check this
  * Scheduler talks gRPC, so the operator needs to talk to it in this way too
    * Long-lived gRPC connections normally
      * (Are any calls unary RPCs?)

## Boxes of bits

* Runtime resource is a meta-resource in the same way as a server is, that being built up from lower-level ones provided directly by k8s
* Found from feedback & own experience there were too many moving parts for users to have to manage and install
  * One Helm chart for X, Y, Z... (list these out)
* Thus, `SeldonRuntime` resource introduced in 2.6.0
  * Lots of discussion about how to implement this
  * Should servers be namespaced or global?
  * What implications would such decisions have for ownership of resources, separation of concerns, security, etc.
    * For ownership, consider team defines a model but needs a custom runtime for it, then another team owns the servers in a different namespace and the first team isn't allowed to deploy their own servers...
  * Teams may have very different requirements from servers anyway, in terms of hardware (GPU accelerated or not), overcommitting/usage profiles, runtimes and dependencies, criticality, scaling limits, etc.
  * Overall easier to leave servers as namespaced resources, but with other components bundled up together as these are much more standardised and not expected to be customised beyond hardware resources & scaling ranges

## Turtles all the way down

* May be worth separating discussion of meta-resources into its own section, as this is fairly interesting
  * Also an easy point to gloss over, but quite important to recognise!
* Almost all custom operators are using this pattern of defining a higher-level resource in terms of lower-level (k8s) ones
  * No reason not to do this with other CRs, as as from a k8s perspective they're basically all the same thing anyway
  * This is similar to programming languages, in which packages or modules (depending on the nomenclature) look and behave in the same way regardless of whether they're part of the standard library, a third-party dependency, or application code
  * Idea of seeing k8s CRDs as modules which can be layered into an overall application

## Operating an operator

* Structure of an operator
  * Operator vs. controller(s)
  * Mermaid diagram may be a big help in explaining this
* SCv2 uses one operator with multiple controllers defined within it
* No persistent state, as is standard for operators
* Global vs. namespaced modes
  * Note that runtimes & resources are always namespaced, as discussed previously
* Diffing needs to be done carefully to avoid issues like reconciliation loops
  * Things like last-applied annotations or whatever else can cause meaningless changes
  * Find some of the PRs relating to this for concrete examples

## From the ground up

* Brief walkthrough of how the operator was built
* Emphasise all standard tooling like `controller-gen`
* Highlight anything notable, such as some of the tags/annotations & libraries
* Discuss generation of raw manifests & Helm charts
  * Using Kustomize
  * Limitations of Kustomize and tricks for getting around it, e.g. markers & sed scripts

---

* Operators are a standard part of k8s-focused systems
