# Lesson 3: Forums, Topics and Replies

## Overview

This is the lesson where elxrBB becomes a forum. We build three tables, one
context, and five LiveViews:

- **Forums** group discussion by theme. Anyone can read them.
- **Topics** are threads inside a forum, written by a user.
- **Replies** are posts inside a topic, written by a user.

Reading is public. Posting requires an account. Editing and deleting require
being the author.

## The database

### Forums

```elixir
create table(:forums) do
  add :name, :string, null: false
  add :description, :text, null: false

  timestamps(type: :utc_datetime)
end

create unique_index(:forums, ["lower(name)"], name: :forums_lower_name_index)
```

Same case-insensitive uniqueness trick as usernames in lesson 2.

### Topics and replies

```elixir
create table(:topics) do
  add :title, :string, null: false
  add :body, :text, null: false
  add :forum_id, references(:forums, on_delete: :delete_all), null: false
  add :user_id, references(:users, on_delete: :delete_all), null: false

  timestamps(type: :utc_datetime)
end

create index(:topics, [:forum_id, "inserted_at DESC"])
create index(:topics, [:user_id])
```

```elixir
create table(:replies) do
  add :body, :text, null: false
  add :topic_id, references(:topics, on_delete: :delete_all), null: false
  add :user_id, references(:users, on_delete: :delete_all), null: false

  timestamps(type: :utc_datetime)
end

create index(:replies, [:topic_id, "inserted_at ASC"])
create index(:replies, [:user_id])
```

**`on_delete: :delete_all` is enforced by PostgreSQL**, not by Ecto. Deleting a
forum removes its topics and their replies in one statement, with no orphans
possible even if something writes to the database outside your app.

**The indexes match the queries, not the columns.** A forum page reads topics
for one `forum_id` ordered by time, so the index covers both. A thread reads
replies for one `topic_id` ordered the other way. Indexing `forum_id` alone
would still leave the database sorting on every page load.

## The schemas

Nothing surprising, but note where the associations point:

```elixir
# lib/elxrbb/forums/topic.ex
schema "topics" do
  field :title, :string
  field :body, :string

  # Filled in by the list queries below; not database columns.
  field :replies_count, :integer, virtual: true
  field :last_posted_at, :utc_datetime, virtual: true

  belongs_to :forum, Forum
  belongs_to :user, User
  has_many :replies, Reply

  timestamps(type: :utc_datetime)
end

def changeset(topic, attrs) do
  topic
  |> cast(attrs, [:title, :body])
  |> update_change(:title, &trim/1)
  |> validate_required([:title, :body])
  |> validate_length(:title, min: 3, max: 200)
  |> validate_length(:body, min: 1, max: 20_000)
  |> assoc_constraint(:forum)
  |> assoc_constraint(:user)
end
```

The changeset casts `:title` and `:body` and **not** `:forum_id` or `:user_id`.
Authorship is not something a form gets to submit. The context sets it.

`assoc_constraint/2` turns a foreign-key violation into a changeset error
instead of an exception — which is what you want if a forum is deleted between
rendering the form and submitting it.

## The context

`ElxrBB.Forums` is the whole business layer. Two design decisions run through
it.

**Writes take an explicit author.**

```elixir
def create_topic(%Forum{} = forum, %User{} = user, attrs) do
  %Topic{forum_id: forum.id, user_id: user.id}
  |> Topic.changeset(attrs)
  |> Repo.insert()
  |> preload_after_write([:forum, :user])
end
```

The context never reaches for an ambient "current user". It is handed one. That
keeps it testable without a connection, and makes it obvious at every call site
who is writing.

**Authorization is a predicate, not a side effect.**

```elixir
def topic_owner?(%Topic{user_id: user_id}, %User{id: user_id}), do: true
def topic_owner?(_topic, _user), do: false
```

Two clauses, matching on the same `user_id` binding twice so the ids must be
equal. The fall-through covers a different user *and* `nil` — an anonymous
visitor owns nothing. The web layer uses the same function to decide what to
render and to decide whether to accept a write.

### Counting replies without an N+1 and without a counter column

A forum page shows every topic with its reply count and the time of its most
recent post. The obvious implementations are both bad: a query per topic (N+1),
or a `replies_count` column that has to be kept correct forever.

