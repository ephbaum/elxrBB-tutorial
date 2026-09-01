# Lesson 2: The board and its boundary

Code: [`lib/elxrbb/board.ex`](https://github.com/ephbaum/elxrBB/blob/main/lib/elxrbb/board.ex),
[`lib/elxrbb/board/`](https://github.com/ephbaum/elxrBB/tree/main/lib/elxrbb/board),
tests in [`test/elxrbb/board_test.exs`](https://github.com/ephbaum/elxrBB/blob/main/test/elxrbb/board_test.exs).

## What a board is, minus the web

Four records:

```
User        who wrote a post, who is online, who can moderate
Forum       the container topics are posted into
Topic       a thread; knows its forum, its author, and its last post
Post        a message; may have a parent, for threaded replies
```

They are plain structs. `lib/elxrbb/board/topic.ex`:

```elixir
defstruct [
  :id,
  :forum_id,
  :user_id,
  :title,
  :slug,
  :inserted_at,
  :last_post_at,
  :last_post_id,
  pinned?: false,
  locked?: false
]
```

`:last_post_at` is denormalised onto the topic on purpose. It is what a forum
index sorts by, and recomputing it from posts on every index render is the
second-most-common bulletin-board performance mistake. (The first is view
counts; that is lesson 3.)

## Validation without Ecto

Every record has a `new/1` that validates:

```elixir
def new(attrs) do
  Schema.build(__MODULE__, attrs, [:id, :username, :email, :bio, :role, :inserted_at], [
    &Schema.required(&1, [:username]),
    &Schema.length(&1, :username, 3, 32),
    &Schema.format(&1, :username, @username_format, "may only contain letters, digits, _ and -"),
    &Schema.length(&1, :bio, 0, 2_000),
    &Schema.inclusion(&1, :role, @roles)
  ])
end
```

Errors come back as a keyword list — `{:error, [username: "is required"]}` — so
a form can render them next to fields without translating anything.

This is not a rebuild of Ecto and it must not become one. `ElxrBB.Board.Schema`
is 90 lines and implements four rules: required, length, format, inclusion.
When the Postgres store lands, Ecto comes with it for queries and migrations —
and these rules stay exactly where they are, so they keep applying no matter
which store is underneath.

That is the first hint of the shape of this lesson: **the rules belong to the
board, not to the database.**

## The store boundary

`ElxrBB.Board` never touches a table, a query, or a connection. It talks to a
behaviour:

```elixir
@callback insert(kind(), record()) :: {:ok, record()} | {:error, {:taken, atom()}}
@callback update(kind(), id(), (record() -> record())) :: {:ok, record()} | {:error, :not_found}
@callback fetch(kind(), id()) :: {:ok, record()} | :error
@callback fetch_by(kind(), atom(), term()) :: {:ok, record()} | :error
@callback list_topics(id(), keyword()) :: [Topic.t()]
@callback list_posts(id(), keyword()) :: [Post.t()]
```

Records are addressed by a `kind` atom — `:user`, `:forum`, `:topic`, `:post` —
so a store implements six callbacks rather than twenty-four.

Which store is used is configuration:

```elixir
config :elxrbb, store: ElxrBB.Board.Store.ETS
```

### Why this seam is the whole lesson

The 2023 version of this project had generated LiveViews calling generated
contexts calling `Repo` directly. Look at what that costs:

- **Nothing to test at.** Every domain test needs a database, a sandbox, and a
  connection pool. So domain tests get written last, or not at all.
- **Nothing to cache at.** There is no single place where "fetch this topic"
  happens, so there is no place to put a cache when you need one.
- **Nothing to reason about.** "What are the rules for creating a post?" has no
  answer, because the rules are spread across a changeset, a context function,
  and a LiveView's `handle_event`.
- **No second implementation, ever.** Not because you want to swap Postgres for
  something else — you almost never do — but because the *ability* to is what
  proves the domain does not secretly depend on the database's behaviour.

The seam costs one behaviour module. It is the cheapest architectural decision
in this project and the one the previous attempts most needed.

## Reads and writes are not the same problem

`ElxrBB.Board.Store.ETS` is the in-memory implementation, and it is a
deliberate demonstration of a pattern you will use again:

```elixir
# Reads go straight to ETS, in the calling process.
def fetch(kind, id) do
  case :ets.lookup(table(kind), id) do
    [{^id, record}] -> {:ok, record}
    [] -> :error
  end
end

# Writes go through the server.
def insert(kind, record) when kind in @kinds do
  GenServer.call(__MODULE__, {:insert, kind, record})
end
```

Reads never message the server. A thousand concurrent page renders run
genuinely in parallel across every scheduler, because `:ets.lookup/2` is
performed by whichever process calls it.

Writes go through one process, and that buys a total order for free. Two people
replying to the same topic in the same millisecond both update
`last_post_at`; because the read-modify-write happens inside a single process,
neither can read a value the other has already superseded. That is why `update`
takes a *function* rather than a new record:

```elixir
defp touch_last_post(topic_id, post) do
  store().update(:topic, topic_id, fn topic ->
    %{topic | last_post_at: post.inserted_at, last_post_id: post.id}
  end)
end
```

The function runs inside the store's serialisation. There is no window between
the read and the write for anyone else to get in.

Ids are the exception. They need atomicity, not ordering, so they come from
`:ets.update_counter/3` on a sequence table rather than from the server.

There is a test for exactly this claim:

```elixir
test "simultaneous replies to one topic all land, and last_post_id is one of them" do
  posts =
    1..50
    |> Enum.map(fn n ->
      Task.async(fn ->
        Board.create_post(%{topic_id: topic.id, user_id: user.id, body: "reply #{n}"})
      end)
    end)
    |> Task.await_many(:timer.seconds(30))

  ids = Enum.map(posts, fn {:ok, post} -> post.id end)
  assert length(Enum.uniq(ids)) == 50
  assert length(Board.list_posts(topic.id)) == 51
end
```

Fifty concurrent writers, no lost posts, no duplicated ids. Run it with
`mix test test/elxrbb/board_test.exs`.

## Creating a topic is two writes that must both happen

```elixir
with {:ok, topic} <- Topic.new(stamp(attrs)),
     :ok <- ensure_forum_open(topic.forum_id),
     {:ok, draft} <-
       Post.new(stamp(%{topic_id: @draft_topic_id, user_id: topic.user_id, body: body})),
     {:ok, topic} <- insert(:topic, topic),
     {:ok, post} <- insert(:post, %{draft | topic_id: topic.id}) do
```

The opening post is *validated* before the topic is *written*. A topic with no
posts is not a thing a bulletin board should be able to represent, and without
a transaction to lean on, the way to avoid one is to do all the failing up
front. There is a test that a rejected body leaves no empty topic behind.

When the Postgres store arrives it will wrap this in a transaction and the
ordering will stop mattering. It costs nothing to be correct without one in the
meantime.

## Soft deletes

```elixir
def delete_post(post_id) do
  # ...
  {:ok, post} = store().update(:post, post_id, &%{&1 | deleted_at: now()})
```

A moderator removing a post sets `:deleted_at`. The row stays. Threaded replies
hanging off it keep their parent, the audit trail survives, and rendering
decides whether to show a tombstone or hide the row. `list_posts/2` filters
deleted posts by default and takes `include_deleted: true` for moderation
views.

Deleting twice is idempotent, and there is a test for it, because moderation
UIs double-submit.

## Try it

```console
$ iex -S mix
```

```elixir
{:ok, forum} = ElxrBB.Board.create_forum(%{name: "Elixir & OTP"})
{:ok, ada}   = ElxrBB.Board.create_user(%{username: "ada"})

{:ok, topic, post} =
  ElxrBB.Board.create_topic(%{
    forum_id: forum.id,
    user_id: ada.id,
    title: "Why processes?",
    body: "Because failure is local."
  })

topic.slug              #=> "why-processes"
topic.last_post_id      #=> post.id

ElxrBB.Board.create_user(%{username: "ada"})
#=> {:error, [username: "has already been taken"]}

ElxrBB.Board.create_user(%{username: "not a username"})
#=> {:error, [username: "may only contain letters, digits, _ and -"]}
```

## Exercises

1. **Add a `Forum.parent_id` listing.** The field already exists on the record.
   Write `list_child_forums/1` in the store behaviour, implement it for ETS,
   and expose it from `ElxrBB.Board`. Notice that you touch three files and no
   tests break.

2. **Make `fetch_by/3` honest.** The ETS implementation scans every record. Add
   an index table for `:username` and `:slug` and keep it in step on insert.
   The behaviour does not change; the tests do not change.

3. **Write a second store.** A `Board.Store.Null` that returns `:error` for
   every fetch and `{:ok, record}` for every insert. Run the board test suite
   against it and read the failures: they are a precise description of what the
   domain assumes about persistence.

---

Next: [Lesson 3 — Events across a cluster](03-events-across-a-cluster.md)
