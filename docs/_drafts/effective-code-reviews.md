---
title: Effective Code Reviews
tags: collaboration workflows
---

Code reviews are an integral part of collaborative software development.
They serve as a natural synchronisation point for discussion, whether retrospective (as is the norm) or also prospective.

This article offers advice for all involved parties on how to make reviews more effective --- for submitters, for reviewers, and for teams more broadly.
The core themes are to embrace the opportunity for discussion and knowledge sharing, respect one another's time, and treat reviews as a form of decision record and documentation.

The suggestions given herein are based on the author's own experiences and opinions.
They are not intended to be taken as gospel and, in a handful of cases, are acknowledged to be contested views on what constitutes good practice.
I encourage you to read and consider them all the same, and to draw your own conclusions on what to do and, more importantly, why.

## Inspiration

> If you want to go fast, go alone; if you want to go far, go together

That old proverb applies as much to software development as to anything else.
It's an inherently collaborative discipline.
Yet for all that, there are a number of things which are rarely discussed in any depth and seem to sort of just spring into existence.
How often do you discuss your source control workflows, how to run meetings, or how to draw clear architecture diagrams?

Like many things, it seems to be just assumed that people know _how_ to review code, or that they'll pick it up quickly through cultural osmosis.
In a way that's true: people do pick things up all the time out of necessity and trial-and-error and by copying others.
At the same time, that doesn't mean people are learning _effectively_ if they're left to their own devices.

Take the example of typing.
Despite the ubiquity of keyboards in devices for decades now, a quick search suggests only around 20% of keyboard-users are touch-typists.
Yet those that are can type 50-100% faster than those that aren't and at least as accurately <a name="ref1" href="#fn1">[1]</a>.
Interestingly, those same studies indicate the different groups of typers have about the same number of years of experience and spend about the same amount of time typing per day.
Unless developers are actively, consciously looking to improve their skills, why should we assume they are effective reviewers just because they're required to provide commentaries from time to time?
The same goes for those _submitting_ reviews --- any form of communication is a two-way street.

The topic of reviewing code has come up in conversation with coworkers before, although usually when there's a point of frustration.
I'm sure we've all had to deal with some uncomfortably large pull/merge requests before, for example.
For all the pain, it was when working through one of these that I came to the realisation it's not really _large_ PRs that cause problems so much as _complex_ ones.
Being the imprecise communicators that humans are, we often coerce request size into being a (weak) proxy for complexity.
Over the last few years, it's a topic I've given a fair bit of active thought to and feel deserves more attention, especially for new practitioners.
The remainder of this article explains my current thinking on how to make the most of the review process.

## A note on tools

