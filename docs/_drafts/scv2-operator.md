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

## Decoupling from Kubernetes

* SCv1 had a hard dependency on k8s
* SCv2 is not k8s-specific as a system
* Optional -- SCv2 can run outside k8s, or even in k8s but without CRDs
* Deliberate design choice to allow for flexibility in dev & deployment
  * Easier to spin up locally in Docker Compose for dev purposes
  * Easier for new users if they don't need all the extra tooling and other overheads of k8s
  * Want to keep the door open for changes in preferred orch systems in future, e.g. Nomad
  * Also provides flexibility for users to manage their own integrations

## Reuniting with Kubernetes

* k8s is one of the most dominant container orch systems
* Thus do want to support it without users having to jump through hoops
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
