# Lesson 1: Setting Up the Environment and Creating the elxrBB Project

## Overview

In this lesson, we'll set up a modern Elixir and Phoenix development environment and create the elxrBB forum application. We'll use the latest stable versions and best practices.

## Prerequisites

- Basic familiarity with command line
- Git installed
- A text editor or IDE (VS Code recommended)

## Setting Up the Development Environment

### Install Elixir

Visit the official Elixir installation page: https://elixir-lang.org/install.html

**Recommended approach using asdf (version manager):**

```bash
# Install asdf (if not already installed)
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0

# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc

# Reload your shell
source ~/.bashrc

# Install Erlang and Elixir
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang latest
asdf install elixir latest
asdf global erlang latest
asdf global elixir latest
```

**Verify installation:**

```bash
elixir --version
# Should show Elixir 1.15+ and Erlang/OTP 26+
```

### Install Phoenix

```bash
# Install Hex package manager
mix local.hex

# Install Phoenix project generator
mix archive.install hex phx_new
```

### Install PostgreSQL

**Ubuntu/Debian:**

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

**macOS (with Homebrew):**

```bash
brew install postgresql
brew services start postgresql
```

**Windows:**
Download and install from: https://www.postgresql.org/download/windows/

### Install Node.js

**Using asdf (recommended):**

```bash
asdf plugin add nodejs
asdf install nodejs latest
asdf global nodejs latest
```

**Or download from:** https://nodejs.org/

## Creating the elxrBB Project

### Generate a New Phoenix Project

```bash
# Create the project with LiveView and PostgreSQL
mix phx.new elxrBB --live --database postgres

# Navigate to the project directory
cd elxrBB
```

### Configure the Database

The project generator creates a `config/dev.exs` file with default PostgreSQL settings. Update it if needed:

```elixir
# config/dev.exs
config :elxrBB, ElxrBB.Repo,
  username: "postgres",
  password: "postgres",
  database: "elxrbb_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

### Create the Database

```bash
# Create the development database
mix ecto.create

# Run any existing migrations
mix ecto.migrate
```

### Install Dependencies and Build Assets

```bash
# Install Elixir dependencies
mix deps.get

# Install and build frontend assets
mix assets.setup
mix assets.build
```

### Start the Development Server

```bash
# Start the Phoenix server
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000) in your browser. You should see the default Phoenix welcome page.

## Project Structure Overview

Your new Phoenix project has the following structure:

```
elxrBB/
├── assets/                 # Frontend assets (CSS, JS)
├── config/                 # Configuration files
├── lib/
│   ├── elxrBB/            # Business logic (contexts)
│   ├── elxrBB_web/        # Web interface (controllers, views, templates)
│   └── elxrBB.ex          # Main application module
├── priv/
│   ├── repo/              # Database migrations and seeds
│   └── static/            # Static assets
├── test/                  # Test files
├── mix.exs                # Project dependencies
└── README.md
```

## Key Phoenix Concepts

- **Contexts**: Business logic modules (e.g., `ElxrBB.Users`, `ElxrBB.Forums`)
- **Controllers**: Handle HTTP requests
- **Views**: Render responses (HTML, JSON)
- **Templates**: HTML templates (using HEEx)
- **LiveView**: Real-time, interactive web interfaces
- **Ecto**: Database wrapper and query builder

## Troubleshooting

### Common Issues

**Database connection errors:**

- Ensure PostgreSQL is running
- Check username/password in `config/dev.exs`
- Verify database exists: `mix ecto.create`

**Asset build errors:**

- Ensure Node.js is installed
- Run `mix assets.setup` to install frontend dependencies

**Port already in use:**

- Change the port in `config/dev.exs` or kill the process using port 4000

## Next Steps

In the next lesson, we'll implement user authentication using the Pow library, which provides a robust, production-ready authentication system.

## Additional Resources

- [Phoenix Documentation](https://hexdocs.pm/phoenix/overview.html)
- [Elixir Documentation](https://hexdocs.pm/elixir/Kernel.html)
- [Ecto Documentation](https://hexdocs.pm/ecto/Ecto.html)
- [LiveView Documentation](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
