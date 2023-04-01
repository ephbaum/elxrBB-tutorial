# Lesson 1: Setting Up the Environment and Creating the elxrBB Project

## Setting Up the Development Environment

Before we can start building elxrBB, we need to set up the development environment. In this section, we will guide you through the process of installing the necessary tools and technologies for building the application.

### Install Elixir

Visit the official Elixir installation page [https://elixir-lang.org/install.html](https://elixir-lang.org/install.html) and follow the instructions for your operating system.

### Install Phoenix

Once Elixir is installed, you can install Phoenix using the following command:

```
mix archive.install hex phx_new
```

This command installs the latest Phoenix project generator.

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
