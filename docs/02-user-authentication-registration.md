# Lesson 2: Implementing User Authentication and Registration

In this lesson, we'll implement user authentication and registration for the elxrBB application using the [Pow library](https://powauth.com/). We'll also set up email verification and create a system for generating random usernames.

The Pow website does a great job extolling the virtues of the Pow system, but let it suffice to say that it does a lot of the hard work for you. 

It's worth noting that you should probably dig in and understand the work that it's doing. There's a lot of value in learning to write your own authentication functionality, but this should give us a little bit of a boost in just creating our application since the library claims to be "batteries included" for production out-of-the-box. 

That said, with no idea how this works, I'm about to embark on trying to make this work based on these instructions (that may hail back to the pre-2021 ChatGPT memory cut-off)

## Add Pow to elxrBB

The instructions are prety clear, and can be found [here](https://hexdocs.pm/pow/README.html#installation). 

First, we need to add the Pow library to our `mix.exs` file. Open the file and add `{:pow, "~> 1.0"}` to the `deps` function:

```elixir
defp deps do
  [
    # ...
    {:pow, "~> 1.0"}
  ]
end
```

Next run `mix deps.get` to fetch the new dependency.

Then you'll need to run `docker-compose exec app mix pow.install` to create and update the necessary files for Pow

Now, for this tutorial, we'll want to exposed the Pow Templates: `mix pow.phoenix.gen.templates` which will allow us to modify the templates later. 

Next we'll enable [some extensions](https://hexdocs.pm/pow/README.html#add-extensions-support): 

`mix pow.extension.phoenix.gen.templates --extension PowResetPassword --extension PowEmailConfirmation`

and then update some files:

``` config/config.exs
config :my_app, :pow,
  ...
  extensions: [PowResetPassword, PowEmailConfirmation],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks
```

(also user.ex and router.ex will need updated -- see link above)

Now we'll create the Mailer Integration, so follow [those instructions](https://hexdocs.pm/pow/README.html#mailer-support)

This will have you create a mock mailer (instead of using swoosh?) and add it to your config so that now the emails will be logged to the debugger logfile, and here I am still stuffing this all into the first step of this particular step and still just trying to get things configured :le_sigh:

⌛

I'm all over the place trying to get this working - I'm struggling a little bit. Seems ChatGPT might have been a bit eager with the `users` schema, so I made the needed migration for that and updated

I also tried to build a `users` repo as described below, and added a users_test - which seems to have gottem me into a whole new set of troubles, but I'm making progress - I'm down to one test that I'm not quite grokking and, try as it might, neither is ChatGPT

At this point, I'm still working my way through this document, however. 

I think I might be close to implementing everything for this lesson, but may need to make some improvements to make the document less a recipe and more an explanation - it also feels very light on direction :laughing:

I'm pleased to have made any progress of any sort, and some of these things are making some sense :)

16 Apr 2023 - 

I'm back, hello there- what a mess I'm making, eh?

I have added a couple of files to this project recently related to the Gerund Verb + Animal Name + Rnadom _n_ digit username behavior, and of course I'm rabbit holing a little bit on this behavior, but I think it will be worth it in the end. 

I'm in the process of updating the project to use the username field - to try to keep things clean, and understanding it's not really intended to work this way, I tried to alter the existing migration and drop the whole DB to start over but I think the test DB is not getting the memo, so I will deal with this broken tests soon. 

Meanwhile, in addition to adding `:username` to the user schema, I also edited the `config.exs` and so that it looks like this: 

```config.exs
config :elxrBB, :pow,
  web_mailer_module: ElxrBBWeb,
  web_module: ElxrBBWeb,
  user: ElxrBB.Users.User,
  repo: ElxrBB.Repo,
  extensions: [PowResetPassword, PowEmailConfirmation],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  mailer_backend: ElxrBB.Pow.Mailer,
  identity_field: :username
```

Which added the `identity_field: :username` k/v pair to our `:pow` configuration

Maybe it's supposed to be  `user_id_field: :username` - that's something to look into: 😅

Good night...

---

Below may be dragons, above too, probably - EB

---

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

    field :username, :string
    field :bio, :string

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> pow_changeset(attrs)
    |> Ecto.Changeset.cast(attrs, [:username, :bio])
    |> Ecto.Changeset.validate_required([:username, :bio])
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

  <%= label f, :username, "Username (Randomized by default)" %>
  <%= text_input f, :username, value: @changeset.data.username || random_username() %>
  <%= error_tag f, :username %>

  <%= label f, :bio %>
  <%= textarea f, :bio %>
  <%= error_tag f, :bio %>

  <%= submit "Register" %>
<% end %>
```

This will pre-fill the username field with a randomly generated username. Users can click the "Randomize" button to generate a new random username.

Now that we have implemented user authentication and registration, we can move on to the next lesson, where we'll implement the forum functionality.
