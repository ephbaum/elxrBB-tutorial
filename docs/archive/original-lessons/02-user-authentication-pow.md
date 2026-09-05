# Lesson 2: User Authentication with Pow

## Overview

In this lesson, we'll implement user authentication for the elxrBB application using the Pow library. Pow provides a robust, production-ready authentication system with features like email confirmation, password reset, and session management.

## Why Pow?

Pow is a batteries-included authentication library for Phoenix that provides:

- User registration and login
- Email confirmation
- Password reset functionality
- Session management
- Extensible architecture
- Production-ready security features

## Adding Pow to the Project

### 1. Add Pow Dependencies

Add Pow to your `mix.exs` file:

```elixir
# mix.exs
defp deps do
  [
    # ... existing dependencies ...
    {:pow, "~> 1.0.29"},
    {:bcrypt_elixir, "~> 2.0"}
  ]
end
```

Install the new dependencies:

```bash
mix deps.get
```

### 2. Install Pow

Run the Pow installer:

```bash
mix pow.install
```

This command will:

- Create a User schema
- Generate database migrations
- Update your router configuration
- Create Pow configuration

### 3. Configure Pow Extensions

Install Pow extensions for email confirmation and password reset:

```bash
mix pow.extension.phoenix.gen.templates --extension PowResetPassword --extension PowEmailConfirmation
```

### 4. Update Pow Configuration

Update your `config/config.exs` file with the complete Pow configuration:

```elixir
# config/config.exs
config :elxrBB, :pow,
  web_mailer_module: ElxrBBWeb,
  web_module: ElxrBBWeb,
  user: ElxrBB.Users.User,
  repo: ElxrBB.Repo,
  extensions: [PowResetPassword, PowEmailConfirmation],
  controller_callbacks: Pow.Extension.Phoenix.ControllerCallbacks,
  mailer_backend: ElxrBB.Pow.Mailer
```

### 5. Create the Pow Mailer

Create the mailer file for handling authentication emails:

```elixir
# lib/elxrBB_web/mails/pow/mailer.ex
defmodule ElxrBB.Pow.Mailer do
  use Pow.Phoenix.Mailer
  require Logger

  def cast(%{user: user, subject: subject, text: text, html: html, assigns: _assigns}) do
    %{to: user.email, subject: subject, text: text, html: html}
  end

  def process(email) do
    # In development, we'll just log emails
    # In production, you'd integrate with a real email service
    Logger.debug("E-mail sent: #{inspect email}")
  end
end
```

### 6. Update the User Schema

The Pow installer creates a basic User schema. Let's enhance it with additional fields:

```elixir
# lib/elxrBB/users/user.ex
defmodule ElxrBB.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  use Pow.Extension.Ecto.Schema,
    extensions: [PowResetPassword, PowEmailConfirmation]

  schema "users" do
    pow_user_fields()

    field :username, :string
    field :bio, :string

    timestamps()
  end

  def changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
    |> Ecto.Changeset.cast(attrs, [:username, :bio])
    |> Ecto.Changeset.validate_length(:username, min: 3, max: 20)
    |> Ecto.Changeset.validate_length(:bio, max: 500)
    |> Ecto.Changeset.unique_constraint(:username)
  end
end
```

### 7. Update the Users Context

Create or update the Users context:

```elixir
# lib/elxrBB/users/users.ex
defmodule ElxrBB.Users do
  alias ElxrBB.Repo
  alias ElxrBB.Users.User

  def get_user_by_email(email), do: Repo.get_by(User, email: email)
  def get_user_by_id(id), do: Repo.get(User, id)
  def get_user_by_username(username), do: Repo.get_by(User, username: username)
  def list_users, do: Repo.all(User)

  def register_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end
end
```

### 8. Update the Router

Ensure your router includes Pow routes:

```elixir
# lib/elxrBB_web/router.ex
defmodule ElxrBBWeb.Router do
  use ElxrBBWeb, :router
  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router,
    extensions: [PowResetPassword, PowEmailConfirmation]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ElxrBBWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Pow authentication routes
  scope "/" do
    pipe_through :browser

    pow_routes()
    pow_extension_routes()
  end

  # Application routes
  scope "/", ElxrBBWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Development routes
  if Application.compile_env(:elxrBB, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ElxrBBWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
```

