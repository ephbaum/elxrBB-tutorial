# Lesson 5: Implementing Threaded Replies and Subtopics

In this lesson, we'll be extending the functionality of our forum by implementing threaded replies and subtopics. This will allow users to reply to existing replies, creating a more interactive and engaging discussion experience. We'll also display the number of subtopics for each main topic in the list of threads view.

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

Add a new route to your `lib/elxr_bb_web/router.ex` file to handle the subtopics path:

```elixir
scope "/", ElxrBbWeb do
  ...
  get "/topics/:id/subtopics", TopicController, :subtopics
end
```

Lastly, modify the `show.html.eex` template in `lib/elxr_bb_web/templates/topic` to include a link to the subtopics:

```html
<!-- Add this line below the Replies heading -->
<p><%= link "View Subtopics", to: Routes.topic_path(@conn, :subtopics, @topic.id) %></p>
```

6. **Update the router**

Add a new route in `lib/elxr_bb_web/router.ex` to handle the subtopics view:

```elixir
get "/topics/:id/subtopics", TopicController, :subtopics
```

7. **Add a link to the subtopics view in the threads list**

In the `lib/elxr_bb_web/templates/topic/index.html.eex` file, update the table cell for the subtopics count to include a link to the subtopics view:

```elixir
<td><%= link length(topic.replies), to: Routes.topic_path(@conn, :subtopics, topic.id) %></td>
```

Now, you have successfully implemented threaded replies and subtopics in your elxrBB application. Users can now reply to existing replies, creating a more interactive and engaging discussion experience. The number of subtopics for each main topic is displayed in the list of threads view, providing users with an overview of the discussion depth.
