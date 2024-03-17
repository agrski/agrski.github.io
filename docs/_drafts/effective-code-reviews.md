---
title: Effective Code Reviews
tags: collaboration workflows
---

* Tooling isn't the key thing -- GitHub, GitLab, Gerrit, emails, etc. can all work
* Draft all comments before posting/publishing
  * Not all need to be submitted
  * Review at end before submitting
  * Can help to spot patterns and suggest a more general comment
  * If review tool allows it, add draft/pending comments to revise later

* As a submitter:
  * Consider target audience
    * How experienced are they?
    * How many different groups may be reviewing (e.g. juniors & seniors)?
  * Add explanatory comments of your own
    * Highlight things which are interesting or might be subtle
    * Bring attention to points you want special attention on
    * Reference other conversations as appropriate
    * Explain why a particular approach was taken
    * Some comments belong in code (e.g. workaround can be removed when X) but some are best placed in reviews
  * Review your draft PR/MR yourself as a sanity check
    * Be respectful of reviewers' time
    * If you can't be bothered to check over your own work, why should a reviewer?
  * Provide useful context in the PR/MR description
    * This is useful for priming a reviewer on what they need to know
      * E.g. is this a high-priority bug fix or a speculative refactoring or optimisation?
    * It can also be a massive boon to future readers
      * I've often ended up looking at past PRs to understand why a change was made
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