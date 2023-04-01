# Lesson 3: Implementing User Authentication and Registration

In this lesson, we'll implement user authentication and registration for the elxrBB application using the [Pow library](https://powauth.com/). We'll also set up email verification and create a system for generating random usernames.

## Add Pow to elxrBB

First, we need to add the Pow library to our `mix.exs` file. Open the file and add `{:pow, "~> 1.0"}` to the `deps` function:

```elixir
defp deps do
  [
    # ...
    {:pow, "~> 1.0"}
  ]
end
```

Then, run `mix deps.get` to fetch the new dependency.

## Configure Pow

In `config/config.exs`, add the following configuration for Pow:

```elixir
config :elxrBB, :pow,
  user: elxrBB.Users.User,
  repo: elxrBB.Repo,
  web_module: elxrBBWeb

config :elxrBB, :pow_extension_mailer_backend, elxrBBWeb.Pow.Mailer
```

## Generate Pow Templates

Run the following command to generate Pow templates:

```
mix pow.phoenix.gen.templates
```

## Install and Configure Pow Routes

In `lib/elxrBB_web/router.ex`, add `use Pow.Phoenix.Router` and `pow_routes()` to the `:browser` pipeline:

```elixir
pipeline :browser do
  # ...
  plug :fetch_session
  plug :fetch_flash
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug Pow.Phoenix.Router
end

scope "/", elxrBBWeb do
  pipe_through :browser
  # ...
  pow_routes()
end
```

## Create the User Schema

Create a new file, `lib/elxrBB/users/user.ex`, and define the `User` schema:

```elixir
defmodule elxrBB.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema

  schema "users" do
    pow_user_fields()

    field :preferred_name, :string
    field :bio, :string

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> pow_changeset(attrs)
    |> Ecto.Changeset.cast(attrs, [:preferred_name, :bio])
    |> Ecto.Changeset.validate_required([:preferred_name, :bio])
  end
end
```

## Create the Repo

Create a new file, `lib/elxrBB/users/users.ex`, and define the `Users` context:

```elixir
defmodule elxrBB.Users do
  alias elxrBB.Repo
  alias elxrBB.Users.User

  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def get_user_by_confirmation_token(token), do: Repo.get_by(User, confirmation_token: token)

  def get_user_by_id(id), do: Repo.get(User, id)

  def get_user_by_password_reset_token(token), do: Repo.get_by(User, password_reset_token: token)

  def list_users, do: Repo.all(User)

  def register_user(attrs), do: User.changeset(%User{}, attrs) |> Repo.insert()

  def update_user(user, attrs), do: User.changeset(user, attrs) |> Repo.update()

  def delete_user(user), do: Repo.delete(user)
end
```

## Update the View and Template

In `lib/elxrBB_web/views/pow/registration_view.ex`, add the following function to generate random usernames:

```elixir
defmodule elxrBBWeb.Pow.RegistrationView do
  use elxrBBWeb, :view
  alias elxrBB.Users.User

  def random_username do
    animals = ["lion", "tiger", "bear", "zebra", "giraffe", "penguin", "koala", "elephant", "rhino", "kangaroo"]
    animal = Enum.random(animals)
    number = :rand.uniform(9999)
    "#{animal}-#{number}"
  end
end
```

_Note: In a later lesson, we will implement a large pool of animal names stored in the database._

Now, update the registration template (`lib/elxrBB_web/templates/pow/registration/new.html.eex`) to include the random username generation functionality:

```html
<%= form_for @changeset, Routes.pow_registration_path(@conn, :create), fn f -> %>
  <%= if @changeset.action do %>
    <div class="alert alert-danger">
      <p>Oops, something went wrong! Please check the errors below:</p>
    </div>
  <% end %>

  <%= label f, :email %>
  <%= text_input f, :email %>
  <%= error_tag f, :email %>

  <%= label f, :password %>
  <%= password_input f, :password %>
  <%= error_tag f, :password %>

  <%= label f, :password_confirmation %>
  <%= password_input f, :password_confirmation %>
  <%= error_tag f, :password_confirmation %>

  <%= label f, :preferred_name, "Preferred Name (Randomized by default)" %>
  <%= text_input f, :preferred_name, value: @changeset.data.preferred_name || random_username() %>
  <%= error_tag f, :preferred_name %>

  <%= label f, :bio %>
  <%= textarea f, :bio %>
  <%= error_tag f, :bio %>

  <%= submit "Register" %>
<% end %>
```

This will pre-fill the preferred name field with a randomly generated username. Users can click the "Randomize" button to generate a new random username.

Now that we have implemented user authentication and registration, we can move on to the next lesson, where we'll implement the forum functionality.
