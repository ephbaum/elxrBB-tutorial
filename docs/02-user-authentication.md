# Lesson 2: User Accounts

## Overview

We add accounts to elxrBB: registration, login, email confirmation, password
and email changes — and the animal-themed usernames the forum is known for.

## Authentication in Phoenix 1.8

Phoenix ships `mix phx.gen.auth`, which writes a complete email-based
authentication system into your application: registration, magic-link login,
email confirmation, password and email changes, and session management. It is
maintained alongside the framework, its output matches the layouts and
components the rest of the app uses, and — most usefully for a tutorial — the
code lands in your repository where you can read and change it.

That is what we use.

## Running the generator

```bash
mix phx.gen.auth Accounts User users --live
mix deps.get
mix ecto.migrate
```

`--live` gives you LiveView-based registration and login pages rather than
controller-rendered ones, which is what you want when the rest of the app is
LiveView.

That single command writes a lot of code. It is *your* code — read it, change
it. The pieces worth understanding before we build on top:

| File | What it does |
|---|---|
| `lib/elxrbb/accounts.ex` | The context. Registration, tokens, email and password changes. |
| `lib/elxrbb/accounts/user.ex` | The schema and its changesets — one changeset per operation, not one for everything. |
| `lib/elxrbb/accounts/user_token.ex` | Session, magic-link, confirmation and email-change tokens. |
| `lib/elxrbb/accounts/scope.ex` | `%Scope{user: user}` — what the web layer is allowed to see. |
| `lib/elxrbb_web/user_auth.ex` | Plugs and `on_mount` hooks: `fetch_current_scope_for_user`, `require_authenticated`, `mount_current_scope`. |
| `lib/elxrbb_web/live/user_live/*` | Registration, login, confirmation and settings LiveViews. |

Run `mix test`. The generator writes its own tests, and they should all pass
before you change anything.

### Three concepts worth pausing on

**Scopes.** The generator does not put a bare `current_user` in your assigns.
It puts a `%Scope{}` there. Everything downstream — templates, LiveViews,
context functions — takes the scope, so when elxrBB later grows organizations
or roles, there is one place to widen. `@current_scope` is `nil` for a
visitor who is not signed in, which is exactly the check your templates want.

**Magic links.** Registration asks only for an email address. The user gets a
link, clicks it, and is signed in and confirmed. A password is optional and set
later from the settings page. Fewer fields, no password reset flow to build.

**Sudo mode.** Changing your email or password requires having authenticated
recently (20 minutes by default). `on_mount {ElxrBBWeb.UserAuth,
:require_sudo_mode}` on the settings LiveView enforces it.

### Reading the emails in development

Confirmation and magic-link emails are captured, not sent. Visit
<http://localhost:4000/dev/mailbox>.

## Adding elxrBB's own fields

The generated user has an email and a password. A forum needs a display name
and a bio.

### The migration

```elixir
# priv/repo/migrations/..._add_profile_fields_to_users.exs
defmodule ElxrBB.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :username, :string, size: 30
      add :bio, :text
    end

    execute "UPDATE users SET username = 'user' || id WHERE username IS NULL"

    alter table(:users) do
      modify :username, :string, size: 30, null: false
    end

    create unique_index(:users, ["lower(username)"], name: :users_lower_username_index)
  end

  def down do
    drop index(:users, ["lower(username)"], name: :users_lower_username_index)

    alter table(:users) do
      remove :username
      remove :bio
    end
  end
end
```

Three things to notice.

**Add nullable, backfill, then constrain.** You cannot add a `NOT NULL` column
to a table that already has rows. Even on a project with no users yet, writing
the migration this way is the habit you want.

**`up`/`down`, not `change`.** `change` cannot infer how to reverse an
`execute`, so the reversible pair is written out by hand.

**The unique index is on `lower(username)`, not on `username`.** We want
`Aardvark` to display with its capital A but still collide with `aardvark`.
A functional index does that without the `citext` extension.

### The schema

```elixir
# lib/elxrbb/accounts/user.ex
schema "users" do
  field :email, :string
  # ... generated fields ...
  field :username, :string
  field :bio, :string

  timestamps(type: :utc_datetime)
end

@username_format ~r/^[A-Za-z0-9_-]+$/
@username_max_length ElxrBB.Accounts.Username.max_length()

def profile_changeset(user, attrs, opts \\ []) do
  user
  |> cast(attrs, [:username, :bio])
  |> validate_username(opts)
  |> validate_length(:bio, max: 500)
end

defp validate_username(changeset, opts) do
  changeset =
    changeset
    |> update_change(:username, &trim/1)
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: @username_max_length)
    |> validate_format(:username, @username_format,
      message: "may only contain letters, numbers, underscores and hyphens"
    )
    |> unique_constraint(:username, name: :users_lower_username_index)

  if Keyword.get(opts, :validate_unique, true) do
    validate_username_available(changeset)
  else
    changeset
  end
end

defp trim(nil), do: nil
defp trim(value) when is_binary(value), do: String.trim(value)
```

