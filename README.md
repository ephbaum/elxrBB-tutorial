# elxrBB-tutorial

Building a phpBB-style bulletin board in Elixir — and using it as an excuse to
learn what the BEAM is actually for.

## Where this stands

Part I of the tutorial is written, and the code it teaches is
[merged and tested](https://github.com/ephbaum/elxrBB):

| # | Lesson | |
|---|---|---|
| 1 | [Setting up](docs/01-setting-up.md) | Elixir, and a project with no dependencies |
| 2 | [The board and its boundary](docs/02-the-board-and-its-boundary.md) | records, validation, and a store you can swap |
| 3 | [Events across a cluster](docs/03-events-across-a-cluster.md) | `:pg`, presence, and hot counters |

Start with the [introduction](docs/00b-introduction.md), or read the
[full outline](docs/00a-outline.md) for what Parts II–IV are meant to cover.
Thirteen of the sixteen lessons are marked "not written; code not built",
because they are.

**The rule this repository runs on:** a lesson is written after the code it
describes is merged and tested, and not before. See [STATUS.md](STATUS.md).

## Why that rule exists

This is the third attempt at this project. The first two both produced
confident, well-formatted lessons about software that did not exist.

### 2023 — the original

The README at the time is worth quoting, because it was right:

> This repo is the result of a recent conversation with ChatGPT (GPT-4). The
> clever little chatbot suggested in true ChatGPT Dunning-Kruger style, and I
> figured 🤷‍♂️, okay, maybe we can build a real tutorial from this conversation
>
> [...]
>
> This instance I'm working with keeps forgetting things, and I've spotted
> plenty of issues with its code as we've gone along so far, but this feels
> like a good opportunity to try to learn how to work with a LLM to accomplish
> larger projects
>
> I harbor no illusions that this will be successful. I'm sure some, if not
> most, of its code is crap, maybe even already outdated
>
> [...]
>
> I make no warranty. This is a work in progress and I have no idea what I'm
> doing (probably). ChatGPT and I seem to be having a pretty productive
> conversation, but this may all be made up bullshit. Do not rely on it until
> this document suggests otherwise.

It was made up. Six lessons were written; a Phoenix skeleton and some
`mix phx.gen.live` output were committed; the two never met. The model produced
a sixteen-lesson outline before a line of code existed, and everything
downstream inherited that confidence.

Preserved at [`docs/archive/original-lessons/`](docs/archive/original-lessons/).

### 2025 — the restart

Three lessons were cleaned up and the application repository was reset to a
README. The prose improved. The lessons still described an application nobody
had built — one of them says "INCOMPLETE - PLANNED" in its own title.

Preserved at [`docs/archive/restart-2025/`](docs/archive/restart-2025/).

### 2026 — this one

The application was rebuilt starting from the domain rather than the framework:
forums, topics and threaded replies; a persistence boundary; cluster-wide
events on `:pg`; who's-online presence replicated across nodes; write-hot
counters kept out of the database. 118 tests, including multi-node tests that
start real peer VMs and prove the distributed claims.

Then, and only then, the first three lessons.

## The premise

A bulletin board is a good excuse to use Elixir and a bad excuse to use most
other things. Almost everything a busy board does is a concurrency problem
wearing a CRUD costume — who's online, view counts, "someone replied while you
were reading", surviving a bad deploy. phpBB solved all four with a table, a
cron job, a page refresh, and hope. The BEAM has better primitives for each.

The tutorial is organised around those problems rather than around a
framework's directory layout, which is why real-time and clustering are in
Part I rather than at lesson 11.

## Contributing

Contributions are welcome, especially from people with real Elixir experience
who want to tell us we are wrong about something. The one thing that will be
turned down is a lesson for code that has not been written.

## Licence

GPL-3.0. The application lives at
[ephbaum/elxrBB](https://github.com/ephbaum/elxrBB).
