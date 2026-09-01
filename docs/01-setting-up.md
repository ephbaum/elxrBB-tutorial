# Lesson 1: Setting up

## What you need

Elixir 1.20 on Erlang/OTP 28. That is the whole list.

No PostgreSQL. No Docker. No Node. No Phoenix. Part I of this tutorial builds
the board's core, and the core has no dependencies — not as a stunt, but
because a domain you can run with nothing installed is a domain you will
actually run.

### Install Elixir

Follow <https://elixir-lang.org/install.html> for your platform.

**Use a version manager** — `mise` or `asdf` — rather than your system package
manager. Distribution packages lag badly: Ubuntu 24.04 ships Elixir 1.14 and
OTP 25, both from 2022, and OTP 25 no longer receives security patches. This
project is pinned in `.tool-versions`, so a version manager will pick the right
pair up on its own:

```console
$ mise install          # or: asdf install
```

Check it:

```console
$ elixir --version
Erlang/OTP 28 [erts-16.5] [source] [64-bit] [jit:ns]

Elixir 1.20.4 (compiled with Erlang/OTP 28)
```

Elixir 1.20 requires OTP 27 or newer. The code in this tutorial is written and
tested against 1.20 on OTP 28; `mix.exs` says so rather than claiming a wider
range nobody has run.

### A word about the type checker

Elixir 1.19 and 1.20 added gradual type checking: the compiler now infers types
for your functions and reports genuine contradictions — a call that can never
match, a value that cannot be what the next function needs.

Moving this project from Elixir 1.14 to 1.20 turned up exactly two complaints,
and both were worth having:

- `@type record :: ...` in the store behaviour shadowed a built-in type name.
  A naming bug, caught for free. It is `entity` now.
- A test asserted `Board.forum_topic(1) != Board.topic_topic(1)`. Those are
  `{:forum, _}` and `{:topic, _}` — disjoint types, so the comparison could
  never be false. A test that cannot fail, sitting there passing. It has been
  replaced with one that subscribes to a forum and broadcasts on a topic with
  the same id, which is what the assertion was reaching for.

Neither was a crash waiting to happen. Both were things a careful reviewer
should have caught and did not. That is a fair description of what this
checker is for.

## The project

```console
$ mix new elxrbb --sup
$ cd elxrbb
```

`--sup` gives you a supervision tree. It is the only flag that matters here:
everything in Part I is a supervised process, and the tree is where they get
started and where they get restarted when something goes wrong.

Open `mix.exs`. The interesting part is what is *not* in it:

```elixir
# The core is deliberately dependency-free: everything here is OTP.
# The web layer (Phoenix/LiveView) is a separate application that depends
# on this one -- see ARCHITECTURE.md.
defp deps do
  []
end
```

That comment is load-bearing, so it is worth being explicit about the claim.

## Why start with no dependencies

Three reasons, in order of how much they matter.

**Because the domain should be testable without infrastructure.** By the end of
lesson 3 the board has 118 tests that run in about a second, needing no
database, no broker and no containers. That is the difference between a suite
that gets run on every save and one that gets skipped.

**Because `:pg` and ETS are the right tools here, not fallbacks.**
`Phoenix.PubSub` is an excellent library, and it sits on top of the same OTP
facilities we are about to use directly. Using them directly makes the
mechanism visible — which is the point of a tutorial, and which is also how you
end up able to debug the library later.

**Because Phoenix is a delivery layer, and the code should say so.** Adding
Phoenix changes what the board can *serve*, not what it *means*. Both previous
attempts at this project started with `mix phx.new` and ended up with the
framework as the application: rules living in generated LiveViews, LiveViews
calling `Repo` directly, and nothing in between to test.

## The aliases worth adding

```elixir
defp aliases do
  [
    check: ["format --check-formatted", "compile --warnings-as-errors", "test"]
  ]
end
```

`mix check` is the thing you run before you commit. Warnings-as-errors matters
more in Elixir than in most languages, because the compiler catches genuinely
useful mistakes — an unmatched clause, a typo'd function name, a
pattern that can never match — and a project that tolerates warnings stops
reading them.

## Directory layout

By the end of Part I:

```
lib/elxrbb/
  application.ex          the supervision tree
  board.ex                the public API: users, forums, topics, posts
  board/
    schema.ex             validation helpers
    slug.ex               URL slugs
    user.ex forum.ex topic.ex post.ex     the records
    store.ex              the persistence behaviour
    store/ets.ex          an in-memory implementation
  pubsub.ex               cluster-wide events, on :pg
  presence.ex             who's online
  presence/state.ex       the replicated data structure behind it
  counters.ex             view counts and post counts
```

Two things about that layout are worth noticing now, because they are choices
rather than convention.

`board/store.ex` is a **behaviour**, not a module that talks to a database. The
domain never touches a table. Lesson 2 is largely about why.

`presence/state.ex` is **pure** — no processes, no messages, no side effects.
The GenServer in `presence.ex` owns the process and the monitors; everything
that decides *what the cluster believes* lives in the pure module and is tested
without starting anything. Lesson 3 is largely about why.

## Check it runs

```console
$ mix check
```

An empty project passes. It will keep passing for the rest of Part I, which is
the point of running it now.

---

Next: [Lesson 2 — The board and its boundary](02-the-board-and-its-boundary.md)
