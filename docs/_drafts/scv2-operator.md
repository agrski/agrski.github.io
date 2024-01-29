---
title: Seldon Core v2 Deep Dive---Operator
tags: seldon seldon-core-v2 architecture
---

This article is part of a series about [Seldon Core v2](https://github.com/SeldonIO/seldon-core/tree/v2).

Seldon Core v2 is largely platform agnostic by design, with the **operator** existing to help integrate it natively into Kubernetes.
It's responsible for managing the Kubernetes resources related to Core v2, and acts as an adapter between those resources and Core v2's internal representation.

This article discusses the operator's role in more detail, including what those Kubernetes resources are, how it handles them, and how it was built.
Of particular interest is the operator's use of **meta-resources**, i.e. resources that define other resources.

## Decoupling from Kubernetes

* SCv1 had a hard dependency on k8s
* SCv2 is not k8s-specific as a system
* Deliberate design choice to allow for flexibility in dev & deployment
  * Easier to spin up locally in Docker Compose for dev purposes
  * Easier for new users if they don't need all the extra tooling and other overheads of k8s
  * Want to keep the door open for changes in preferred orch systems in future, e.g. Nomad
  * Also provides flexibility for users to manage their own integrations

## Reuniting with Kubernetes

* k8s is one of the most dominant container orch systems
* Thus do want to support it without users having to jump through hoops
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
  * This in turn informs other components, but that's a topic for another blog post
* For models, pipelines, and experiments, the operator delegates the responsibility for actually managing these to Core v2 via the scheduler
* For servers, the operator is directly responsible for managing these in terms of lower-level resources
* Translation not just of resource definitions, but also of comms protocols
  * k8s API is REST/HTTP-based
  * Operators are informed on an event basis as things change in the system
    * Again REST-based?  Check this
  * Scheduler talks gRPC, so the operator needs to talk to it in this way too
    * Long-lived gRPC connections normally
      * (Are any calls unary RPCs?)

---

* Optional -- SCv2 can run outside k8s, or even in k8s but without CRDs
  * Nice to have as it manages k8s CRDs for a Kube-native experience
* Operators are a standard part of k8s-focused systems
* Multiple CRDs managed by it: models, pipelines, servers, experiments
* Adaptor between CRDs & SCv2
* Delegates management of models, pipelines, and experiments to SCv2 scheduler
  * Long-lived connection to schedulers over gRPC
* Manages server resources much more directly
* Single operator for all resources, with one controller per resource
* No persistent state, as is standard for operators
* Mention generation of CRDs with controller-gen (& Kustomize?)
* Interesting use of CRs that define other CRs in the form of the `SeldonRuntime` resource
* Operator can be global, with runtimes namespaced
  * Can also be namespaced
