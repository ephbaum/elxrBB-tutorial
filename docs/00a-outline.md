# elxrBB Tutorial Series Outline

Sixteen planned lessons became fifteen plus four optional appendices. See
[Revisions to this plan](#revisions-to-this-plan) at the bottom for what
changed and why.

Status of each lesson is tracked in [STATUS.md](../STATUS.md).

## Introduction

- [Overview of elxrBB](00b-introduction.md)
- Introducing Elixir and Phoenix
- System requirements and setup

## [Lesson 1: Setting Up the Environment](01-setting-up.md) ✅

- Installing Elixir, Erlang/OTP and PostgreSQL
- Installing the Phoenix project generator
- Generating the elxrBB project and reading what it produced

## [Lesson 2: User Accounts](02-user-authentication.md) ✅

- Generating authentication with `mix phx.gen.auth`
- Scopes, magic-link login and email confirmation
- Assigning each new account a random username
- User profiles: usernames and biographies

## [Lesson 3: Forums, Topics and Replies](03-forum-functionality.md) ✅

- The Forums context: forums, topics, replies
- Schemas, associations and cascading deletes
- Public reads, authenticated writes, author-only edits
- LiveViews for browsing, posting and replying
- Counting replies without an N+1 or a counter column

## [Lesson 4: Threaded Replies, Sub-Topics and Voting](04-threading-and-voting.md) ✅

- Self-referencing replies: `parent_id` and a nested tree
- Rendering a thread recursively without an N+1
- Sub-topic counts on every reply
- Upvotes and downvotes on topics and replies
- One vote per user per post, changeable and revocable
- Sorting a thread by score

## Lesson 5: Real-Time Updates with PubSub

- Why a LiveView app broadcasts through `Phoenix.PubSub`, not Channels
- Subscribing a LiveView to a topic and handling `handle_info/2`
- Broadcasting from the context, so every writer publishes
- Reconciling a broadcast with a LiveView stream
- Presence: who else is reading this thread
- Where Channels *are* the right tool (non-LiveView clients, mobile, an API)

## Lesson 6: Pagination and Search

- Why every unbounded list query is a latent outage
- Keyset pagination, and why `OFFSET` degrades
- Paginating topics and replies in LiveView
- PostgreSQL full-text search: `tsvector`, a generated column, a GIN index
- A search LiveView with debounced input

## Lesson 7: User Profiles, Avatars and Private Messaging

- Public profile pages at `/users/:username`
- Avatar uploads with `allow_upload/3` and `consume_uploaded_entries/3`
- Validating uploads: content type, size, and why you re-encode images
- Storing files: local disk in development, S3-compatible object storage in
  production, behind one behaviour so the app does not care which
- Private messages: conversations, participants, read state
- Unread counts without a query per conversation

## Lesson 8: Rich Text and Safe Rendering

- Markdown as the single formatting system
- Rendering Markdown server-side and sanitizing the result
- **Why unsanitized user HTML is how forums get owned** — XSS, and what
  `raw/1` really does
- Image and file attachments in posts
- A live preview pane using a LiveView JS hook

## Lesson 9: Roles, Permissions and Moderation

- Generalizing `topic_owner?/2` into an authorization module
- Roles: member, moderator, administrator
- Permission checks in one place, used by both templates and handlers
- Moderator actions: lock, pin, move, edit, remove
- Reporting and a moderation queue

## Lesson 10: Audit Trails and the Admin Dashboard

- Recording who did what, when, and to which record
- Soft deletes: keeping the row, hiding the content
- Edit history on posts
- An admin dashboard LiveView
- Phoenix LiveDashboard behind an authorization check

## Lesson 11: Notifications

- Email notifications with Swoosh, and previewing them in development
- In-app notifications: a table, a bell, an unread count over PubSub
- Digests and per-user notification preferences
- Sending email reliably in production (a real adapter, retries, bounces)

## Lesson 12: Accessible Design (a11y)

- Auditing what we have built with a screen reader and a keyboard
- Semantics, landmarks, focus management in LiveView navigation
- Live regions for content that arrives over the socket
- Colour contrast in both daisyUI themes
- Automated checks in CI, and what they cannot catch

## Lesson 13: Testing in Depth

- What we have already been doing, named: `DataCase`, `ConnCase`, fixtures
- `Phoenix.LiveViewTest`: `render_click/3`, `render_submit/2`, `follow_redirect/3`
- Testing authorization by pushing events a hostile client would push
- Testing PubSub broadcasts and multi-session behaviour
- Property-based testing with StreamData
- Running the suite in CI

## Lesson 14: Deploying elxrBB

- `config/runtime.exs` and the environment variables that matter
- Releases: `mix release`, and the generated Dockerfile
- Running migrations on deploy
- Deploying to a platform (Fly.io, Render) or a plain VM
- TLS, `force_ssl`, secret management, and a security checklist
- Backups, and restoring one before you need to

## Lesson 15: Customizing and Extending elxrBB

- The extension points the design left open
- Adding a feature end to end, as a worked example
- Contributing back to the project

## Conclusion

- What you have built
- Where to go next

## Appendices (optional)

### Appendix A: An Event-Driven Architecture

- What events buy you, and what they cost
- Refactoring one slice of elxrBB to publish domain events

### Appendix B: Object-Oriented vs. Functional Programming

- The two paradigms side by side
- Why contexts are not services and structs are not objects

### Appendix C: Subscriptions and Payment Processing

- A "pro" tier gated on subscription state
- Integrating a payment provider, webhooks, and the states you must handle
- **Requires a third-party account and cannot be followed offline**

### Appendix D: Browser Push and SMS Notifications

- Web Push: service workers, VAPID keys, and permission UX
- SMS and voice via a telephony provider
- **Requires third-party accounts and cannot be followed offline**

---

## Revisions to this plan

The original sixteen-lesson outline was drafted before any code existed. Now
that lessons 1–3 are implemented, several parts of it do not survive contact
with the application.

**Lessons 4 and 5 were the same lesson.** "Threaded replies" and "sub-topics"
describe one feature: a reply with a `parent_id`. They are merged into
lesson 4.

**Real-time moved from lesson 11 to lesson 5, and changed technology.** The
original plan reached for Phoenix Channels. elxrBB is a LiveView application,
and a LiveView broadcasts over `Phoenix.PubSub` and receives in
`handle_info/2` — Channels are for clients that are *not* LiveViews. It also
belongs early: after lesson 4 the reply you post appears instantly for you and
not at all for anyone else, which is the wrong thing to leave standing for six
lessons.

**Pagination and search were missing entirely.** Every list query in the
application today is unbounded. That is fine with five topics and an outage
with fifty thousand, and it is the single largest gap between "the tutorial
finishes" and "the application works". It is now lesson 6.

**Testing moved from lesson 14 to lesson 13, and changed shape.** The
reference application has had tests since lesson 2, so a lesson that
introduces testing at the end would be describing a project that does not
exist. Lesson 13 now covers the parts we have *not* been using — LiveView
interaction tests, PubSub assertions, property-based testing, CI — and the
basics are taught where they are first used.

**The animal-names lesson is gone.** Old lesson 12 proposed importing the
animal list into a database table and exposing it to JavaScript. Lesson 2
already loads those lists at compile time, which is faster and simpler, and
the JavaScript half had no user-facing purpose. The genuinely useful JS-hook
material moves to lesson 8, where a Markdown preview pane gives it a reason to
exist.

**Payments and SMS became appendices.** A tutorial step that cannot be
completed without a vendor account, a credit card, and a public webhook
endpoint is not a step most readers can take. The roles and permissions half
of old lesson 7 is real work and stays, as lesson 9; the subscription and
billing half moves to appendix C. Browser push and Twilio move to appendix D
for the same reason.

**Profiles moved earlier and avatars later.** Usernames and biographies were
planned for lesson 6 but are part of registration, so they shipped in lesson 2.
What remains of old lesson 6 — avatar uploads and private messaging — is
lesson 7, with file storage behind a behaviour instead of naming one vendor's
block storage in the lesson title.

**Rich text narrowed to one format.** Supporting Markdown *and* BBCode *and* a
WYSIWYG editor triples the work and teaches nothing three times. Lesson 8 does
Markdown properly, including the sanitization step that is the actual reason
this lesson matters.

**Accessibility stayed at the back, with a caveat.** Lesson 12 is an audit and
a fix pass, which is a reasonable thing to do once there is something to
audit — but a11y is not a feature you bolt on at the end, so the earlier
lessons carry inline notes where a choice has accessibility consequences.