`trim/1` has to accept `nil`. `update_change/3` runs whenever the field is
cast — including when it is cast to `nil` — and `String.trim(nil)` raises a
`FunctionClauseError` that surfaces as a 500 instead of a validation error.
This is the kind of bug a test catches and a manual click-through does not.

The `:validate_unique` option follows the pattern the generator already uses
for email: live validation on every keystroke should not hit the database, but
the final save should. The database index is the actual authority; the query
just produces a nicer error.

### The Users context additions

```elixir
# lib/elxrbb/accounts.ex
def register_user(attrs) do
  %User{}
  |> User.email_changeset(attrs)
  |> User.profile_changeset(Map.put_new(normalize(attrs), "username", generate_username()))
  |> Repo.insert()
end

def generate_username(attempts \\ 5)

def generate_username(0),
  do: Username.generate() <> Integer.to_string(System.unique_integer([:positive]))

def generate_username(attempts) do
  candidate = Username.generate()

  if username_taken?(candidate) do
    generate_username(attempts - 1)
  else
    candidate
  end
end

def username_taken?(username) do
  Repo.exists?(
    from(u in User, where: fragment("lower(?)", u.username) == ^String.downcase(username))
  )
end

def get_user_by_username(username) when is_binary(username) do
  Repo.one(
    from(u in User, where: fragment("lower(?)", u.username) == ^String.downcase(username))
  )
end

def update_user_profile(%User{} = user, attrs) do
  user
  |> User.profile_changeset(attrs)
  |> Repo.update()
end

def change_user_profile(%User{} = user, attrs \\ %{}, opts \\ []) do
  User.profile_changeset(user, attrs, opts)
end
```

`Map.put_new` means a caller who supplies a username keeps it; everyone else
gets one assigned. Registration stays a single-field form.

## The username generator

elxrBB names new accounts after a gerund verb and an animal:
`ChortlingAardvark`, `WanderingZebu`, `PiningElephantShrew`. The word lists
live in this repository under `data/`; copy them into the application:

```bash
mkdir -p priv/data
cp ../elxrBB-tutorial/data/Animals.txt priv/data/animals.txt
cp ../elxrBB-tutorial/data/GerundVerbs.txt priv/data/gerund_verbs.txt
```

```elixir
# lib/elxrbb/accounts/username.ex
defmodule ElxrBB.Accounts.Username do
  @max_length 30

  @priv_data Path.expand("../../../priv/data", __DIR__)
  @animals_path Path.join(@priv_data, "animals.txt")
  @verbs_path Path.join(@priv_data, "gerund_verbs.txt")

  @external_resource @animals_path
  @external_resource @verbs_path

  load_words = fn path ->
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&String.replace(&1, ~r/[^A-Za-z]/, ""))
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn <<first::utf8, rest::binary>> -> String.upcase(<<first::utf8>>) <> rest end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @animals load_words.(@animals_path)
  @verbs load_words.(@verbs_path)

  @verbs_by_length @verbs |> Enum.sort_by(&byte_size/1) |> List.to_tuple()
  @shortest_verb @verbs |> Enum.map(&byte_size/1) |> Enum.min()

  @verbs_within Map.new(0..@max_length, fn budget ->
                  {budget, Enum.count(@verbs, &(byte_size(&1) <= budget))}
                end)

  @usable_animals @animals
                  |> Enum.filter(&(byte_size(&1) + @shortest_verb <= @max_length))
                  |> List.to_tuple()

  def generate do
    animal = elem(@usable_animals, :rand.uniform(tuple_size(@usable_animals)) - 1)
    fitting_verbs = Map.fetch!(@verbs_within, @max_length - byte_size(animal))
    verb = elem(@verbs_by_length, :rand.uniform(fitting_verbs) - 1)

    verb <> animal
  end

  def max_length, do: @max_length
end
```

Three techniques in that module are worth taking away.

