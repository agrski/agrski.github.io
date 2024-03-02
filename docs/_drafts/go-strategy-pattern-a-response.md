---
title: The Strategy Pattern In Go -- A Response
tags: golang patterns
---

This is a response to the recent article [Strategy pattern in Go](https://rednafi.com/go/strategy_pattern/) by Redowan ("rednafi").
I like the author's easy-to-understand example of string formatting methods and their contrast of Ruby code with Go.
With that said, their solution feels verbose and overcomplicated to me, so I wanted to address that and propose some alternatives.

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
