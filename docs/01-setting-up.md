# Lesson 1: Setting Up the Environment and Creating the elxrBB Project

## Setting Up the Development Environment

Before we can start building elxrBB, we need to set up the development environment. In this section, we will guide you through the process of installing the necessary tools and technologies for building the application.

### Install Elixir

Visit the official Elixir installation page [https://elixir-lang.org/install.html](https://elixir-lang.org/install.html) and follow the instructions for your operating system, or even [Docker](https://elixir-lang.org/install.html#docker)

### Install Phoenix

Once Elixir is installed, as of this writing, the required versions for Erlang is 24 and Elixir is 1.19, according to the [Phoenix install instructions](https://hexdocs.pm/phoenix/installation.html) you may install using the following commands:

```sh
mix local.hex
```

```sh
mix archive.install hex phx_new
```

This command installs the latest Phoenix project generator.

#### A note about version issues

When I did this using WSL2 I encountered the following error (because I wasn't paying attention to version numbers): 

```
** (Mix) You're trying to run :phx_new on Elixir v1.9.1 but it has declared in its mix.exs file it supports only Elixir ~> 1.14
```

This indicated that I was running the wrong version of Elixir, which I surmised was due to running the wrong version of Erlang. To correct this I went to the Erlang download site and found the "Add from repository" section and followed their instructions:

```sh
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc
sudo apt-key add erlang_solutions.asc
sudo apt-get update
sudo apt-get install erlang
```

When I was done I was able to see the Erlang version just by calling the `erl` command, which returned: 

```
Erlang/OTP 25 [erts-13.0.4] [source] [64-bit] [smp:16:16] [ds:16:16:10] [async-threads:1] [jit:ns]
```

However, I still was not able to proceed with the Phoenix install as my version of Elixir was now only 1.13.2

```sh
elixir -v                                                                           1 ↵
```

```
Erlang/OTP 25 [erts-13.2] [source] [64-bit] [smp:16:16] [ds:16:16:10] [async-threads:1] [jit:ns]

Elixir 1.13.4 (compiled with Erlang/OTP 25)
```

So...

#### Another note about version issues

There are recommendations that I found to try using the [asdf package](https://github.com/asdf-vm/asdf-elixir), but its installation and use are outside the (present) scope of this guide, but the instructions are fairly clear and should be easy enough to follow. (glhf)

After completing this installation, it was finally smooth sailing 

```sh
% elixir -v
```

```
Erlang/OTP 25 [erts-13.2] [source] [64-bit] [smp:16:16] [ds:16:16:10] [async-threads:1] [jit:ns]

Elixir 1.14.3 (compiled with Erlang/OTP 25)
```

I was able to complete the instructions above by reinstalling `hex` and then installing `phx_new`

---
This guide is "valid" to this point - EB
---

### Install PostgreSQL

Visit the PostgreSQL download page [https://www.postgresql.org/download/](https://www.postgresql.org/download/) and follow the instructions for your operating system. After installation, ensure that the PostgreSQL service is running.

### Install Node.js

Visit the Node.js download page [https://nodejs.org/en/download/](https://nodejs.org/en/download/) and follow the instructions for your operating system. This is required for managing frontend dependencies and running the development server.

## Creating the elxrBB Project

Now that our development environment is set up, we can create a new Phoenix project for elxrBB.

### Generate a New Phoenix Project

Run the following command to generate a new Phoenix project called `elxrBB`:

```
mix phx.new elxrBB --live
```

This command generates a new project with the `--live` flag, which includes LiveView for building real-time features.

### Configure the Database

Navigate to the `elxrBB` project directory and open the `config/dev.exs` file. Update the PostgreSQL configuration to match your local database settings, including username, password, and database name:

```elixir
config :elxrBB, elxrBB.Repo,
  username: "your_db_username",
  password: "your_db_password",
  database: "elxrBB_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

### Create the Database

Run the following command to create the development database:

```
mix ecto.create
```

### Start the Development Server

Run the following command to start the Phoenix development server:

```
mix phx.server
```

Now, you can visit [http://localhost:4000](http://localhost:4000) in your web browser to see the default Phoenix project homepage.

In the next lesson, we will begin implementing the elxrBB application features, starting with user authentication and registration.
