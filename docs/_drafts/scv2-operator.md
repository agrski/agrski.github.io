---
title: Seldon Core v2 Deep Dive---Operator
tags: seldon seldon-core-v2 architecture
---

This article is part of a series about [Seldon Core v2](https://github.com/SeldonIO/seldon-core/tree/v2).

Seldon Core v2 is largely platform agnostic by design, with the **operator** existing to help integrate it natively into Kubernetes.
It's responsible for managing the Kubernetes resources related to Core v2, and acts as an adapter between those resources and Core v2's internal representation.

This article discusses the operator's role in more detail, including what those Kubernetes resources are, how it handles them, and how it was built.
Of particular interest is the operator's use of **meta-resources**, i.e. resources that define other resources.

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
