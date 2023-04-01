# Lesson 4: Implementing Basic Forum Functionality

In this lesson, we'll implement basic forum functionality for the elxrBB application, including creating topics, replying to topics, and displaying a list of topics.

1. Create a new context `Forums` in `lib/elxrBB/forums/forums.ex`. Define the `Topic` and `Reply` schemas in this file.

```elixir
defmodule elxrBB.Forums.Topic do
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

defmodule elxrBB.Forums.Reply do
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

2. Create the necessary functions in the `Forums` context to perform CRUD operations on topics and replies.

```elixir
defmodule elxrBB.Forums do
  alias elxrBB.Forums.{Topic, Reply}
  alias elxrBB.Repo

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

4. Update the router to add routes for topics and replies.

5. Create the necessary templates to display a list of topics, view a single topic with replies, and create new topics and replies.

After completing this lesson, you'll have a basic forum system where users can create topics and reply to them. In the next lesson, we'll implement more advanced features like upvoting and downvoting, as well as threaded replies.