**Compile-time loading.** The `load_words` anonymous function runs while the
module compiles; `@animals` and `@verbs` are baked into the BEAM file. A note
on why it is an anonymous function and not a `defp`: a module cannot call its
own functions in its own body, because it does not exist yet.
`@external_resource` tells `mix` to recompile when the text files change.

**Cleaning the input.** The animal list has entries like `Adelie Penguin` and
`American Staffordshire Terrier`. Stripping non-letters turns them into
`AdeliePenguin` — collapsed, not discarded.

**Respecting your own validation.** The naive version — pick any verb, pick any
animal — can produce `MisunderstandingAmericanStaffordshireTerrier`, which is
44 characters and fails the 30-character rule the schema enforces. Registration
then blows up on a name the app itself chose.

The fix keeps generation O(1). Verbs are sorted shortest-first in a tuple, so
"every verb that fits in N bytes" is a prefix of that tuple, and
`@verbs_within` says how long the prefix is. Pick an animal, look up the
budget, index into the tuple. 544,116 valid pairs, all of them legal.

This is the general lesson: **generated data has to satisfy the same
constraints as user input.** Test it the same way, too.

## Showing profiles in the UI

### The settings page

Add a profile form to `lib/elxrbb_web/live/user_live/settings.ex` above the
existing email form:

```heex
<.form for={@profile_form} id="profile_form" phx-submit="update_profile" phx-change="validate_profile">
  <.input field={@profile_form[:username]} type="text" label="Username" required />
  <.input field={@profile_form[:bio]} type="textarea" label="Bio" maxlength="500" />
  <.button variant="primary" phx-disable-with="Saving...">Save Profile</.button>
</.form>
```

```elixir
def handle_event("validate_profile", %{"user" => user_params}, socket) do
  profile_form =
    socket.assigns.current_scope.user
    |> Accounts.change_user_profile(user_params, validate_unique: false)
    |> Map.put(:action, :validate)
    |> to_form()

  {:noreply, assign(socket, profile_form: profile_form)}
end

def handle_event("update_profile", %{"user" => user_params}, socket) do
  user = socket.assigns.current_scope.user
  true = Accounts.sudo_mode?(user)

  case Accounts.update_user_profile(user, user_params) do
    {:ok, user} ->
      {:noreply,
       socket
       |> put_flash(:info, "Profile updated.")
       |> assign(:current_scope, ElxrBB.Accounts.Scope.for_user(user))
       |> assign(:profile_form, to_form(Accounts.change_user_profile(user, %{}, validate_unique: false)))}

    {:error, changeset} ->
      {:noreply, assign(socket, :profile_form, to_form(changeset, action: :insert))}
  end
end
```

Re-assigning `:current_scope` after a successful save matters: the nav bar
reads the username out of the scope, and without it the old name lingers until
the next full page load.

### The nav bar

In `lib/elxrbb_web/components/layouts/root.html.heex`, swap the email for the
username:

```heex
<li class="font-medium" title={@current_scope.user.email}>
  {@current_scope.user.username}
</li>
```

## Testing

The interesting tests are the ones about the generator and about case
sensitivity:

```elixir
test "pairs a gerund verb with an animal" do
  verbs = MapSet.new(Username.verbs())
  animals = MapSet.new(Username.animals())

  for _ <- 1..200 do
    name = Username.generate()

    assert name =~ ~r/^[A-Za-z]+$/
    assert String.length(name) <= Username.max_length()

    assert Enum.any?(verbs, fn verb ->
             String.starts_with?(name, verb) and
               MapSet.member?(animals, String.replace_prefix(name, verb, ""))
           end)
  end
end

test "rejects another user's username, ignoring case", %{user: user} do
  other = user_fixture()

  assert {:error, changeset} =
           Accounts.update_user_profile(user, %{username: String.downcase(other.username)})

  assert "has already been taken" in errors_on(changeset).username
end

test "keeping your own username is not a conflict", %{user: user} do
  assert {:ok, _user} = Accounts.update_user_profile(user, %{username: user.username})
end
```

That last one is the classic uniqueness bug: a naive "is this name taken?"
check says yes when you save your profile without changing your name. The
availability query excludes the current record's own id.

Run the suite:

```bash
mix precommit
```

## Try it

```bash
mix phx.server
```

1. Register at <http://localhost:4000/users/register>.
2. Open <http://localhost:4000/dev/mailbox> and click the login link.
3. Look at the nav bar — you have been named after an animal.
4. Change it at <http://localhost:4000/users/settings>.

## Next

[Lesson 3](03-forum-functionality.md) builds the forum itself: forums,
topics and replies, with the accounts from this lesson as their authors.