The third option is one aggregate subquery:

```elixir
defp topics_with_counts do
  reply_stats =
    from(r in Reply,
      group_by: r.topic_id,
      select: %{topic_id: r.topic_id, count: count(r.id), last_posted_at: max(r.inserted_at)}
    )

  from(t in Topic,
    left_join: s in subquery(reply_stats),
    on: s.topic_id == t.id,
    order_by: [desc: coalesce(s.last_posted_at, t.inserted_at), desc: t.id],
    preload: [:user],
    select: %{
      t
      | replies_count: coalesce(s.count, 0),
        last_posted_at: type(coalesce(s.last_posted_at, t.inserted_at), :utc_datetime)
    }
  )
end
```

Points of interest:

- `left_join` plus `coalesce` gives a topic with no replies a count of `0`
  rather than dropping it or returning `nil`.
- Ordering by "most recent post, falling back to when the topic was created"
  floats active threads to the top, which is what a forum should do.
- **`type/2` is not optional.** `max(r.inserted_at)` loses its Ecto type on the
  way out of the subquery, so without it the virtual field comes back as a
  `NaiveDateTime` even though it is declared `:utc_datetime`. Anything
  pattern-matching on `%DateTime{}` downstream then fails. This one cost a test
  run to find; the test is in `forums_test.exs`.
- `select: %{t | ...}` merges into the struct, so callers still get a `%Topic{}`
  and not a bare map.

## The web layer

### Routes

```elixir
# Posting requires an account.
scope "/", ElxrBBWeb do
  pipe_through [:browser, :require_authenticated_user]

  live_session :forums_authenticated,
    on_mount: [{ElxrBBWeb.UserAuth, :require_authenticated}] do
    live "/forums/new", ForumLive.Form, :new
    live "/forums/:id/edit", ForumLive.Form, :edit
    live "/forums/:forum_id/topics/new", TopicLive.Form, :new
    live "/topics/:id/edit", TopicLive.Form, :edit
    live "/replies/:id/edit", ReplyLive.Form, :edit
  end
end

# Browsing is public; the scope is still mounted so authors see their controls.
scope "/", ElxrBBWeb do
  pipe_through :browser

  live_session :forums_public,
    on_mount: [{ElxrBBWeb.UserAuth, :mount_current_scope}] do
    live "/forums", ForumLive.Index, :index
    live "/forums/:id", ForumLive.Show, :show
    live "/topics/:id", TopicLive.Show, :show
  end
end
```

**Order matters.** Phoenix matches routes in declaration order, so
`/forums/new` has to come before `/forums/:id` or "new" is parsed as an id and
`Repo.get!` raises. Putting the authenticated scope first handles it.

**Two `live_session`s, two `on_mount` hooks.** `:require_authenticated`
redirects a signed-out visitor to the login page. `:mount_current_scope`
assigns the scope and lets them through — `@current_scope` is `nil` for a
guest, which templates check directly:

```heex
<.button :if={@current_scope} variant="primary" navigate={~p"/forums/new"}>
  <.icon name="hero-plus" /> New forum
</.button>
```

A LiveView cannot move between live sessions without a full page navigation, so
keep `navigate={...}` rather than `patch={...}` on links that cross the
boundary.

### Checking ownership twice

`TopicLive.Form` checks `topic_owner?/2` at mount, to decide whether to render
the form at all:

```elixir
defp apply_action(socket, :edit, %{"id" => id}) do
  topic = Forums.get_topic!(id)

  if Forums.topic_owner?(topic, socket.assigns.current_scope.user) do
    socket
    |> assign(:page_title, "Edit topic")
    |> assign(:topic, topic)
    |> assign(:form, to_form(Forums.change_topic(topic)))
  else
    socket
    |> put_flash(:error, "You can only edit your own topics.")
    |> push_navigate(to: ~p"/topics/#{topic}")
  end
end
```

...and again on save:

```elixir
defp save_topic(socket, :edit, topic_params) do
  %{topic: topic, current_scope: %{user: user}} = socket.assigns

  if Forums.topic_owner?(topic, user) do
    # ... update ...
  else
    # ... refuse ...
  end
end
```

