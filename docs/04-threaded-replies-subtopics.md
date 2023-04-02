# Lesson 4: Implementing Threaded Replies and Upvoting/Downvoting

In this lesson, we'll be extending the functionality of our forum by implementing threaded replies, upvoting, and downvoting. This will allow users to reply to existing replies, creating a more interactive and engaging discussion experience. Additionally, users will be able to upvote and downvote topics and replies.

1. **Add a parent_id field to the replies table**

To enable threaded replies, we'll need to add a `parent_id` field to the replies table. This field will store the ID of the parent reply, allowing us to create a hierarchy of replies. Open the migration file for the replies table and add the following line:

```elixir
add :parent_id, references(:replies, on_delete: :nothing), null: true
```

Run the migration to update the database:

```sh
mix ecto.migrate
```

2. **Update the Reply schema**

Next, update the `Reply` schema in `lib/elxr_bb/forum/reply.ex` to include the new `parent_id` field and the association with the parent reply:

```elixir
schema "replies" do
  field :content, :string
  field :parent_id, :id
  belongs_to :topic, ElxrBB.Forum.Topic
  belongs_to :user, ElxrBB.Accounts.User
  belongs_to :parent_reply, ElxrBB.Forum.Reply, foreign_key: :parent_id

  timestamps()
end
```

3. **Modify the reply form to support threaded replies**

In the `lib/elxr_bb_web/templates/reply/form.html.eex` file, add a hidden field for the `parent_id`:

```elixir
<%= hidden_input f, :parent_id, value: @parent_id %>
```

Update the `new` function in `lib/elxr_bb_web/controllers/reply_controller.ex` to accept a `parent_id` parameter and pass it to the template:

```elixir
def new(conn, %{"topic_id" => topic_id, "parent_id" => parent_id}) do
  changeset = Forum.change_reply(%Reply{})
  render(conn, "new.html", changeset: changeset, topic_id: topic_id, parent_id: parent_id)
end
```

4. **Display the subtopics count in the threads view**

In the `lib/elxr_bb_web/templates/topic/index.html.eex` file, add a column to display the number of subtopics for each main topic:

```elixir
<th>Subtopics</th>
```

In the table row, add a new cell to display the subtopics count:

```elixir
<td><%= length(topic.replies) %></td>
```

5. **Create a view for subtopics**

To display subtopics, create a new template at `lib/elxr_bb_web/templates/topic/subtopics.html.eex`:

```html
<h2>Subtopics for "<%= @topic.title %>"</h2>

<%= for reply <- @topic.replies do %>
  <div class="subtopic">
    <h3><%= reply.content %></h3>
    <p>Posted by <%= reply.user.username %> on <%= Timex.format!(reply.inserted_at, "%B %-e, %Y") %></p>
  </div>
<% end %>
```

Update the `TopicController` in `lib/elxr_bb_web/controllers/topic_controller.ex` to add a `subtopics` action:

```elixir
def subtopics(conn, %{"id" => id}) do
  topic = ElxrBb.Forum.get_topic!(id)
  render(conn, "subtopics.html", topic: topic)
end
```

6. **Create Upvote and Downvote functionality**

To add upvote and downvote functionality, we need to create a new schema called `Vote`. Generate a new context called `Votes` with the following command:

```sh
mix phx.gen.context Votes Vote votes user_id:references:users reply_id:references:replies value:integer
```

Run the migration:

```sh
mix ecto.migrate
```

Next, update the `Vote` schema in `lib/elxr_bb/votes/vote.ex` to include associations with the `User` and `Reply` schemas:

```elixir
schema "votes" do
  field :value, :integer
  belongs_to :user, ElxrBB.Accounts.User
  belongs_to :reply, ElxrBB.Forum.Reply

  timestamps()
end
```

7. **Update the Reply schema to include votes**

Update the `Reply` schema in `lib/elxr_bb/forum/reply.ex` to include the association with the `Vote` schema:

```elixir
schema "replies" do
  field :content, :string
  field :parent_id, :id
  has_many :votes, ElxrBB.Votes.Vote
  belongs_to :topic, ElxrBB.Forum.Topic
  belongs_to :user, ElxrBB.Accounts.User
  belongs_to :parent_reply, ElxrBB.Forum.Reply, foreign_key: :parent_id

  timestamps()
end
```

8. **Create Upvote and Downvote controller actions**

Update the `ReplyController` in `lib/elxr_bb_web/controllers/reply_controller.ex` to include upvote and downvote actions:

```elixir
def upvote(conn, %{"id" => id}) do
  reply = Forum.get_reply!(id)
  {:ok, _vote} = Votes.upvote(conn.assigns.current_user, reply)
  redirect(conn, to: Routes.topic_path(conn, :show, reply.topic_id))
end

def downvote(conn, %{"id" => id}) do
  reply = Forum.get_reply!(id)
  {:ok, _vote} = Votes.downvote(conn.assigns.current_user, reply)
  redirect(conn, to: Routes.topic_path(conn, :show, reply.topic_id))
end
```

9. **Create Upvote and Downvote functions in the Votes context**

Open the `Votes` context in `lib/elxr_bb/votes/votes.ex` and create the `upvote` and `downvote` functions:

```elixir
def upvote(user, reply) do
  vote_changeset = %Vote{}
  |> change_vote(user, reply, 1)

  Repo.insert(vote_changeset)
end

def downvote(user, reply) do
  vote_changeset = %Vote{}
  |> change_vote(user, reply, -1)

  Repo.insert(vote_changeset)
end

defp change_vote(changeset, user, reply, value) do
  changeset
  |> Ecto.Changeset.cast(%{value: value}, [:value])
  |> Ecto.Changeset.put_assoc(:user, user)
  |> Ecto.Changeset.put_assoc(:reply, reply)
end
```

10. **Update the router to include upvote and downvote routes**

In your `lib/elxr_bb_web/router.ex` file, add new routes for upvote and downvote actions:

```elixir
scope "/", ElxrBbWeb do
  ...
  post "/replies/:id/upvote", ReplyController, :upvote
  post "/replies/:id/downvote", ReplyController, :downvote
end
```

11. **Display upvotes and downvotes in the UI**

Update the `lib/elxr_bb_web/templates/topic/show.html.eex` file to display the upvotes and downvotes for each reply:

```html
<%= if length(reply.votes) > 0 do %>
  <span class="vote-count">Votes: <%= Enum.sum(reply.votes, fn vote -> vote.value end) %></span>
<% end %>

<%= link "Upvote", to: Routes.reply_path(@conn, :upvote, reply.id), method: :post %>
<%= link "Downvote", to: Routes.reply_path(@conn, :downvote, reply.id), method: :post %>
```

With these steps, you have now completed Lesson 4, implementing threaded replies along with upvoting and downvoting functionality. Users can now interact with replies by upvoting or downvoting them, which will be displayed in the user interface.