Code reviews have probably been around in one form or another about as long as code has.
They can be as simple as sitting down with someone (physically or virtually) and talking through some code together.
They might be done via sending patches over email, as famously with [the Linux kernel](https://www.kernel.org/doc/html/v4.10/process/email-clients.html#general-preferences) and Vim.
They might be supported by browser-based tools like the UIs provided for GitHub, GitLab, and similar, or even third-party tools like Gerrit.
Heck, you might even use an IDE integration like [the one for VS Code](https://code.visualstudio.com/docs/sourcecontrol/github#_pull-requests)!

If it's one of these or none of them, that's okay.
Tools are just that: tools.
Some are definitely more helpful or offer better support for certain workflows, but what matters is how you use them.
The suggestions given in this article should apply to most, if not all, of the tools you might encounter.

## As a submitter

### Identify your audience

This might sound overly obvious --- surely the audience is other developers?!
There's a bit more to it, however.

Are the reviewers in your team, from elsewhere in the same organisation, or potentially even from another organisation (as might be the case for open-source software)?
How much **access** do they have to the same systems and knowledge bases as you have?
This is especially important in the latter two scenarios and any assumptions that are baked in around set-up and tooling.

How **experienced** do you expect the reviewers to be overall, and in particular in terms of relevant **domain expertise**?
There's a big difference between a graduate familiar with Python and someone with a decade of experience in latency-sensitive applications using a specific C++ tool chain.
For less experienced reviewers, consider providing more context and avoiding lots of short-hand, for example.

How many different **groups** of reviewers do you need to cater to?
Are you expecting new joiners to be reviewing your work to build up their knowledge or feed in new ideas?
Are the only reviews people who've been on the team for a while and know the ins and outs of the project and why things are done a certain way?
Might someone with a less technical background need to sign off on the functional aspects of your changes?

### Provide context

Many code review mechanisms support some way of describing changes, be that an email body or a PR description.
This serves a few purposes.

The immediate benefit is that it primes the reader on what they need to know.
What's the priority of this change --- an urgent bug, a speculative optimisation, or perhaps a refactoring to simplify an upcoming feature?
What dependencies does this change have and what is dependent on it?
If this blocks something important, it should in turn be understood to be more important itself.
How risky is it?
Are you confident in the solution or looking for feedback on specific aspects of it?
Giving the reviewer(s) an idea of what to focus on can help them to be more efficient with their time and to provide more focused feedback.

There's a future benefit too, which may even exceed the immediate value.
When you're making a change, there's a reasonable likelihood someone else in the team has context on that change, why it's being done, why a particular solution was chosen, and suchlike.
What happens when that's not, or is _no longer_, the case?
What if the assigned reviewer has just come back from a break or is in a different time zone and working asynchronously?
What happens when coworkers with this information have moved to other projects or left for other companies?
What about when a change was made a year ago and you simply can't remember all the details about it?

Recording information about a change _for future reference_ is a major motivating factor for me.
I don't want to be a bottleneck or overwhelmed with questions on past decisions, and allowing others to self-service their answers mitigates that.
If this context makes it into source control history, even better, but that's not always possible depending on what's been configured.
Do yourself and your teammates a massive favour and keep context close to the code.

The way I tend to structure my own PR descriptions these days is with the following sections:
* Why this PR exists:
  * Any linked tickets, which should provide more or less full context for the changes.
  * A few sentences on the motivation for this change and any relevant background.
    While tickets should cover this in depth, I value having key information _immediately_ available.
    Information in another system is liable to suffering from poor accessibility, perhaps due to permissions, poor organisation, deletions and modifications, and so on.
* What the changes involve:
  * A brief overview of the _logical_ changes.
    The commit history _should_ tell me exactly what changed, but it may be overly terse or excessively verbose.
    Things like merge commits, reversions, and addressing review comments do not tell me much about what this PR represents.
  * A before and after comparison, if applicable.
  * A summary of any manual testing, or things that otherwise do not live within the code itself.

You might disagree with this structure or bemoan the additional effort.
I find that's somewhat mitigated through using PR templates for tools that support them, [like GitHub](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/about-issue-and-pull-request-templates).
Whatever your opinion, I've found this approach beneficial for myself and have been complimented by multiple coworkers when it helped them too!

---

## Footnotes

<a name="fn1" href="#ref1">[1]</a> Around 80 words per minute compared to around 50 according to [this research paper](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9356123/) from 2022.
[This article](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5145878/) from 2016 gives self-reported numbers of about 68 and 43.

---

* Tooling isn't the key thing -- GitHub, GitLab, Gerrit, emails, etc. can all work
* Draft all comments before posting/publishing
  * Not all need to be submitted
  * Review at end before submitting
  * Can help to spot patterns and suggest a more general comment
  * If review tool allows it, add draft/pending comments to revise later

* As a submitter:
  * Add explanatory comments of your own
    * Highlight things which are interesting or might be subtle
    * Bring attention to points you want special attention on
    * Reference other conversations as appropriate
    * Explain why a particular approach was taken
    * Some comments belong in code (e.g. workaround can be removed when X) but some are best placed in reviews
  * Review your draft PR/MR yourself as a sanity check
    * Be respectful of reviewers' time
    * If you can't be bothered to check over your own work, why should a reviewer?
  * Address comments
    * Actually provide a written response on the review platform _for future reference_ by others
    * Lots of information can easily be lost and inaccessible to others down the line
    * Sometimes addressing a comment can be as simple as "won't fix" or "I'll remember for next time"
    * When a particular commit addresses a comment, link to/reference this commit
      * GitHub supports this nicely
      * Don't do one "address comments" commit because it makes it hard to evaluate specific changes; use one commit per comment/family of comments
  * Try to minimise how many logical changes are involved
    * E.g. separate refactoring from introducing new features
    * E.g. introduce bug fix & test but leave out formatting/stylistic changes
    * Make it easy for the reviewer to focus on what's important -- minimise _noise_
  * Do document manual testing steps
    * Not all code is easy to unit test
    * I've had a few bugs that were tricky to reproduce and needed a particular ecosystem configuration to match a customer setup
    * In such cases, a PR is a good place to document manual testing so others can check this over and, if necessary, reproduce it themselves
    * Maybe you want to confirm all instances of something have been changed/removed so you record some `grep` invocations
    * Sometimes you might want to use pictures or video for before/after validation
  * Be adapatable and open to feedback
    * But also don't be a pushover -- justify and discuss so everyone has a clear understanding
    * If you wrote something notably suboptimal, it's likely better to change it now rather than trying to unpick it later
    * It's easier to make changes when you have all the context fresh in your mind

* As a reviewer:
  * Consider your tone & the target audience
  * Comments should follow the must/should/could convention
    * Must = blocks merging, something is wrong
    * Should = discussion needed, something might be wrong or have edge cases or non-functional considerations
    * Could = take it or leave it; nit-picking or educational commentary
  * Comments are a means of instigating discussion
    * Discussion can benefit other readers/viewers
    * Discussion can be for your own education
    * Proposing alternatives might lead to better outcomes, at least sometimes
  * Using emoji/emoticons provides visual feedback
    * Humans have evolved to be good at consuming visual media and processing it quickly
    * Easy to scan down a list of comments and pick out what's most important -- not as easy with words
    * Prefer a limited set to avoid confusion
      * Wrench = change required
      * Thought balloon = suggestion/idea
      * Question mark (red) = I'm ensure of something, please explain
      * Needle = nit-picking (think knitting needle or needling concerns)
      * Upside-down face = completely throwaway comment; feel free to ignore as it won't block a review
  * Assume good intentions -- someone might have missed something, so help raise others up instead of bringing down
  * Provide targetted feedback
    * Be specific and clear about what you mean
    * Offer suggestions if possible
      * "This is poor practice" is uninformative
      * "This data structure makes lookups much cheaper and this code is likely to lots of lookups" is much more useful
  * Reason about the PR, don't just accept it because someone submitted it
    * What is the PR supposed to achieve?
    * What approach would _you_ take?
    * What approach did the submitter take?
    * Does the approach meets the functional _and_ non-functional requirements?
    * Is it making a unilateral decision when this is something that should be discussed amongst the team?
    * Are there are major implications of the approach, e.g. for security or performance?
  * Be confident in asking for clarification
    * Don't just assume -- that's how bugs sneak in!
  * Be focused
    * Try not to get side-tracked by small details and aim to review the key aspects first

* As a team:
  * Treat code reviews as a form of team communication that can benefit everyone if done effectively
  * Where possible, enforce things like code style automatically through linters
    * These should run consistently in CI and in the same way on development machines
    * I'm a fan of Makefiles or equivalent to enforce the same invocation of a tool, even if the installation of that tool differs by env
  * Apply settings provided by the review platform to ensure comments are addressed
    * E.g. in GitHub for a big PR with lots of comments, it folds them and makes it easy to literally lose sight of what's outstanding
    * Some might complain this slows down the process
      * If it's a minor comment and/or can be ignored, resolving it is a trivial cost
      * If it's more serious, that comment shouldn't be ignored and the slow-down is justified!
  * I believe in _not_ applying auto-merge functions, at least not by default
    * There can be >1 reviewer for a PR
    * If one reviewer hasn't finished reviewing, it's better to wait
    * The co-ordinator of the change (i.e. the submitter) is the best placed to know if anyone's review is pending, so they should be in control of the setting
  * I also believe in dismissing stale reviews if new code is pushed
    * I acknowledge this is a controversial opinion
    * If the changes are trivial to review, it's a minor cost to scan over them quickly
    * If the changes are more significant, another review is justified to ensure new issues haven't been introduced
  * Develop a culture of supporting live code reviews
    * In some situations, a live review is enormously faster and more effective than writing many comments
    * E.g. I've done live reviews for documentation with non-native speakers to help with grammar and phrasing
  * Aim for automated and human aspects to be as smooth and fast as possible
    * E.g. having to wait for tests to run when you changed a few lines in a README wastes everyone's time
    * Inconsisentices in setups cause friction
    * Having too many people working on the same area causes merge conflicts and, thus, friction
    * Ultimately, if it's slowing you down enough that you notice, it's probably worth investing time to fix!
    * Be open to experimenting with new workflows and tools to see if they work better!
    * Try to provide initial reviews quickly
      * Avoid overloading a small number of people -- it creates bottlenecks

* Pet peeves
  * Many people write long lines of code, which is awkward for many reasons
    * There's a reason newspapers and books use narrow columns -- much easier for humans to read
    * Not everyone uses screen real estate in the same way, so don't assume long lines are convenient
      * Many online review tools in particular limit horizontal screen real estate, such as when using side-by-side views
    * Making a small change in a long line, like renaming a parameter, is often much harder to spot than having multiple lines
  * Merging in a PR as soon as one person has reviewed it
    * This is acceptable in some workflows, but in my experience it's not uncommon for there to be multiple reviewers
    * I've seen a number of bugs and/or debatable code choices come back to bite because of an over-eager reviewer
    * Co-ordinate and give others a chance to respond unless a change is low risk or you really need to move quickly
    * Merging in others' PRs means you probably don't have full context and might be premature in doing this
  * Heavily stacked PRs
    * I've seen a lot of proselytising for stacked PRs recently
    * I can understand doing some (minor) refactoring/reformatting before introducing a new feature
    * However, lots of stacking means a reviewer may need context from other PRs first
    * It's also arrogant to my mind -- basing new work on other work that hasn't been accepted _presumes_ it will be accepted with minimal changes
    * With heavy stacking, this presumption stacks
    * It's better to have fast review cycles so there's discussion from earlier on in case things do change
