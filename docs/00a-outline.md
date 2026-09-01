# elxrBB Tutorial Series Outline

## How this outline differs from the last one

The previous outline had sixteen lessons and two appendices. It was written
before any code existed, it put "Integrating Real-Time Updates" at lesson 11
and "Writing Tests" at lesson 14, and it never mentioned running the
application on more than one machine. It is preserved at
`archive/original-lessons/`.

This one is ordered by **what the board actually needs, hardest problem
first**, and it only lists a lesson as written once the code it teaches is
merged and tested in the application repository.

The reordering is not cosmetic. Real-time updates and presence are not a
feature you bolt on at lesson 11; they are the reason to build a bulletin board
in Elixir at all. Tests are not lesson 14; they are how you find out whether
the distributed thing you wrote is distributed.

## Part I — The core

Everything in Part I is dependency-free OTP. No framework, no database, no
containers. You can run all of it with nothing but Elixir installed.

| # | Lesson | State |
|---|---|---|
| 1 | [Setting up](01-setting-up.md) — Elixir, and a project with no dependencies | written |
| 2 | [The board and its boundary](02-the-board-and-its-boundary.md) — records, validation, and a store you can swap | written |
| 3 | [Events across a cluster](03-events-across-a-cluster.md) — `:pg`, presence, and hot counters | written |

## Part II — Persistence

| # | Lesson | State |
|---|---|---|
| 4 | The Postgres store — implementing the same behaviour against a real database | not written; code not built |
| 5 | Migrations, indexes, and the queries a forum index actually runs | not written; code not built |
| 6 | Flushing counters through to storage without blocking a page render | not written; code not built |

## Part III — The web layer

| # | Lesson | State |
|---|---|---|
| 7 | Phoenix as a delivery layer — adding it to a domain that already works | not written; code not built |
| 8 | The forum index and the topic view in LiveView | not written; code not built |
| 9 | Posting, editing, and optimistic updates | not written; code not built |
| 10 | "Who's online", wired to the presence server from lesson 3 | not written; code not built |
| 11 | Authentication, and why `User` has no password on it | not written; code not built |

## Part IV — Operating it

| # | Lesson | State |
|---|---|---|
| 12 | Clustering in production — discovery, and what `:pg` gives you for free | not written; code not built |
| 13 | Moderation: soft deletes, locking, and an audit trail | not written; code not built |
| 14 | Notifications, built on the event stream you already have | not written; code not built |
| 15 | Deploying a clustered release | not written; code not built |
| 16 | Accessibility, and why a forum is a good place to get it right | not written; code not built |

## Ideas that are not lessons yet

Kept here rather than promoted into the table, because nobody has built them:

- Search — full-text over posts, and whether it belongs in Postgres or beside it
- Attachments and media
- Rate limiting and spam defence, which on the BEAM is a per-user process problem
- Federation, which is the interesting version of "sub-topics"
- Upvotes and downvotes, which are a counter problem and mostly a moderation
  policy problem

## The rule

**A lesson is written after the code it describes is merged and tested.**

Three times now this project has produced a confident outline for software that
did not exist, and each time the outline aged into fiction. The table above
says "not written; code not built" instead of a completion percentage because
that is the true state, and because a plan that admits what it has not done is
worth more than one that does not.