### 9. Run Database Migrations

```bash
# Run the migrations created by Pow
mix ecto.migrate
```

### 10. Update the Endpoint

Ensure your endpoint includes the Pow session plug:

```elixir
# lib/elxrBB_web/endpoint.ex
defmodule ElxrBBWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :elxrBB

  # ... existing configuration ...

  plug Plug.Session, @session_options
  plug Pow.Plug.Session, otp_app: :elxrBB
  plug ElxrBBWeb.Router
end
```

## Testing Authentication

### 1. Start the Server

```bash
mix phx.server
```

### 2. Test User Registration

Visit [http://localhost:4000/registration/new](http://localhost:4000/registration/new) to test user registration.

### 3. Test User Login

Visit [http://localhost:4000/session/new](http://localhost:4000/session/new) to test user login.

### 4. Check Email Logs

In development, authentication emails are logged to the console. Look for log messages like:

```
[debug] E-mail sent: %{to: "user@example.com", subject: "Confirm your email", ...}
```

## Customizing Authentication Templates

### Generate Custom Templates

```bash
mix pow.phoenix.gen.templates
```

This creates customizable templates in `lib/elxrBB_web/controllers/pow/`.

### Customize Registration Form

You can customize the registration form to include additional fields:

```html
<!-- lib/elxrBB_web/controllers/pow/registration_html/new.html.heex -->
<div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
  <div class="max-w-md w-full space-y-8">
    <div>
      <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
        Create your account
      </h2>
    </div>

    <.simple_form for={@changeset} action={~p"/registration"} method="post">
      <.input field={@changeset[:email]} type="email" label="Email" required />
      <.input field={@changeset[:password]} type="password" label="Password" required />
      <.input field={@changeset[:password_confirmation]} type="password" label="Confirm Password" required />
      <.input field={@changeset[:username]} type="text" label="Username" required />
      <.input field={@changeset[:bio]} type="textarea" label="Bio (optional)" />

      <:actions>
        <.button class="w-full">Register</.button>
      </:actions>
    </.simple_form>

    <div class="text-center">
      <.link href={~p"/session/new"} class="text-indigo-600 hover:text-indigo-500">
        Already have an account? Sign in
      </.link>
    </div>
  </div>
</div>
```

## Adding Authentication to Your Application

### Protect Routes

To protect routes that require authentication, add a plug:

```elixir
# lib/elxrBB_web/router.ex
pipeline :protected do
  plug Pow.Plug.RequireAuthenticated,
    error_handler: Pow.Phoenix.PlugErrorHandler
end

scope "/", ElxrBBWeb do
  pipe_through [:browser, :protected]

  # Protected routes go here
  get "/dashboard", DashboardController, :index
end
```

### Access Current User

In your controllers and LiveViews, you can access the current user:

```elixir
# In a controller
def index(conn, _params) do
  user = Pow.Plug.current_user(conn)
  # ... rest of controller logic
end

# In a LiveView
def mount(_params, _session, socket) do
  user = Pow.Plug.current_user(socket.assigns[:__changed__][:conn])
  # ... rest of mount logic
end
```

## Next Steps

In the next lesson, we'll implement the core forum functionality, including forums, topics, and replies. The authentication system we've built will be used to associate forum content with users.

## Troubleshooting

### Common Issues

**"No route found" errors:**

- Ensure `pow_routes()` and `pow_extension_routes()` are in your router
- Check that the Pow session plug is in your endpoint

**Email confirmation not working:**

- Verify the mailer is properly configured
- Check that email confirmation is enabled in the Pow config

**Database errors:**

- Run `mix ecto.migrate` to ensure all migrations are applied
- Check that the User schema includes all required Pow fields

## Additional Resources

- [Pow Documentation](https://hexdocs.pm/pow/README.html)
- [Pow Phoenix Integration](https://hexdocs.pm/pow/Phoenix.html)
- [Pow Extensions](https://hexdocs.pm/pow/Pow.Extension.html)
