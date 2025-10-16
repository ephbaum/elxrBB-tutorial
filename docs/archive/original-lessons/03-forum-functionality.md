# Lesson 3: Implementing Basic Forum Functionality

In this lesson, we'll implement basic forum functionality for the elxrBB application, including creating topics, replying to topics, and displaying a list of topics.

1. Create a new context `Forums` in `lib/elxrBB/forums/forums.ex`. Define the `Topic` and `Reply` schemas in this file.

```elixir
defmodule ElxrBB.Forums.Topic do
  use Ecto.Schema
  import Ecto.Changeset

  schema "topics" do
    field :title, :string
    field :content, :string
    has_many :replies, elxrBB.Forums.Reply
    belongs_to :user, elxrBB.Users.User

    timestamps()
  end

  def changeset(topic, attrs) do
    topic
    |> cast(attrs, [:title, :content])
    |> validate_required([:title, :content])
    |> assoc_constraint(:user)
  end
end

defmodule ElxrBB.Forums.Reply do
  use Ecto.Schema
  import Ecto.Changeset

  schema "replies" do
    field :content, :string
    belongs_to :topic, elxrBB.Forums.Topic
    belongs_to :user, elxrBB.Users.User

    timestamps()
  end

  def changeset(reply, attrs) do
    reply
    |> cast(attrs, [:content])
    |> validate_required([:content])
    |> assoc_constraint(:topic)
    |> assoc_constraint(:user)
  end
end
```

---

In Elixir and the Phoenix framework, a context is a design pattern used to organize related functionality and separate concerns within an application. A context represents a specific part of the application's domain and encapsulates the logic and data access for that part.

Contexts help you organize your code by grouping related functions and data models. They act as a boundary that separates different parts of the application, promoting a clear separation of concerns and making it easier to understand and maintain the code.

In a Phoenix application, a context is typically a module that defines functions and uses Ecto for data access. It interacts with one or more schema modules representing the underlying database tables and relationships.

For example, if you are building a blog application, you might have contexts like Blog, Accounts, and Comments. The Blog context would contain functions for managing blog posts, the Accounts context would contain functions for managing users and authentication, and the Comments context would contain functions for managing comments on blog posts.

By grouping related functions and data models into contexts, you make it easier to manage the complexity of your application, improve maintainability, and provide a clear structure for future development.

---

2. Create the necessary functions in the `Forums` context to perform CRUD operations on topics and replies.

```elixir
defmodule ElxrBB.Forums do
  alias ElxrBB.Forums.{Topic, Reply}
  alias ElxrBB.Repo

  # Topic functions
  def list_topics, do: Repo.all(Topic)

  def get_topic!(id), do: Repo.get!(Topic, id)

  def create_topic(attrs, user) do
    %Topic{}
    |> Topic.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  def update_topic(topic, attrs) do
    topic
    |> Topic.changeset(attrs)
    |> Repo.update()
  end

  def delete_topic(topic), do: Repo.delete(topic)

  # Reply functions
  def list_replies, do: Repo.all(Reply)

  def get_reply!(id), do: Repo.get!(Reply, id)

  def create_reply(attrs, topic, user) do
    %Reply{}
    |> Reply.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:topic, topic)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  def update_reply(reply, attrs) do
    reply
    |> Reply.changeset(attrs)
    |> Repo.update()
  end

  def delete_reply(reply), do: Repo.delete(reply)
end
```

3. Create the necessary controller actions and views to handle topics and replies.

To create the necessary controller actions and views using .heex templates, you'll need to create the corresponding controllers and templates for topics and replies. I'll provide a brief outline of the necessary steps.

Create a topic_controller.ex in the controllers directory:

```elixir
defmodule ElxrBBWeb.TopicController do
  use ElxrBBWeb, :controller

  alias ElxrBB.Forums
  alias ElxrBB.Forums.Topic

  # Implement your actions here, e.g., index, show, new, create, edit, update, delete
end
```

Create a reply_controller.ex in the controllers directory:

```elixir
defmodule ElxrBBWeb.ReplyController do
  use ElxrBBWeb, :controller

  alias ElxrBB.Forums
  alias ElxrBB.Forums.Reply

  # Implement your actions here, e.g., create, update, delete
end
```

Create a topic_view.ex in the views directory:

```elixir
defmodule ElxrBBWeb.TopicView do
  use ElxrBBWeb, :view
end
```

Create a reply_view.ex in the views directory:

```elixir
defmodule ElxrBBWeb.ReplyView do
  use ElxrBBWeb, :view
end
```

Create templates using .heex files in the templates/topic and templates/reply directories. Here's an example for templates/topic/index.

```html
<section>
  <h1>Topics</h1>
  <table>
    <thead>
      <tr>
        <th>Title</th>
        <th>Content</th>
      </tr>
    </thead>
    <tbody>
      <%= for topic <- @topics do %>
        <tr>
          <td><%= topic.title %></td>
          <td><%= topic.content %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</section>
```

Now, you can create the other .heex templates like new, show, edit, etc., for topics, and also create the necessary templates for replies.


---

Side note, getting this thing to actually produce everything here is like pulling teeth right now. Normally ChatGPT seems gung-ho about producing everything but not today, it seems. 

Also, the structure here seems a bit different than how I it's laid out in my project 🤔

Also, because I think this seems to be trying to get me to do a lot more work than I would like, I started looking at the possible generators for this code and sure enough, I found: `mix phx.gen.html` and `mix phx.gen.live` which seem to create the context, controller, views, etc. for a given HTML or LiveView resource. 

I started a new ChatGPT thread and now we're trying something to the `mix phx.gen.live` commands to see what we can do:

Forum:

`mix phx.gen.live Forums Forum forums title:string description:text`

Topic:

`mix phx.gen.live Forums Topic topics title:string body:text forum_id:references:forums`

Reply:

`mix phx.gen.live Forums Reply replies body:text topic_id:references:topics user_id:references:users`

This feels like it makes a bit more sense from my experience 😅

Of course now I have a bunch of files but have no idea how to update my route and ChatGPT seems to be giving me wrong information 🙄 I think I'm giving up for tonight 

---

4. Update the router to add routes for topics and replies.

5. Create the necessary templates to display a list of topics, view a single topic with replies, and create new topics and replies.

After completing this lesson, you'll have a basic forum system where users can create topics and reply to them. In the next lesson, we'll implement more advanced features like upvoting and downvoting, as well as threaded replies.
