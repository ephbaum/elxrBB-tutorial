# Lesson 1: Setting Up the Environment and Creating the elxrBB Project

## Overview

We install Elixir, Erlang/OTP and PostgreSQL, then generate the elxrBB
application with the Phoenix project generator. By the end you will have a
running Phoenix server on <http://localhost:4000>.

## What you need first

- A command line, Git, and an editor.
- Roughly 2 GB of free disk for the toolchain and dependencies.

## Versions this tutorial was written against

The reference application is built and tested with:

| | Version |
|---|---|
| Elixir | 1.20.4 |
| Erlang/OTP | 28 |
| Phoenix | 1.8.13 |
| PostgreSQL | 16 |

The application's `mix.exs` requires Elixir 1.17 or newer, so anything at or
above that will work. If you are following along exactly, matching the table
saves surprises.

## Installing Elixir and Erlang

The official installer fetches precompiled builds and does not need a version
manager:

```bash
curl -fsSO https://elixir-lang.org/install.sh
sh install.sh elixir@1.20.4 otp@28.5.0.6
```

It prints two `export PATH=...` lines. Add them to your shell profile
(`~/.bashrc`, `~/.zshrc`) and reload it.

If you prefer a version manager, [asdf](https://asdf-vm.com) or
[mise](https://mise.jdx.dev) both work; use their `erlang` and `elixir`
plugins. On macOS, `brew install elixir` installs a recent pair.

Verify:

```bash
elixir --version
# Erlang/OTP 28 ...
# Elixir 1.20.4 (compiled with Erlang/OTP 28)
```

> **Locale note.** If Elixir warns about `native name encoding of latin1`, your
> shell locale is not UTF-8. Set `LANG=C.UTF-8` (or your own UTF-8 locale), or
> export `ELIXIR_ERL_OPTIONS="+fnu"`.

## Installing Hex, Rebar and the Phoenix generator

```bash
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new --force
```

`mix phx.new --version` should now report `Phoenix installer v1.8.13` or newer.

## Installing PostgreSQL

**Debian/Ubuntu**

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo service postgresql start
```

**macOS**

```bash
brew install postgresql@16
brew services start postgresql@16
```

Phoenix's development configuration expects a `postgres` role with the password
`postgres`. On a fresh Debian/Ubuntu install:

```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
```

## Node.js is not required

Phoenix 1.8 builds assets with standalone [esbuild](https://esbuild.github.io)
and [Tailwind](https://tailwindcss.com) binaries that `mix` downloads for you.
There is no `package.json` and no `npm install`. You only need Node if you add a
JavaScript toolchain of your own later.

## Generating the project

```bash
mix phx.new elxrbb --module ElxrBB --database postgres
cd elxrbb
```

Two things about that command:

- **`--live` is redundant.** LiveView is included by default in Phoenix 1.8.
  The flag is still accepted and does nothing; older tutorials (including this
  one, before it was rewritten) pass it out of habit.
- **`--module ElxrBB`.** The OTP application name has to be a lowercase atom, so
  the project is `:elxrbb` on disk while the Elixir modules are namespaced
  `ElxrBB` / `ElxrBBWeb`. The original 2023 attempt tried to name the project
  `elxrBB` directly, which the generator rejects.

Answer `Y` when it offers to fetch dependencies.

## Database setup and first run

```bash
mix setup      # deps.get, ecto.create, ecto.migrate, seeds, assets
mix phx.server
```

Visit <http://localhost:4000>. You should see the Phoenix welcome page.

`mix setup` is defined as an alias in `mix.exs`; look at it now, because it is
the one command you will run after every `git pull` for the rest of the series.

## What the generator gave you

```
elxrbb/
├── assets/                  # app.css, app.js — built by esbuild + tailwind
├── config/                  # config.exs, dev.exs, test.exs, prod.exs, runtime.exs
├── lib/
│   ├── elxrbb/              # contexts: your business logic
│   │   ├── application.ex   # the OTP supervision tree
│   │   ├── mailer.ex
│   │   └── repo.ex          # the Ecto repository
│   ├── elxrbb_web/          # everything HTTP
│   │   ├── components/      # core_components.ex, layouts
│   │   ├── controllers/
│   │   ├── endpoint.ex      # the plug pipeline
│   │   └── router.ex
│   └── elxrbb.ex
├── priv/repo/migrations/
├── test/
└── mix.exs
```

The split that matters: `lib/elxrbb/` holds **contexts** — plain modules that
own the data and the rules. `lib/elxrbb_web/` holds the web layer, which calls
into contexts and knows nothing about SQL. Every lesson from here adds to both
sides of that line, and keeping the line clean is most of what "idiomatic
Phoenix" means.

Two more files worth opening now:

- `lib/elxrbb_web/components/core_components.ex` — the `<.button>`,
  `<.input>`, `<.header>`, `<.table>` function components every template uses.
  Phoenix 1.8 styles them with [daisyUI](https://daisyui.com) on top of
  Tailwind 4.
- `lib/elxrbb_web/components/layouts.ex` — `<Layouts.app>`, the wrapper every
  page renders inside.

## Useful commands

```bash
mix test                   # run the test suite (it creates its own database)
mix format                 # format all code
mix precommit              # compile with warnings-as-errors, format, test
iex -S mix phx.server      # server with an attached REPL
```

`mix precommit` is generated for you and is the check to run before every
commit in this series.

## Troubleshooting

**`connection refused` from Ecto** — PostgreSQL is not running, or is not
listening where `config/dev.exs` expects. Check `pg_isready`.

**`password authentication failed for user "postgres"`** — set the password as
shown above, or edit `config/dev.exs` to match the role you actually have.

**`Port 4000 in use`** — something else is on it. `http: [port: 4001]` in
`config/dev.exs` moves the server.

**Live reload complains about `inotify-tools`** — a development-only
convenience; install `inotify-tools` on Linux or ignore it.

## Next

[Lesson 2](02-user-authentication.md) adds accounts: registration, login,
email confirmation, and the animal-themed usernames elxrBB hands out.
