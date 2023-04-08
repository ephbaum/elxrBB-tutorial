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

Below there may be dragons, but I diverged a little at this point, first I uninstalled/reinstalled Docker Desktop so that it would work properly again. That seemed to clear some kind of bottleneck so that I could again use `docker` on WSL2.

I began, then, chatting with ChatGPT about getting Docker working. It took a little bit of back and forth and a couple of false starts, but we started making progress

First we created a new Phoenix project (having read the book, Phoenix Project always makes me chuckle):

```sh
mix phx.new elxrBB --database postgres
```

In hindsight I see that the instructions below suggested the --live flag, so I may reinstall this one more time to make it work -- remembering again to `git branch -m master main` after my first commit -- in collaboration with ChatGPT, I tried to work through the needed files to make Docker work. I may regret this later.

Anyway, then I got into my project:

```sh
cd elxrBB
```

Then I generated a secret, because this seems to be the way to populate a value for an ENV variable that's in my `docker-compose.yml` later:

```sh
mix phx.gen.secret 
```

Then created a Dockerfile:

```Dockerfile
# Use the official Elixir image as the base
FROM elixir:1.14-alpine

# Install required build dependencies
RUN apk add --update \
  build-base \
  git \
  nodejs \
  npm \
  postgresql-dev \
  yarn

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set the working directory
WORKDIR /app

# Copy required files
COPY mix.exs mix.lock ./

# Fetch dependencies
RUN mix do deps.get, deps.compile

# Copy the rest of the application
COPY . .

# Compile the application
RUN mix do compile

# Install Node.js dependencies
# RUN npm install --prefix assets

# Build the assets
# RUN npm run deploy --prefix assets
RUN mix phx.digest

# Expose the application port
EXPOSE 4000

# Set the default command to run the Phoenix server
CMD ["mix", "phx.server"]
```

Then created a docker-compose.yml.example file:

```docker-compose.yml
version: "3.8"

services:
  app:
    build: .
    ports:
      - "4000:4000"
    depends_on:
      - db
    environment:
      - MIX_ENV=prod
      - SECRET_KEY_BASE=your-secret-key-base
      - DATABASE_URL=ecto://postgres:postgres_password@db:5432/elxrbb_prod
      - PORT=4000
      - HOST=localhost

  db:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres_password
      - POSTGRES_DB=elxrbb_prod
```

Then I added `docker-compose.yml` to `.gitignore` and copied my new example file over:

```sh
cp docker-compose.yml.example docker-compose.yml
```

(I pivoted after an error related to NPM)

And in that file I updated the `SECRET_KEY_BASE` value as well as the Postgres credentials to be a bit more secure. 

Following directions at [Pheonix Up and Running](https://hexdocs.pm/phoenix/up_and_running.html) I made sure to update `config\dev.exs` with the database password you defined in your `docker-compose.yml`.

For now, I just eant to be able to verify that this project is working locally without installing PostgresDB in WSL2

```sh
docker-compose up db -d
```

Then, with Postgresql running I used my host machines install of mix again:

```sh
mix ecto.create
```

Which seemed to go pretty well: 

```
Compiling 15 files (.ex)
Generated elxrBB app
The database for ElxrBB.Repo has been created
```

```sh
mix phx.server
```

Which exposed this error:

```
[error] `inotify-tools` is needed to run `file_system` for your system, check https://github.com/rvoicilas/inotify-tools/wiki for more information about how to install it. If it's already installed but not be found, appoint executable file with `config.exs` or `FILESYSTEM_FSINOTIFY_EXECUTABLE_FILE` env.
```

Which seems like a bit of a bummer, but I'll see about installing `inotify-tools` next, I suppose, but it otherwise appears to have worked, this is good news, I suppose, given that I'm just muddling along trying to listen to ChatGPT and follow instructions. 

The rest of the output says I'm at least broadly up and running

```
[warning] Could not start Phoenix live-reload because we cannot listen to the file system.
You don't need to worry! This is an optional feature used during development to
refresh your browser when you save files and it does not affect production.

[info] Running ElxrBBWeb.Endpoint with cowboy 2.9.0 at 127.0.0.1:4000 (http)
[info] Access ElxrBBWeb.Endpoint at http://localhost:4000
[watch] build finished, watching for changes...

Rebuilding...

Done in 328ms.
[info] GET /
[debug] Processing with ElxrBBWeb.PageController.home/2
  Parameters: %{}
  Pipelines: [:browser]
[info] Sent 200 in 74ms
[info] GET /
[debug] Processing with ElxrBBWeb.PageController.home/2
  Parameters: %{}
  Pipelines: [:browser]
[info] Sent 200 in 3ms
```

That second request was served up mighty quick.

Of course I can't help but wonder why I got an NPM error in the first place :thinking:

So, I've removed the NPM lines for now.

Now when I run `docker-compose up -d` everything builds and I get a working server at https://localhost:4000 :tada:

That wasn't too painful, I suppose

I have two containers and I didn't have to do _too_ much to get things work besides a little RTFM, which, I suppose I was trying to bypass a little bit by using ChatGPT in the first place... :thinking:

Still, it's 

                  ,--,                                  
               ,---.'|                                  
   ,---,       |   | :      ,---,                ,---,. 
  '  .' \      :   : |   ,`--.' |       ,---.  ,'  .' | 
 /  ;    '.    |   ' :   |   :  :      /__./|,---.'   | 
:  :       \   ;   ; '   :   |  ' ,---.;  ; ||   |   .' 
:  |   /\   \  '   | |__ |   :  |/___/ \  | |:   :  |-, 
|  :  ' ;.   : |   | :.'|'   '  ;\   ;  \ ' |:   |  ;/| 
|  |  ;/  \   \'   :    ;|   |  | \   \  \: ||   :   .' 
'  :  | \  \ ,'|   |  ./ '   :  ;  ;   \  ' .|   |  |-, 
|  |  '  '--'  ;   : ;   |   |  '   \   \   ''   :  ;/| 
|  :  :        |   ,/    '   :  |    \   `  ;|   |    \ 
|  | ,'        '---'     ;   |.'      :   \ ||   :   .' 
`--''                    '---'         '---" |   | ,'   
                                             `----'     

I, however, am exhausted as it's been a hell of a week and my tank is empty. But I'm excited to see if any of this works. 

I am pleased to see this working as I would expect, at least, and without too much tinkering over the course of about an hour of tinkering.

I do regret trusting ChatGPT to generate good boilerplate without scrutinizing it a bit better, this should be easy to integrate into any instructions.  

I also wonder if the ascii art above will look right on GitHub :thinking: 


Next up I'll update the below... soon-ish - but I'm about ready to start vetting the next section where I'll actually be building _something_. 

@TODOs

- [ ] - what's the deal with the config files not being .gitignore but containing secrets?
- [ ] - what's the deal with salt in the `lib/elxrBB_web/endpoint.ex`?

🛌

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
