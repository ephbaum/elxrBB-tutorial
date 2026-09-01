# Lesson 3: Events across a cluster

Code: [`lib/elxrbb/pubsub.ex`](https://github.com/ephbaum/elxrBB/blob/main/lib/elxrbb/pubsub.ex),
[`lib/elxrbb/presence.ex`](https://github.com/ephbaum/elxrBB/blob/main/lib/elxrbb/presence.ex),
[`lib/elxrbb/presence/state.ex`](https://github.com/ephbaum/elxrBB/blob/main/lib/elxrbb/presence/state.ex),
[`lib/elxrbb/counters.ex`](https://github.com/ephbaum/elxrBB/blob/main/lib/elxrbb/counters.ex).
Tests in [`test/elxrbb/cluster_test.exs`](https://github.com/ephbaum/elxrBB/blob/main/test/elxrbb/cluster_test.exs).

This is the lesson the previous two versions of this project never reached, and
it is the reason to build a bulletin board in Elixir.

## Part 1 — PubSub, in about forty lines

`:pg` is OTP's process groups. It ships with Erlang, it replicates group
membership to every connected node, and it removes members when they die. That
is a distributed pub/sub with the hard parts already done.

The whole subscription mechanism:

```elixir
@scope __MODULE__

def child_spec(_opts) do
  %{id: @scope, start: {:pg, :start_link, [@scope]}, type: :worker}
end

def subscribe(topic), do: :pg.join(@scope, topic, self())

def broadcast(topic, message) do
  @scope |> :pg.get_members(topic) |> Enum.each(&send(&1, message))
end
```

`:pg.get_members/2` returns members on **every connected node**. `send/2` to a
remote pid is transparent. So a broadcast from any node reaches a subscriber on
any other node, and nothing in those four lines knows that.

Three details worth stealing:

**Topics are terms, not strings.** `{:topic, 42}` rather than `"topic:42"`. It
is cheaper to build, it cannot collide with `{:forum, 42}` by accident, and it
pattern-matches.

**Subscribers receive plain process messages.** A GenServer handles them in
`handle_info/2`; a LiveView handles them in `handle_info/2`. There is no
subscriber behaviour to implement.

**Cleanup is free.** `:pg` drops a member when the process dies and drops a
whole node's members when the node goes. There is no unsubscribe path to get
wrong on the crash route, which is the route that actually happens.

The board uses it to announce every change, carrying the whole record:

```elixir
PubSub.broadcast(topic_topic(topic.id), {:post_created, post})
PubSub.broadcast(forum_topic(topic.forum_id), {:topic_updated, topic})
```

Carrying the record rather than an id matters: a subscriber that already has
the list in memory can prepend, instead of re-querying on every reply. That is
what makes a busy topic cheap to keep open.

## Part 2 — Presence

"Who's online" is the feature at the bottom of every phpBB index page, and it
is the one phpBB got most wrong: a table, written to on every request, cleaned
up by a cron job that guessed at timeouts.

The right shape on the BEAM is: **presence is memory, held by the process that
represents the connection, replicated to peers, and gone when the process is.**

### The data structure

```
%{node() => %{topic => %{key => %{ref => meta}}}}
```

Read that outside-in. The state is a map of **node slices**. Each node writes
only to its own slice and ships that slice to its peers.

This is a state-based CRDT, and a very small one — because a node only ever
writes to its own slice, two nodes can never disagree about the same entry.
There is nothing to resolve. Merging is "take each node's word for its own
slice":

```elixir
def list(%__MODULE__{} = state, topic) do
  Enum.reduce(state.slices, %{}, fn {_node, slice}, acc ->
    slice
    |> Map.get(topic, %{})
    |> Enum.reduce(acc, fn {key, refs}, acc ->
      Map.update(acc, key, Map.values(refs), &(&1 ++ Map.values(refs)))
    end)
  end)
end
```

A node leaving is a `Map.delete/2` on its slice, which is exactly right:
everyone connected through that node is gone too.

Metas are keyed by a unique `ref` rather than stored in a list, so the same
user with three browser tabs produces three metas that can be removed
independently. The user goes offline when the last one does — not the first.

### The pure/impure split

`ElxrBB.Presence.State` is pure. No processes, no messages. It is tested
without starting anything:

```elixir
test "a node leaving does not disturb the surviving nodes' view" do
  state =
    State.new()
    |> State.put(@a, @topic, 1, ref(1), %{})
    |> State.put(@b, @topic, 1, ref(2), %{})

  state = State.drop_node(state, @b)

  # The user still has a live connection on @a, so they are still online.
  assert State.present?(state, @topic, 1)
end
```

`ElxrBB.Presence` is the GenServer, and it owns only three things: the
monitors, the replication, and an ETS cache of the merged view.

That split is worth internalising as a habit. Anything that decides *what is
true* goes in the pure module and gets tested exhaustively for microseconds.
Anything that decides *when* goes in the process. Most "we can't test our
distributed system" is really "we put the logic inside the message loop".

### Cleanup is a monitor

```elixir
def handle_call({:track, pid, topic, key, meta}, _from, state) do
  ref = make_ref()

  state =
    state
    |> monitor(pid, ref)
    |> put_ref(ref, pid, topic, key)
    |> apply_local({:put, topic, key, ref, meta})

  {:reply, {:ok, ref}, state}
end

def handle_info({:DOWN, _monitor, :process, pid, _reason}, state) do
  refs = state.monitors |> Map.get(pid, %{}) |> Map.keys()
  state = Enum.reduce(refs, state, &forget(&2, &1))
  {:noreply, %{state | monitors: Map.delete(state.monitors, pid)}}
end
```

A closed browser, a crashed LiveView and a `kill -9`'d node all arrive through
the same path. There is no timeout to tune and no sweeper to schedule. This is
the single largest thing the BEAM gives you over the phpBB design, and it is
sixteen lines.

### Reads do not queue behind the server

Rendering "42 users online" on a hot index page must not send a message to one
process. So the server keeps a merged view in ETS and readers go straight
there:

```elixir
def list(topic) do
  case :ets.lookup(@table, {:list, topic}) do
    [{_, presences}] -> presences
    [] -> %{}
  end
end

defp refresh_table(state, topic) do
  case State.list(state.presence, topic) do
    empty when map_size(empty) == 0 -> :ets.delete(state.table, {:list, topic})
    presences -> :ets.insert(state.table, {{:list, topic}, presences})
  end
end
```

The merge cost is paid once per change, by the writer, instead of once per read
by every reader. That is the right trade for a board, where far more people are
looking than joining.

### The bug you will write

On boot, this server introduces itself to everyone already connected:

```elixir
# Nodes we are already connected to will never send us a `:nodeup`, so on
# boot we introduce ourselves and ask for their slice in the same message.
for node <- Node.list(), do: push_sync(node, state, :respond)
```

The first version pushed its own slice and did not ask for theirs. On
`:nodeup` that is fine — both sides get the event, both sides push. But a node
that boots *after* the connection already exists gets no `:nodeup`, pushes its
empty slice, and never learns who is already online.

It passed every single-node test. It was caught by the cluster test in the next
section, on the one case where a node joins late.

## Part 3 — Counters

`UPDATE topics SET views = views + 1` on every page load is the hottest write
in a bulletin board, contending on exactly the rows people are reading. The
number is also the least important thing on the page: nobody minds if it is a
few seconds stale.

```elixir
def bump(key, delta \\ 1) when is_integer(delta) do
  ensure_row(key)
  [base, pending] = :ets.update_counter(@table, key, [{@base_pos, 0}, {@pending_pos, delta}])
  base + pending
end
```

`:ets.update_counter/3` is atomic and is performed by the *calling* process on
a table opened with `write_concurrency`. Ten thousand concurrent readers of a
hot topic do not queue behind a GenServer and do not touch the database.

A flusher drains the accumulated deltas to a sink in batches. The interesting
line is the drain:

```elixir
{key, _base, delta}, acc ->
  :ets.update_counter(@table, key, [{@base_pos, delta}, {@pending_pos, -delta}])
  Map.put(acc, key, delta)
```

It subtracts *exactly the delta it observed*, rather than setting pending to
zero. Increments that land between the read and the subtraction are carried
into the next window instead of being clobbered. The test hammers this with
concurrent writers and flushers and asserts the total is exact.

`get/1` returns `base + pending`, so reads are always current even though
writes are deferred.

**The trade is explicit and it is a real one.** If a node dies between flushes,
that window of view counts is gone. That is correct for view counts and wrong
for posts, which is why posts are written through the store instead. Say which
of your numbers are which, out loud, in the moduledoc — the mistake is not
choosing the fast path, it is choosing it silently.

## Part 4 — Proving it

Everything above claims to work across a cluster. The previous versions of this
project made that claim too, without ever running two of the application.

`test/elxrbb/cluster_test.exs` starts real peer VMs with `:peer`, adds the
project's code path, boots the application on each, and connects them:

```elixir
defp start_peer(name) do
  {:ok, pid, node} =
    :peer.start_link(%{
      name: :"elxrbb_#{name}_#{System.unique_integer([:positive])}",
      host: ~c"127.0.0.1",
      longnames: true,
      args: [~c"-setcookie", Atom.to_charlist(Node.get_cookie())]
    })

  :erpc.call(node, :code, :add_pathsz, [:code.get_path()])
  {:ok, _started} = :erpc.call(node, Application, :ensure_all_started, [:elxrbb])

  {pid, node}
end
```

Then it asserts on things that only exist across a cluster:

```elixir
test "a reply written on one node is announced on the other", %{a: a, b: b} do
  {_forum_id, topic_id} = :erpc.call(node_name(a), Helper, :seed_topic, [])
  pubsub_topic = ElxrBB.Board.topic_topic(topic_id)

  :erpc.call(node_name(b), Helper, :relay, [pubsub_topic, self()])
  assert_receive {:subscribed, ^pubsub_topic}, 5_000

  :erpc.call(node_name(a), Helper, :reply, [topic_id, "from the other node"])

  assert_receive {:relayed, {:post_created, %{body: "from the other node"}}}, 5_000
end

test "a node going down takes its users offline and leaves the rest", %{a: a, b: b} do
  track(a, topic, 1, %{})
  track(b, topic, 2, %{})
  assert eventually(fn -> presence_count(a, topic) == 2 end)

  stop_peer(b)

  assert eventually(fn -> presence_count(a, topic) == 1 end)
  assert Map.keys(:erpc.call(node_name(a), ElxrBB.Presence, :list, [topic])) == [1]
end
```

```console
$ mix test --include distributed
1 doctest, 118 tests, 0 failures
```

One practical note, because it costs an hour if you meet it cold: **a peer
cannot run a closure defined in a test module.** ExUnit compiles test modules
in memory and never writes them to disk, so the peer has nothing to load. Put
the code the peer runs in `test/support/`, which *is* compiled into `_build`
and therefore reachable over the code path. That is what
`ElxrBB.ClusterHelper` is for.

## See it yourself

Two terminals:

```console
$ iex --sname a --cookie board -S mix
$ iex --sname b --cookie board -S mix
```

```elixir
# on b
iex(b@host)> Node.connect(:a@host)
iex(b@host)> ElxrBB.Presence.track({:forum, 1}, 2, %{username: "grace"})

# on a
iex(a@host)> ElxrBB.Presence.track({:forum, 1}, 1, %{username: "ada"})
iex(a@host)> ElxrBB.Presence.count({:forum, 1})
2
iex(a@host)> ElxrBB.Presence.list({:forum, 1})
%{1 => [%{username: "ada"}], 2 => [%{username: "grace"}]}
```

Now kill node `b` — `Ctrl-C` twice — and ask node `a` again:

```elixir
iex(a@host)> ElxrBB.Presence.count({:forum, 1})
1
```

Nothing swept anything. A node went away, its slice went with it, and everyone
who was connected through it went offline at the same instant.

## Exercises

1. **Add a typing indicator.** `Presence.update/2` already takes a function
   over the current meta. Set `typing?: true`, subscribe to the presence topic
   in `iex` on the other node, and watch the diff arrive.

2. **Break the drain on purpose.** Change `Counters` to set pending to `0`
   instead of subtracting the observed delta, and run
   `mix test test/elxrbb/counters_test.exs`. Read which test fails and why.

3. **Find the sync bug yourself.** Revert the `:respond` flag in
   `Presence.init/1` so boot pushes without asking, and run
   `mix test --include distributed`. Exactly one test fails. Notice that no
   single-node test does.

4. **Count something new.** Add a per-forum "posts in the last hour" counter
   and work out what it would take to make it a *window* rather than a total.
   This is harder than it looks and is the beginning of a good conversation
   about what ETS is and is not for.

---

That is Part I. The board has a domain, a persistence boundary, cluster-wide
events, presence, and counters — and a test suite that proves the distributed
claims on real nodes.

Part II adds Postgres behind the store behaviour. Part III adds Phoenix in
front. Neither of them changes anything you have read in these three lessons,
which was the point.
