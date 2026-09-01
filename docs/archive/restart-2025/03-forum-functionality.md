# Lesson 3: Implementing Basic Forum Functionality

## Status: 🚧 INCOMPLETE - PLANNED

**Note**: This lesson is currently incomplete. The forum functionality described below needs to be implemented in the application.

## Overview

In this lesson, we'll implement the core forum functionality for elxrBB, including:

- Forum categories
- Discussion topics
- Topic replies
- User associations
- Basic CRUD operations

## Planned Implementation

### 1. Database Schema Design

We'll create three main entities:

```
Forums (Categories)
├── id
├── name (string)
├── description (text)
├── created_at
└── updated_at

Topics (Discussions)
├── id
├── title (string)
├── body (text)
├── forum_id (references forums)
├── user_id (references users)
├── created_at
└── updated_at

Replies (Comments)
├── id
├── body (text)
├── topic_id (references topics)
├── user_id (references users)
├── created_at
└── updated_at
```

### 2. Phoenix Generators

We'll use Phoenix generators to create the contexts and LiveViews:

```bash
# Create Forum context
mix phx.gen.live Forums Forum forums name:string description:text

# Create Topic context
mix phx.gen.live Forums Topic topics title:string body:text forum_id:references:forums user_id:references:users

# Create Reply context
mix phx.gen.live Forums Reply replies body:text topic_id:references:topics user_id:references:users
```

### 3. Database Migrations

After running the generators, we'll need to:

- Run `mix ecto.migrate` to create the database tables
- Add proper indexes for performance
- Set up foreign key constraints

### 4. Context Functions

The Forums context will include:

```elixir
# Forum functions
- list_forums/0
- get_forum!/1
- create_forum/1
- update_forum/2
- delete_forum/1

# Topic functions
- list_topics/0
- list_topics_by_forum/1
- get_topic!/1
- create_topic/2 (attrs, user)
- update_topic/2
- delete_topic/1

# Reply functions
- list_replies_by_topic/1
- get_reply!/1
- create_reply/2 (attrs, user)
- update_reply/2
- delete_reply/1
```

### 5. LiveView Implementation

We'll create LiveViews for:

- Forum listing page
- Topic listing page (by forum)
- Individual topic view with replies
- Topic creation form
- Reply creation form

### 6. Router Configuration

```elixir
scope "/", ElxrBBWeb do
  pipe_through :browser

  # Forum routes
  live "/forums", ForumLive.Index, :index
  live "/forums/new", ForumLive.Index, :new
  live "/forums/:id/edit", ForumLive.Index, :edit
  live "/forums/:id", ForumLive.Show, :show
  live "/forums/:id/show/edit", ForumLive.Show, :edit

  # Topic routes
  live "/topics", TopicLive.Index, :index
  live "/topics/new", TopicLive.Index, :new
  live "/topics/:id/edit", TopicLive.Index, :edit
  live "/topics/:id", TopicLive.Show, :show
  live "/topics/:id/show/edit", TopicLive.Show, :edit

  # Reply routes
  live "/replies", ReplyLive.Index, :index
  live "/replies/new", ReplyLive.Index, :new
  live "/replies/:id/edit", ReplyLive.Index, :edit
  live "/replies/:id", ReplyLive.Show, :show
  live "/replies/:id/show/edit", ReplyLive.Show, :edit
end
```

### 7. User Interface

The UI will include:

- Forum listing with topic counts
- Topic listing with reply counts
- Topic view with threaded replies
- Forms for creating topics and replies
- Navigation between forums and topics

### 8. User Associations

- Topics will be associated with users (authors)
- Replies will be associated with users (authors)
- Users will be able to edit/delete their own content
- User information will be displayed with posts

## Implementation Steps

1. **Generate the contexts and LiveViews**
2. **Run database migrations**
3. **Update the router with new routes**
4. **Customize the LiveView templates**
5. **Add user associations and permissions**
6. **Test the basic CRUD operations**
7. **Add navigation and UI improvements**

## Dependencies

This lesson builds on:

- Lesson 1: Phoenix setup and project structure
- Lesson 2: User authentication system

## Next Lessons

This lesson provides the foundation for:

- Lesson 4: Threaded replies and voting system
- Lesson 5: Advanced forum features
- Lesson 6: User profiles and private messaging

## Current Status

- [ ] Database schema design
- [ ] Phoenix generator commands
- [ ] Database migrations
- [ ] Context implementation
- [ ] LiveView implementation
- [ ] Router configuration
- [ ] User interface
- [ ] User associations
- [ ] Testing and validation

## Notes

- This lesson will use Phoenix LiveView for real-time updates
- We'll implement proper user permissions and associations
- The forum structure will be hierarchical: Forums → Topics → Replies
- All content will be associated with authenticated users
