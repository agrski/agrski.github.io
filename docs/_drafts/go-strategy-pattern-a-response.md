---
title: The Strategy Pattern In Go -- A Response
tags: golang patterns
---

* Explain response to this article:
  * https://rednafi.com/go/strategy_pattern/
* Briefly explain purpose of strategy pattern & how it works in an OOP language
* Explain Go is not a traditional OOP language as it lacks classes & inheritance
  * But does have structs with methods, and interfaces
* Raise issues with original article
  * Overcomplicated -- attaching methods to function objects is confusing
  * Creating `OutputFunc` with a method to implement the interface also creates unnecessary wrapping
    * Interface already provides a consistent, type-checked
    * More verbose and confusing than using a struct or function directly
  * Use of struct is (in contrast to article) both simpler and more extensible as state can be added if required, e.g. for a logger
    * Personally, I like loggers provided through dep. inj. rather than global config -- easier for testing & customisation of fields
  * Not idiomatic (to my mind) to try to force something that looks more like a classical class and strict use of specific objects than to use Go's dynamic interfaces
* Give example using structs for strategies
* Give example using functions (whether plain function or method) for strategies
  * Meets footnote 4 in the Rednafi article
