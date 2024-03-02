---
title: The Strategy Pattern In Go -- A Response
tags: golang patterns
---

This is a response to the recent article [Strategy pattern in Go](https://rednafi.com/go/strategy_pattern/) by Redowan ("rednafi").
I like the author's easy-to-understand example of string formatting methods and their contrast of Ruby code with Go.
With that said, their solution feels verbose and overcomplicated to me, so I wanted to address that and propose some alternatives.

## Background -- the Strategy Pattern

In case you aren't familiar with this pattern or haven't read the original article, I'll summarise the idea here.

The Strategy Pattern applies when there are multiple ways of solving the same, specific problem.
Rather than creating an ever-growing switch statement to select between the alternatives, each solution is represented by a class and one such class is passed into the logic that needs to call it.
In other words, this is an application of **dependency injection**.
The key thing is that all of these classes, called **strategies**, conform to a common interface that, canonically, exposes a single method to invoke the strategy.

Let's take the example of sorting a list of items into ascending (or descending) order.
There's quick-sort, merge-sort, heap-sort, insertion-sort, and so on as generally applicable approaches, and specialised algorithms like radix-sort and bucket-sort if dealing with integers.
Each one can be represented as a single function that accepts a list of some type as input and returns a list of the same type as output.
If you have some logic that requires sorting a list, you can pass in an appropriate sorting algorithm to that logic, rather than having to hard-code it or embed the decision for which algorithm to apply.
If you're dealing with `int32`s, you may choose radix-sort; if the list is likely to be almost sorted, you might prefer insertion-sort to quick-sort.

There are three benefits to using the Strategy Pattern.
Firstly, it decouples the calling logic from the strategy logic, which provides loose coupling and generality, and allows the implementation of incidental logic to be swapped out, such as for testing purposes.
If the calling context doesn't need to know _how_ something is achieved, but just that it is, then it doesn't need to take responsilbity for that or concern itself with configuration for this; this aligns well with the Single Responsibility Principle.
Secondly, it provides extensibility in line with the Open-Closed Principle, which is about keeping code more maintainable.
Thirdly, it keeps the logic grouped into smaller, more focused elements rather than lengthy, expansive blocks.
That should make it more legible and thus more maintainable, particularly as it's capturing the _purpose_ of these strategies and not just their implementations.[1]

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

---

## Footnotes

[1] I'm a big believer in writing code that expresses algorithms rather than getting lost in the weeds.
It's something that Robert Martin discusses in the form of keeping blocks of code (functions, subroutines, etc.) at a consistent level of abstraction.
The idea is also found in parametric polymorphism, which is precisely about abstracting an algorithm over types.
[Until Go 1.18](https://go.dev/blog/intro-generics), there was no support for this feature, commonly known as "generics".
