# Introduction

## What we are building

elxrBB is a bulletin board — the phpBB shape. Forums holding topics, topics
holding threaded replies, a list of who is online at the bottom of the index,
view counts, moderation.

That is a deliberately old-fashioned thing to build, and it is a very good
excuse to learn Elixir, because almost everything a busy board does is a
concurrency problem wearing a CRUD costume:

- **Who's online** is soft, per-connection state that should vanish the moment
  a connection does. phpBB kept it in a table and ran a cron job to clean it
  up. Elixir has processes that die, and monitors that tell you.
- **View counts** are the hottest writes in the system and the least important
  numbers on the page. phpBB ran `UPDATE topics SET views = views + 1` on every
  page load, contending on exactly the rows people were looking at.
- **"Someone replied while you were reading"** is a push. phpBB made you hit
  refresh.
- **A board that survives a bad deploy** wants a failure to be local to one
  request rather than fatal to the process serving everyone. This is the thing
  the BEAM is actually for.

So the tutorial is organised around those problems rather than around a
framework's directory layout.

## What you need to know already

Some programming, in any language. You do not need Elixir. You do not need
functional programming. You do not need to have run a server.

You *will* need to be comfortable being told that a thing you already know how
to do — increment a counter, keep a session, notify a client — has a different
and better answer here, and to sit with the new answer long enough to see why.

## How the two repositories fit together

- **[elxrBB](https://github.com/ephbaum/elxrBB)** — the application. Every
  lesson corresponds to code that is merged and tested there.
- **[elxrBB-tutorial](https://github.com/ephbaum/elxrBB-tutorial)** — this
  repository, the lessons.

They have not always agreed. See [the honest version of this project's
history](#a-note-on-the-history) below.

## What we build in Part I, and what we leave out

Part I builds the whole board *except* the web and the database:

```
ElxrBB.Board      users, forums, topics, threaded replies, moderation
ElxrBB.PubSub     cluster-wide events, on :pg
ElxrBB.Presence   who's online, replicated across nodes
ElxrBB.Counters   view counts, kept out of the database
ElxrBB.Board.Store  a persistence boundary, with an in-memory implementation
```

No Phoenix. No PostgreSQL. No Docker. Not because those are bad — Part II and
Part III add two of the three — but because putting them first is how this
project failed twice.

When the framework comes first, it becomes the application. The rules end up
inside generated LiveViews, the LiveViews call `Repo` directly, and there is no
seam left to test at, cache at, or reason about. You cannot run the domain
without a database because there is no domain, only controllers.

Starting from the middle instead means that by the end of lesson 3 you have a
board you can drive from `iex`, a test suite that runs in under a second with
nothing installed, and multi-node tests that prove the distributed claims. Then
Phoenix is a delivery layer, which is what it is good at.

## A note on the history

This is the third attempt at this project.

The first, in 2023, was written in conversation with GPT-4. The model produced
a confident sixteen-lesson outline, then lessons for code it had not written,
then code that did not match the lessons. The repository ended up with a
Phoenix skeleton, some generator output, and six lessons describing a different
application. The README at the time said, accurately, "this may all be made up
bullshit."

The second, in 2025, cleaned up three of those lessons and reset the
application repository to a README. The lessons were better written and still
described software nobody had built.

The third is this one. The rule it runs on is in
[`STATUS.md`](../STATUS.md): a lesson is written after the code it describes is
merged and tested, and not before. That is why this outline has three written
lessons and thirteen honestly marked "not built", rather than sixteen
plausible-looking chapters.

The earlier lessons are kept in `docs/archive/`. They are worth a read, in the
way that a post-mortem is worth a read.
