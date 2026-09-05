# Lesson 4: Threaded Replies, Sub-Topics and Voting

## Overview

Two features, one shape:

- **Threading.** A reply can answer another reply, not just the topic. That is
  all "sub-topics" ever meant — the original outline described the same feature
  twice, under two names.
- **Voting.** Members can upvote and downvote topics and replies, and sort by
  the result.

Both are small schema changes and a large amount of care about correctness.

## Part one: threading

### One column, and two constraints that keep it honest

```elixir priv/repo/migrations/20260902052043_add_threading_to_replies.exs
# priv/repo/migrations/..._add_threading_to_replies.exs
@max_depth 5

def change do
  alter table(:replies) do
    add :parent_id, references(:replies, on_delete: :delete_all)
    add :depth, :integer, null: false, default: 0
  end

  create index(:replies, [:parent_id])

  create constraint(:replies, :replies_depth_within_bounds,
           check: "depth >= 0 AND depth <= #{@max_depth}"
         )

  create constraint(:replies, :replies_depth_matches_parent,
           check: "(depth = 0) = (parent_id IS NULL)"
         )
end
```

**A self-referencing foreign key.** `replies.parent_id` points at `replies.id`.
With `on_delete: :delete_all`, deleting a reply deletes its children, whose
deletion deletes *their* children, all the way down — PostgreSQL walks the
self-reference itself. There is no recursive delete in application code, and
no orphaned subtree if a row is removed by anything other than your app.

**Why store `depth` at all?** It is derivable: walk up the parents and count.
But you need it on the way *in* — before inserting a reply you must know
whether its parent is already at the limit — and walking the chain is a query
per level. One integer, set once at insert, answers it with the row you
already have.

Denormalizing means the two facts can disagree, which is what the second
constraint is for: a reply is at depth zero exactly when it has no parent.
`(depth = 0) = (parent_id IS NULL)` compares two booleans, and PostgreSQL is
happy to do that.

### Schema

```elixir
# lib/elxrbb/forums/reply.ex
@max_depth 5

schema "replies" do
  field :body, :string
  field :depth, :integer, default: 0

  # Filled in by ElxrBB.Forums when a thread is loaded; not columns.
  field :score, :integer, virtual: true, default: 0
  field :user_vote, :integer, virtual: true
  field :descendants_count, :integer, virtual: true, default: 0
  field :children, {:array, :map}, virtual: true, default: []

  belongs_to :topic, Topic
  belongs_to :user, User
  belongs_to :parent, __MODULE__
  has_many :children_replies, __MODULE__, foreign_key: :parent_id
  has_many :votes, Vote

  timestamps(type: :utc_datetime)
end

def max_depth, do: @max_depth
```

`belongs_to :parent, __MODULE__` is how a schema references itself. The
`has_many :children_replies` is the other half — note it needs an explicit
`foreign_key:`, because Ecto would otherwise look for `reply_id`.

`:children` is a *virtual* field, separate from the `has_many`. The
association is how you would preload one level through Ecto; `:children` is
where we hang the tree we assemble ourselves, which is a different job.

### Creating a nested reply

```elixir lib/elxrbb/forums.ex
def create_reply(%Topic{} = topic, %User{} = user, attrs, opts \\ []) do
  case resolve_parent(topic, Keyword.get(opts, :parent)) do
    {:ok, parent} ->
      %Reply{
        topic_id: topic.id,
        user_id: user.id,
        parent_id: parent && parent.id,
        depth: (parent && parent.depth + 1) || 0
      }
      |> Reply.changeset(attrs)
      |> Repo.insert()
      |> preload_after_write([:user])

    {:error, reason} ->
      {:error, reply_parent_error(attrs, reason)}
  end
end

defp resolve_parent(_topic, nil), do: {:ok, nil}

defp resolve_parent(topic, %Reply{} = parent) do
  cond do
    parent.topic_id != topic.id -> {:error, :wrong_topic}
    parent.depth >= Reply.max_depth() -> {:error, :too_deep}
    true -> {:ok, parent}
  end
end

defp resolve_parent(topic, parent_id) do
  case Repo.get(Reply, parent_id) do
    nil -> {:error, :not_found}
    parent -> resolve_parent(topic, parent)
  end
end
```

Three things are being defended here, and each is a real attack or a real bug:

1. **A parent that does not exist.** The id came from a form field.
2. **A parent in a different topic.** Also from a form field. Without this
   check, a reply can be grafted onto a thread it does not belong to, and it
   would render there — the tree builder groups by `parent_id`, and would
   happily place it.
