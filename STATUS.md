# Status

## The rule

**A lesson is written after the code it describes is merged and tested in the
application repository, and not before.**

Everything else on this page is bookkeeping for that one rule.

## Lessons

| # | Lesson | Code it teaches | State |
|---|---|---|---|
| 1 | [Setting up](docs/01-setting-up.md) | `mix.exs`, project layout | written |
| 2 | [The board and its boundary](docs/02-the-board-and-its-boundary.md) | `ElxrBB.Board`, `Board.Store`, `Board.Store.ETS`, the record modules | written |
| 3 | [Events across a cluster](docs/03-events-across-a-cluster.md) | `ElxrBB.PubSub`, `ElxrBB.Presence`, `ElxrBB.Counters` | written |
| 4–6 | Persistence | `Board.Store.Postgres` | code not built |
| 7–11 | The web layer | Phoenix / LiveView | code not built |
| 12–16 | Operating it | releases, clustering, moderation | code not built |

See [`docs/00a-outline.md`](docs/00a-outline.md) for what those later lessons
are expected to cover.

## Application

Repository: <https://github.com/ephbaum/elxrBB>

| Component | State |
|---|---|
| `ElxrBB.Board` — users, forums, topics, posts | done, tested |
| `ElxrBB.Board.Store` + ETS implementation | done, tested |
| `ElxrBB.PubSub` — `:pg`-backed cluster events | done, tested across real nodes |
| `ElxrBB.Presence` — who's online | done, tested across real nodes |
| `ElxrBB.Counters` — write-hot counters | done, tested under concurrency |
| `Board.Store.Postgres` | not started |
| Phoenix / LiveView | not started |

118 tests, including multi-node cluster tests that start real peer VMs.

## What "written" means for a lesson

1. The code it teaches is merged in the application repository.
2. The code it teaches has tests, and they pass.
3. Every snippet in the lesson is either copied from that code or runnable as
   written.
4. The lesson links to the file it is describing.

A lesson that fails any of those is not "in progress". It is archived, with a
note saying why. See [`docs/archive/`](docs/archive/).

## History

- **2023** — original attempt, written with GPT-4. Six lessons, a Phoenix
  skeleton, and no agreement between them. Archived at
  `docs/archive/original-lessons/`.
- **2025-10** — restart. Three lessons rewritten, application reset to a
  README. The lessons still described software nobody had built. Archived at
  `docs/archive/restart-2025/`.
- **2026-09** — this reset. Application rebuilt from the domain outward; the
  first three lessons written against code that exists.
