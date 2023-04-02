# Lesson 6: Adding Private Messaging and User Profiles

In this lesson, we will implement private messaging between users, create user profiles with biographies and preferred names, implement an avatar system with file uploads, and configure file storage with Digital Ocean Block Storage.

1. **Implementing private messaging between users**

To implement private messaging, we will create a new `Message` schema and associated database table. First, create a new migration file:

```sh
mix ecto.gen.migration create_messages
```

Next, open the migration file and define the messages table with the following columns: `content`, `sender_id`, and `recipient_id`.

```elixir
defmodule ElxrBB.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :content, :string
      add :sender_id, references(:users, on_delete: :nothing)
      add :recipient_id, references(:users, on_delete: :nothing)

      timestamps()
    end
  end
end
```

Run the migration:

```sh
mix ecto.migrate
```

Now create the `Message` schema in `lib/elxr_bb/forum/message.ex`:

```elixir
defmodule ElxrBB.Forum.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    belongs_to :sender, ElxrBB.Accounts.User
    belongs_to :recipient, ElxrBB.Accounts.User

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content])
    |> validate_required([:content])
    |> assoc_constraint(:sender)
    |> assoc_constraint(:recipient)
  end
end
```

Next, create the `MessageController`, templates, and views for listing, creating, and deleting messages.

2. **Creating user profiles with biographies and preferred names**

Add `bio` and `preferred_name` fields to the `User` schema in `lib/elxr_bb/accounts/user.ex`:

```elixir
schema "users" do
  field :bio, :string
  field :preferred_name, :string
  # ... other fields ...

  timestamps()
end
```

Update the registration form and user edit form to include fields for the new `bio` and `preferred_name` attributes.

3. **Implementing an avatar system with file uploads**

To implement an avatar system, we will use the [Arc](https://github.com/stavro/arc) library. First, add Arc to your `mix.exs` dependencies:

```elixir
defp deps do
  [
    # ... other deps ...
    {:arc, "~> 0.11"}
  ]
end
```

Fetch the new dependency:

```sh
mix deps.get
```

Create an `Avatar` uploader module in `lib/elxr_bb_web/uploaders/avatar.ex`:

```elixir
defmodule ElxrBB.Avatar do
  use Arc.Definition

  # Store avatars in the "uploads/avatars" directory
  def storage_dir(_version), do: "uploads/avatars"

  # Generate unique filenames based on the user's ID
  def filename(version, {_file, user}), do: "#{user.id}_#{version}"
end
```

Add an `avatar` field to the `User` schema in `lib/elxr_bb/accounts/user.ex`:

```elixir
schema "users" do
  # ... other fields ...
  field :avatar, ElxrBB.Avatar.Type

  timestamps()
end
```

Update the registration and user edit forms to include an avatar upload field.

4. **Configuring file storage with Digital Ocean Block Storage**

To configure file storage with Digital Ocean Block Storage, we will use the [Arc Digital Ocean Spaces](https://github.com/stavro/arc_digitalocean_spaces) library. First, add Arc Digital Ocean Spaces to your `mix.exs` dependencies:

```elixir
defp deps do
  [
    # ... other deps ...
    {:arc_digitalocean_spaces, "~> 0.1"}
  ]
end
```

Fetch the new dependency:

```sh
mix deps.get
```

Configure Arc to use Digital Ocean Spaces by adding the following configuration to your `config/config.exs` file:

```elixir
config :arc,
  storage: Arc.Storage.DigitalOceanSpaces,
  digitalocean_spaces: [
    space: "your-space-name",
    region: "your-space-region",
    access_key_id: "your-access-key-id",
    secret_access_key: "your-secret-access-key"
  ]
```

Now, your elxrBB application has private messaging, user profiles with biographies and preferred names, an avatar system with file uploads, and file storage with Digital Ocean Block Storage. Users can now send private messages to each other, customize their profiles, and upload avatars to enhance their presence on the forum.