3. **A parent already at maximum depth.** Refused, not silently flattened.
   Quietly re-parenting someone's reply somewhere they did not choose is worse
   than telling them no.

Failures come back as `{:error, changeset}` with the message on `:parent_id`,
so the caller handles them exactly like a validation error.

Note `resolve_parent/2` accepts a `%Reply{}` *or* an id. The struct clause is
the one that does the work; the id clause loads and delegates. That way a
LiveView which already has the reply does not re-fetch it, and a caller which
only has an id does not have to.

### Building the tree

The context loads a thread flat and assembles it in memory:

```elixir lib/elxrbb/forums.ex
def list_reply_tree(topic_id, user, opts) do
  replies = list_replies(topic_id)
  tallies = vote_tallies(:reply_id, Enum.map(replies, & &1.id), user)

  replies
  |> Enum.map(&apply_tally(&1, tallies))
  |> build_tree(Keyword.get(opts, :order_by, :oldest))
end

defp build_tree(replies, order) do
  by_parent = Enum.group_by(replies, & &1.parent_id)

  attach(Map.get(by_parent, nil, []), by_parent, order)
end

defp attach(replies, by_parent, order) do
  replies
  |> sort_siblings(order)
  |> Enum.map(fn reply ->
    children = attach(Map.get(by_parent, reply.id, []), by_parent, order)

    %{
      reply
      | children: children,
        descendants_count:
          Enum.reduce(children, length(children), &(&1.descendants_count + &2))
    }
  end)
end
```

**Two queries, whatever the depth.** One for every reply in the topic, one for
the vote tallies. Contrast the naive approach — preload children, then their
children — which is a query per level, or a recursive CTE, which is a query but
harder to read and does not help here because we want every reply anyway.

`Enum.group_by(replies, & &1.parent_id)` puts the roots under the key `nil`,
which is exactly the entry point. The recursion is bounded by `max_depth`, so
there is no risk of running away — and if a cycle somehow got into the data,
the depth constraint would have rejected it at insert.

`descendants_count` accumulates on the way back up: each reply's count is its
direct children plus everything their counts already include. One pass, no
second traversal.

**Ordering applies within a level.** `sort_siblings/2` orders each set of
siblings, so a well-rated reply rises among its peers but never escapes its
parent — the thread stays a conversation.

```elixir lib/elxrbb/forums.ex
defp sort_siblings(replies, :oldest), do: Enum.sort_by(replies, &{&1.inserted_at, &1.id})
defp sort_siblings(replies, :newest), do: Enum.sort_by(replies, &{&1.inserted_at, &1.id}, :desc)
defp sort_siblings(replies, :score), do: Enum.sort_by(replies, &{-&1.score, &1.id})
```

The `&1.id` tiebreak is not decoration. Two replies posted in the same second
have equal `inserted_at` at `:utc_datetime` precision, and without a tiebreak
their order is whatever the database felt like — which means it can *change
between renders*, and LiveView will dutifully reorder the page under the
reader.

## Part two: voting

### One table for two kinds of target

A vote belongs to a topic or to a reply. The options are two tables, or one
table with two nullable foreign keys. We take the second:

```elixir priv/repo/migrations/20260902052044_create_votes.exs
create table(:votes) do
  add :value, :integer, null: false
  add :user_id, references(:users, on_delete: :delete_all), null: false
  add :topic_id, references(:topics, on_delete: :delete_all)
  add :reply_id, references(:replies, on_delete: :delete_all)

  timestamps(type: :utc_datetime)
end

create constraint(:votes, :votes_value_is_up_or_down, check: "value IN (-1, 1)")

create constraint(:votes, :votes_have_exactly_one_target,
         check: "(topic_id IS NULL) <> (reply_id IS NULL)"
       )

create unique_index(:votes, [:user_id, :topic_id],
         where: "topic_id IS NOT NULL",
         name: :votes_user_topic_index
       )

create unique_index(:votes, [:user_id, :reply_id],
         where: "reply_id IS NOT NULL",
         name: :votes_user_reply_index
       )
```

Both foreign keys stay real, so the database still enforces that a vote points
at a row that exists and cleans up when it does not. What it cannot infer is
that *exactly one* should be set, so we say so: on booleans, PostgreSQL's `<>`
is exclusive or.

