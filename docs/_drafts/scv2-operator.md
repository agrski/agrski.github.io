---
title: Seldon Core v2 Deep Dive --- Operator
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

## Systems with semantics --- customising Kubernetes

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

### Core v1 --- collated, conflated, orchestrated

* Highlight key aspects of SCv1 operator
  * Single CRD containing everything (the entire spec)
  * Integrations need to be provided and managed by the operator
  * Deployments uses an orchestrator to manage the flow of data

### Core v2 --- composable, choreographed, self-contained [c...? idea of efficient, multi-user]

* Splitting up single large CRD from SCv1 into multiple in SCv2
  * Be brief -- this should be covered in the post about SCv1 vs SCv2, so just want to recap key info
* Emphasis on defining more modular components that can be combined together in interesting (or simple!) ways
* List out CRDs
* Mention that these don't magically interact -- there needs to be logic in one or more components to orchestrate these workflows
  * (Or choreograph, in terms of the data plane...  According to Neal Ford's taxonomy)
  * Mention various components need to be aware of models & pipelines to process them appropriately
  * Clearly we need some way to convert between the k8s representation and the internal one understood by SCv2
    * Internal repr. exists due to platform agnosticism, cf. earlier point

## Decoupling from Kubernetes

### A bit too close for comfort?

* SCv1 had hard dependency on k8s
* This caused various difficulties
  * Dev is harder due to dependencies
  * Hurdle for new users to get up to speed with k8s before using Core
  * Reliance on Kube-native tools, e.g. Istio & Knative
    * Recognise external tools allow focus on core competencies, but...
    * Contentious choices may not suit everyone
    * Maintenance burden to keep up to date with *ranges* of compatible releases
    * Maintenance burden to support increasingly many options for community
    * Heavier deps for dev, testing, and end users
* Precludes integration with other container orch. systems like Nomad & Swarm

### Staying in touch

* Want to address issues raised above
* Nice to still have operator as it manages k8s CRDs for a Kube-native experience
* Many components have some awareness of k8s in the form of watching secrets
  * Don't want to go into this _too_ much
  * Watching can be faster than waiting for secret updates to propagate through the filesystem, supposedly
    * Find articles discussing this as motivating factor
  * Some k8s metadata also passed around as relevant and if available
    * Link to parts of CRDs which do this
  * BUT the key thing about k8s integration is having custom resources... Segue
* Use of API is major consideration
* Breaking away from service meshes and ingress providers with custom configuration for Envoy

### Translation & delegation

* The operator translates CRDs to the internal model used by the scheduler
  * Similar in content, but different in some ways and in structure
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
