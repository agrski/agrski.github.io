---
title: The Strategy Pattern In Go --- A Response
tags: golang patterns
---

There was an article only a few weeks ago on the [Strategy Pattern in Go](https://rednafi.com/go/strategy_pattern/) by Redowan, a.k.a. "rednafi".
It's well written and informative but, reading through it as a Gopher myself, I realised there were certain aspects I would approach differently.
I like the author's easy-to-follow example of string formatting methods, and their contrast of Ruby code with Go.
With that said, their solution feels verbose and overcomplicated to me.
This post is a response to rednafi's article, as I wanted to address those issues and propose some alternatives.

## Background --- the Strategy Pattern

In case you aren't familiar with this pattern or haven't read the original article, I'll summarise the idea here.
If you're already familiar with it, feel free to skip over this section.

The Strategy Pattern applies when there are multiple ways of solving the same, specific problem.
It's particularly relevant when the choice of which approach to take is dynamic, i.e. it happens at runtime.
Rather than creating an ever-growing switch statement to aggregate the alternatives, each solution is represented by a class and one such class is passed into the logic that needs to call it.
In other words, this is an application of **dependency injection**.
The key thing is that all of these classes, called **strategies**, conform to a common interface that, canonically, exposes a single method by which to invoke the strategy.

Let's take the example of sorting a list of items into ascending (or descending) order.
There's quick-sort, merge-sort, heap-sort, insertion-sort, and so on as generally applicable approaches, and specialised algorithms like radix-sort and bucket-sort if dealing with integers.
Each one can be represented as a single function that accepts a list of some type as input and returns a list of the same type as output.
If you have some logic that requires sorting a list, you can pass in an appropriate sorting algorithm to that logic, rather than having to hard-code it or embed the decision for which algorithm to apply.
If you're dealing with `int32`s, you may choose radix-sort; if the list is likely to be almost sorted, you might prefer insertion-sort to quick-sort.

There are three main benefits to using the Strategy Pattern.
Firstly, it separates the calling logic from the strategy logic, thereby maintaining loose coupling and generality and allowing the implementation of incidental logic to be swapped out, such as for testing purposes.
If the calling context doesn't need to know _how_ something is achieved, but just that it is, then it doesn't need to take responsilbity for that or concern itself with configuration for this; this aligns well with the Single Responsibility Principle.
Secondly, it provides extensibility in line with the Open-Closed Principle, which is about keeping code more maintainable.
Thirdly, it keeps the logic grouped into smaller, more focused elements rather than lengthy, expansive blocks.
This should make it more legible and thus more maintainable, particularly as it's capturing the _purpose_ of these strategies and not just their implementations<a name="ref1" href="#fn1">[1]</a>.

## OOPs!  Go is classless

The description of the Strategy Pattern given above talks about classes, but Go doesn't have classes so how can it possibly apply?!
The short answer is using interfaces and method receivers, whether structs or functions, but let's discuss _why_ the design pattern is applicable before digging into the _how_.

In introducing the topic, Redowan mentions that "the Go community exhibits a knee-jerk reaction to the word 'pattern'" but, rightly so in my opinion, continues to use the established term rather than inventing a new one.
When translating the Ruby solution into Go, the author touches upon the lack of classes and the use of "interfaces and custom types" to supplement this, but without justifying why this is equivalent.

What I think is missed here is that Go isn't a million miles away from traditional object-oriented (OO) languages, particularly given the trend of favouring composition over inheritance.
Crucially, Go supports methods on structs (`func (a *A) foo()` ) rather than forcing the use of functions without receivers (`func foo(a *A)`) --- **structs with methods are effectively classes without subtype polymorphism** (inheritance)!
Like many OO languages it has interfaces and, since Go 1.18, generics.
Go is a memory-managed, garbage-collected language just like Java, C#, and Python, and its structs can be stack- or heap-allocated like in C++ and C#<a name="ref2" href="#fn2">[2]</a>.
Go's pointers are similar to references in languages like Java in that they do not support pointer arithmetic, although they do require manual indirection (`&` and `*`).
There are different visibilities for state, handled like in Python without using visibility modifier keywords; this is called exported and unexported state in Go nomenclature.

In short, if you take a classic OO language and strictly forbid inheritance in favour of composition, it's not necessarily going to look too different to Go.
As a consequence, I'd argue the use of design patterns, even ones common in OOP, is still valid and applicable.

## The (un)importance of being explicit

While Oscar Wilde may laud the virtues of being earnest, Redowan seems to value being explicit.
Specifically, they seemed perplexed by Go having "no concept of ... explicit interface implementation" like Ruby does.

On this point, I'd argue that it's irrelevant to implementing the Strategy Pattern, but note that Go does still allow us to express this idea.
Why is it irrelevant, you might ask?
The answer is that Go, unlike many languages, doesn't need _explicit_ interface implementation for its type system to work.
In Go, adherence to an interface is determined at the point of _use_ rather than at the point of _definition_.
This is the idea of **duck typing** --- if it quacks, it's a duck!
In fact, duck typing is the very approach taken by Python, the [zen of which](https://peps.python.org/pep-0020/) states that "explicit is better than implicit".
If defining the right methods is explicit enough for Python, with this clearly stated convention, then it's probably sufficiently explicit for Go too.

With that said, sometimes one might just want some reassurance that an entity really does implement the right interface(s).
For this, you can use what I've previously seen described as "interface assertions".
This isn't a language feature in Go, but rather an idiomatic expression that will fail compilation if a type doesn't conform to a specified interface.
It's a nifty trick because the anonymous variable `_` will be discarded by the compiler for runtime purposes, thus doesn't incur any storage or runtime cost.

```go
type Fooer interface {
  ...
}

type Bar struct {
  ...
}

// interface assertion
var _ Fooer = (*Bar)(nil)
```

## Unwrapping unnecessary complexity

My main criticism of rednafi's article is that the approach it presents is, in my opinion, overcomplicated and not particularly idiomatic.
I'd like to explain what I mean by that and suggest a couple of alternatives.

What first caught my eye was attaching a method to a function.
Functions are first-class objects in Go, so this is valid, but personally I find it unintuitive --- I expect the receiver of a method to be a struct or (more likely) a pointer to a struct.
The author claims "a function type keeps things concise", but is that really the case?
Their implementation is given below for reference (comments elided for brevity), with my suggestion of using a struct given thereafter.
In terms of line count, character count, and nesting, using a struct is decisively more concise.

```go
// rednafi's approach

type OutputFunc func(message string) string

func (f OutputFunc) Output(message string) string {
    return f(message)
}

TextFormatted := OutputFunc(func (message string) string {
    return message
})
```

```go
// my approach

type TextFormatter struct {}

func (t *TextFormatter) Output(message string) string {
    return message
}
```

This brings me on to my next point: this approach of creating a wrapper for implementors of the interface induces needless nesting and complexity.
To be clear, I'm not referring to computational complexity, i.e. time or space, but rather cognitive complexity --- how simple or convoluted the logic is.
The `Formatter` interface already provides a consistent and type-safe way of passing strategies, if using struct receivers; the `OutputFunc` wrapper is an artifact of using a function receiver instead.
The following snippets are from the original article, given first, followed by my proposal.
The latter approach is again more concise and legible, as well as automatically satisfying the type system without the need for a cast.

```go
// rednafi's approach

TextFormatted := OutputFunc(func (message string) string {
    return message
})
Display(message, TextFormatted)
```

```go
// my approach

tf := &TextFormatter{}
Display(message, tf)
```

If we want to be even more concise, we can pass the formatting strategy in directly:

```go
// my approach

Display(message, &TextFormatter{})
```

There is another benefit to using a struct as the method receiver, which rednafi very briefly touches upon: should we need to, we can add state.
An empty struct is very cheap to use in the first place, as it requires no space to allocate, but should we need to add state then everything else is already in place<a name="ref3" href="#fn3">[3]</a>.
If we wanted to add state to the original, function-based approach, we would need to change it to use a struct anyway, likely causing reworking in other code that should, really, be unaffected.

In summary, using **structs** to implement the strategy interface is **simpler, more concise, and more readily extensible**.

## Functioning differently

I mentioned that previously that I would propose more than one alternative to Redowan's approach.
[Footnote 4](https://rednafi.com/go/strategy_pattern/#fn:4) to their post gave me a little brainwave --- what if there's a nicer way to handle passing around functions as strategies?

If we're willing to bend the definition of the Strategy Pattern slightly, we could argue that a strategy is really defined by the signature of its invocation function.
Given that the canonical strategy interface comprises a single function, the interface itself is really just a way of assigning a type for that function in languages that don't support raw, first-class functions but rather only methods, like Java.

Using this looser interpretation, we can do away with that superfluous wrapping we saw before and pass functions instead of interfaces.
The following are minimal working examples tested with Go 1.21.5.
In both of them, we now define `Format` as a function instead of using the `Formatter` interface<a name="ref4" href="#fn4">[4]</a>.

In the first example, We define `textFormat` as a normal function and `textFormat2` as a lambda.
Both are valid approaches and legal syntax, without requiring the wrapping employed by rednafi's solution.

```go
package main

import (
	"fmt"
)

type Format func(message string) string

func textFormat(message string) string {
	return message
}

func Display(message string, f Format) {
	fmt.Println(f(message))
}

func main() {
	message := "Hello, World!"
	textFormat2 := func(message string) string { return message }

	Display(message, textFormat)
	Display(message, textFormat2)
}
```

In this second example, the `jsonFormat` strategy is defined as a struct to show that we can pass in a method so long as its signature is compatible.
In other words, we have not lost the ability to use stateful strategies when relying on function types!
However, using a method on a struct requires instantiating it first, which might be inconvenient at times.
The exported (public) `JSON` variable shows one approach to working around that inconvenience.

```go
package main

import (
	"encoding/json"
	"fmt"
)

type Format func(message string) string

type jsonFormat struct{}

func (jf *jsonFormat) Format(message string) string {
	asJSON, _ := json.Marshal(map[string]string{"message": message})
	return string(asJSON)
}

func Display(message string, f Format) {
	fmt.Println(f(message))
}

var JSON = &jsonFormat{}

func main() {
	message := "Hello, World!"
	j := &jsonFormat{}

	Display(message, j.Format)
	Display(message, JSON.Format)
}
```

## Conclusions

The Strategy Pattern is as applicable to Go as to object-oriented programming languages.
However, the idiomatic ways of modelling it in Go look slightly different due to Go's lack of classes and support for duck typing and first-class functions.
Using an interface and structs with methods to represent strategies is concise, flexible, and comparable to a class-based approach.
Using functions or methods conforming to a function signature is equally as valid in Go, and equally concise.

---

## Footnotes

<a name="fn1" href="#ref1">[1]</a> I'm a big believer in writing code that expresses algorithms rather than getting lost in the weeds.
It's something that Robert Martin discusses in the form of keeping blocks of code (functions, subroutines, etc.) at a consistent level of abstraction.
The idea is also present in parametric polymorphism, which is precisely about abstracting an algorithm over types.
[Until Go 1.18](https://go.dev/blog/intro-generics), there was no support for parametric polymorphism, commonly known as "generics".

<a name="fn2" href="#ref2">[2]</a> C# uses the keyword `struct` to refer to value types, which are often stack-allocated, and `class` to refer to reference types, which are heap-allocated.
See [the docs](https://learn.microsoft.com/en-us/dotnet/standard/design-guidelines/choosing-between-class-and-struct) and Jon Skeet's [blog post](https://jonskeet.uk/csharp/memory.html) for more information.

<a name="fn3" href="#ref3">[3]</a> My personal preference is for structs that represent services or components to have a field for a logger at the very least.
In my experience, having this already wired in tends to be very convenient for debugging purposes.

<a name="fn4" href="#ref4">[4]</a> Go [recommends](https://go.dev/doc/effective_go#interface-names) that interface names be [agent nouns](https://en.wikipedia.org/wiki/Agent_noun), i.e. words ending in "er", such as "Stringer" for the interface providing a `String()` method.
Conversely, given this convention, one might well expect that names ending in "er" be interfaces.
As the `Format` type is _not_ an interface but rather a type alias for a function, it would seem unhelpful to suggest it were.