**The unique indexes have to be partial.** "One vote per user per topic" is
`unique_index(:votes, [:user_id, :topic_id])` — except every reply vote has
`topic_id IS NULL`, and NULLs do not collide in a unique index, so those rows
would all sit there harmlessly. Which is fine. What is *not* fine is leaving it
implicit: `where: "topic_id IS NOT NULL"` says what you mean and keeps the
index small.

Storing the value as `1` and `-1` rather than a boolean means the score is
`SUM(value)`, which the database does directly.

### Casting a vote

```elixir
def vote(post, %User{} = user, value) when value in [-1, 1] do
  {field, id} = vote_target(post)

  result =
    case Repo.get_by(Vote, [{:user_id, user.id}, {field, id}]) do
      nil ->
        %Vote{user_id: user.id}
        |> Ecto.Changeset.change(%{field => id})
        |> Vote.changeset(%{value: value})
        |> Repo.insert()

      %Vote{value: ^value} = existing ->
        Repo.delete(existing)

      existing ->
        existing
        |> Vote.changeset(%{value: value})
        |> Repo.update()
    end

  case result do
    {:ok, _vote} -> {:ok, refresh_score(post, user)}
    {:error, changeset} -> {:error, changeset}
  end
end

defp vote_target(%Topic{id: id}), do: {:topic_id, id}
defp vote_target(%Reply{id: id}), do: {:reply_id, id}
```

`vote_target/1` is the whole polymorphism: two clauses that turn a struct into
the column it lives in. Everything downstream is uniform, and adding a third
votable thing later is one more clause.

Three cases, and the middle one is the interesting one. `%Vote{value: ^value}`
pins the argument — if the existing vote matches the one being cast, the vote
is *removed*. That is what every voting UI a reader has ever used does: click
up once to upvote, click it again to take it back. Switching direction moves
the score by two, which surprises people who expect one, and is correct.

### Reading scores without an N+1

```elixir lib/elxrbb/forums.ex
defp vote_tallies(field, ids, user) do
  scores =
    from(v in Vote,
      where: field(v, ^field) in ^ids,
      group_by: field(v, ^field),
      select: {field(v, ^field), sum(v.value)}
    )
    |> Repo.all()
    |> Map.new()

  mine =
    case user do
      %User{id: user_id} ->
        from(v in Vote,
          where: field(v, ^field) in ^ids and v.user_id == ^user_id,
          select: {field(v, ^field), v.value}
        )
        |> Repo.all()
        |> Map.new()

      _ ->
        %{}
    end

  %{scores: scores, mine: mine}
end
```

`field(v, ^field)` is how Ecto refers to a column chosen at runtime. It works
in `where`, `group_by` and `select` alike, which is what lets one function
serve both kinds of vote.

Two queries decorate an arbitrary number of posts, and the second is skipped
entirely for a reader who is not signed in — there is no "my vote" to look up.

**No counter column.** A `score` column on topics and replies would be faster
to read and permanently at risk of drifting from the votes that produced it.
Sum the rows. Revisit only when a profiler says to.

## The web layer

### A recursive function component

HEEx components can call themselves:

```heex lib/elxrbb_web/live/topic_live/show.ex
<.reply_thread
  :if={reply.children != []}
  replies={reply.children}
  current_scope={@current_scope}
  replying_to={@replying_to}
  reply_form={@reply_form}
  nested
/>
```

The recursion terminates because the tree the context hands us is bounded by
`Reply.max_depth/0` — the same constant the database enforces. A component
that recurses on unbounded data is a stack overflow waiting for a deep enough
thread.

### Inline reply forms, and a DOM id collision

Clicking **Reply** on a post sets `@replying_to` to that reply's id, and the
form renders under it. Simple enough — except the first version put two forms
on the page whose textareas both had `id="reply_body"`, because Phoenix derives
input ids from the form's name.

The LiveView test suite fails loudly on that:

```
** (RuntimeError) Duplicate id found while testing LiveView: reply_body
```

Which is a gift. Duplicate ids do not throw in a browser; they just make DOM
patching target the wrong element, and you find out later when a keystroke
lands in the wrong box. The fix is to name each input for its form:

```heex
<.input field={@form[:body]} id={"#{form_id(@target)}-body"} type="textarea" ... />
```

### Streams versus a tree

Lesson 3 rendered replies from a LiveView stream. This lesson replaces that
with a plain assign, reloaded after each change.

That is a real trade, made deliberately. A stream is a flat list the server
does not keep; a thread is a tree the server has to hold to render. Keeping
both would mean maintaining the tree separately from the stream and reconciling
them on every insert, for no benefit at the size a thread actually reaches.
Lesson 6 adds pagination, which is when this decision gets revisited.