That is not redundant. A LiveView holds a websocket open, and anything on the
other end of it can send any event it likes. **The mount-time check decides
what to render; it does not decide what to accept.** Every handler that writes
re-checks. The same applies to `delete_reply` and `delete_topic` in
`TopicLive.Show`.

### Streams for the reply list

`TopicLive.Show` keeps replies in a LiveView stream rather than an assign, so
posting a reply appends one `<li>` instead of re-rendering the thread:

```elixir
def handle_event("save_reply", %{"reply" => reply_params}, socket) do
  case Forums.create_reply(socket.assigns.topic, current_user(socket), reply_params) do
    {:ok, reply} ->
      {:noreply,
       socket
       |> update(:replies_count, &(&1 + 1))
       |> assign_reply_form()
       |> stream_insert(:replies, reply)}

    {:error, %Ecto.Changeset{} = changeset} ->
      {:noreply, assign(socket, reply_form: to_form(changeset))}
  end
end
```

The catch with streams: the server does not keep the list, so anything derived
from it — here, the reply count in the heading — has to be tracked separately.
`update(:replies_count, &(&1 + 1))` on insert, `&(&1 - 1)` on delete.

The markup needs `phx-update="stream"` on the container and an `id` on each
child:

```heex
<ul id="replies" phx-update="stream" class="divide-y divide-base-300">
  <li :for={{dom_id, reply} <- @streams.replies} id={dom_id} class="py-4">
    ...
  </li>
</ul>
```

## A bug worth repeating

Both the forum and the topic changesets trim whitespace:

```elixir
|> update_change(:name, &trim/1)
```

Write that as `&String.trim/1` and the app crashes with a
`FunctionClauseError` the moment someone submits an empty name. `cast/3` puts
`nil` in the changes, `update_change/3` calls the function with it, and
`String.trim/1` only accepts binaries. The nil-tolerant version lets
`validate_required` do its job:

```elixir
defp trim(nil), do: nil
defp trim(value) when is_binary(value), do: String.trim(value)
```

The generated `@invalid_attrs` test — the one you are tempted to delete because
it "just checks the obvious" — is what catches this.

## Seeds

`priv/repo/seeds.exs` creates five starter forums, and skips ones that already
exist so it is safe to re-run:

```elixir
existing = MapSet.new(Forums.list_forums(), &String.downcase(&1.name))

for attrs <- forums, not MapSet.member?(existing, String.downcase(attrs.name)) do
  {:ok, forum} = Forums.create_forum(attrs)
  IO.puts("created forum #{forum.name}")
end
```

## Testing

Fixtures take their associations as options, creating them on demand:

```elixir
def topic_fixture(attrs \\ %{}) do
  {forum, attrs} = Map.pop_lazy(Map.new(attrs), :forum, &forum_fixture/0)
  {user, attrs} = Map.pop_lazy(attrs, :user, &user_fixture/0)

  attrs = Enum.into(attrs, %{title: "some title", body: "some body"})

  {:ok, topic} = Forums.create_topic(forum, user, attrs)
  topic
end
```

`Map.pop_lazy/3` means a test that does not care about the forum does not pay
to create one explicitly, and a test that does can pass `forum: forum`.

The tests worth writing are the ones about permissions, because they are the
ones a click-through will not cover:

```elixir
test "a visitor cannot delete someone else's reply", %{conn: conn} do
  topic = topic_fixture()
  reply = reply_fixture(topic: topic)

  {:ok, lv, _html} = conn |> log_in_user(user_fixture()) |> live(~p"/topics/#{topic}")

  assert lv |> render_click("delete_reply", %{"id" => reply.id}) =~
           "You can only delete your own replies."

  assert [_] = Forums.list_replies(topic)
end
```

`render_click/3` pushes the event straight at the LiveView, bypassing the
markup — which is exactly what a hostile client does. If your only check is
`refute html =~ "Delete"`, you have tested that the button is hidden, not that
the action is refused.

## Try it

```bash
mix setup
mix phx.server
```

1. <http://localhost:4000/forums> — the seeded forums, with topic counts.
2. Register (lesson 2), then open a forum and press **New topic**.
3. Post a reply and watch it appear without a page load.
4. Sign out and reload: the thread is still readable, the controls are gone.

## Next

Lesson 4 adds threaded replies and voting on top of this structure.