### Trusting ids from the client

Every `phx-value-*` on the page arrives as a plain string in an event payload,
and anything holding the websocket open can send whatever it likes:

```elixir
def handle_event("vote", %{"kind" => kind, "id" => id, "value" => value}, socket) do
  case {current_user(socket), to_id(id), to_id(value)} do
    {nil, _id, _value} ->
      {:noreply, put_flash(socket, :error, "You must be logged in to vote.")}

    {user, post_id, direction} when not is_nil(post_id) and direction in [-1, 1] ->
      {:noreply, cast_vote(socket, kind, post_id, direction, user)}

    _ ->
      {:noreply, socket}
  end
end

defp cast_vote(socket, "reply", id, value, user) do
  topic_id = socket.assigns.topic.id

  case Forums.get_reply(id) do
    %Reply{topic_id: ^topic_id} = reply ->
      {:ok, _} = Forums.vote(reply, user, value)
      load_replies(socket)

    _ ->
      socket
  end
end
```

Three habits worth keeping:

**Parse, do not trust.** `String.to_integer/1` raises on `"abc"`, and a raise
in `handle_event/3` kills the LiveView process. `Integer.parse/1` behind a
`to_id/1` helper returns `nil` instead, and `nil` falls through to the
do-nothing clause.

**Check the id addresses something in scope.** A reply id is only acceptable if
that reply belongs to the topic *this* LiveView is showing. Without the pin on
`topic_id`, one open page is a lever on every reply in the database.

**Use the non-raising getter.** `get_reply!/1` raises `Ecto.NoResultsError` on
a made-up id — a 500 for the sender and noise in your logs. `get_reply/1`
returns `nil`, which the same clause already handles.

## Testing

The tests worth writing here are the ones about arithmetic and about refusal.

```elixir
test "changing direction moves the score by two, not one", %{topic: topic, user: user} do
  {:ok, topic} = Forums.vote(topic, user, 1)
  assert {:ok, topic} = Forums.vote(topic, user, -1)

  assert topic.score == -1
  assert topic.user_vote == -1
end

test "refuses to nest deeper than the maximum" do
  deepest =
    Enum.reduce(1..Reply.max_depth(), reply_fixture(), fn _, parent ->
      reply_fixture(parent: parent)
    end)

  topic = Forums.get_topic!(deepest.topic_id)

  assert {:error, changeset} =
           Forums.create_reply(topic, user_fixture(), %{body: "too deep"}, parent: deepest)

  assert "this thread cannot be nested any deeper" in errors_on(changeset).parent_id
end

test "the vote value is constrained at the database, not only in Elixir" do
  assert_raise Ecto.ConstraintError, ~r/votes_value_is_up_or_down/, fn ->
    Repo.insert!(%Vote{user_id: user.id, topic_id: topic.id, value: 7})
  end
end
```

That last one bypasses the changeset on purpose. A validation you have only
tested through the changeset is a validation you have only tested in Elixir;
this asserts the database would refuse the row too. Note it is
`Ecto.ConstraintError`, not `Postgrex.Error` — Ecto catches the constraint
violation and re-raises it with advice about `check_constraint/3`.

And the LiveView equivalents, which push events a hostile client would push:

```elixir test/elxrbb_web/live/topic_thread_test.exs
test "a vote aimed at another topic's reply is ignored", %{conn: conn} do
  topic = topic_fixture()
  elsewhere = reply_fixture()

  {:ok, lv, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/topics/#{topic}")

  lv |> render_click("vote", %{"kind" => "reply", "id" => elsewhere.id, "value" => "1"})

  assert Forums.with_score(Forums.get_reply!(elsewhere.id)).score == 0
end
```

## Try it

```bash
mix phx.server
```

1. Open a topic, post a reply, then press **Reply** on it and post again.
2. Watch the sub-reply count appear on the parent.
3. Vote on a post. Vote the same way again — the vote comes back off.
4. Nest five deep; the **Reply** action stops being offered.
5. Sort the thread by **Top rated** and watch siblings reorder in place.

## What is still missing

Open a second browser and reload: someone else's reply is not there until you
refresh. Everything in this lesson happens in one LiveView's own process.
Lesson 5 fixes that.

## Next

Lesson 5 makes the forum live for every reader at once, with
`Phoenix.PubSub`. It is [outlined](00a-outline.md) but not yet written.
