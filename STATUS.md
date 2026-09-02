# Tutorial Status

Tracks each lesson and whether the reference application actually implements it.

Application repository: <https://github.com/ephbaum/elxrBB>

## Lessons

Numbering follows the revised [outline](docs/00a-outline.md).

| # | Title | Lesson | Implemented |
|---|---|---|---|
| 1 | Setting Up the Environment | ✅ Written | ✅ Yes |
| 2 | User Accounts | ✅ Written | ✅ Yes |
| 3 | Forums, Topics and Replies | ✅ Written | ✅ Yes |
| 4 | Threaded Replies, Sub-Topics and Voting | 🚧 Next | 🚧 Next |
| 5 | Real-Time Updates with PubSub | 📋 Outlined | ❌ No |
| 6 | Pagination and Search | 📋 Outlined | ❌ No |
| 7 | Profiles, Avatars and Private Messaging | 📋 Outlined | ⚠️ Profiles shipped in lesson 2 |
| 8 | Rich Text and Safe Rendering | 📋 Outlined | ❌ No |
| 9 | Roles, Permissions and Moderation | 📋 Outlined | ❌ No |
| 10 | Audit Trails and the Admin Dashboard | 📋 Outlined | ❌ No |
| 11 | Notifications | 📋 Outlined | ❌ No |
| 12 | Accessible Design | 📋 Outlined | ❌ No |
| 13 | Testing in Depth | 📋 Outlined | ⚠️ App is tested; lesson not written |
| 14 | Deploying elxrBB | 📋 Outlined | ❌ No |
| 15 | Customizing and Extending | 📋 Outlined | ❌ No |
| A–D | Appendices | 📋 Outlined | ❌ No |

Legend: ✅ done · 🚧 in progress · ⚠️ partial · 📋 planned · ❌ not started

## What the application does today

- Accounts: registration, magic-link login, email confirmation, password and
  email changes, sudo mode for sensitive edits.
- Profiles: an auto-assigned `GerundAnimal` username (544,116 possible names)
  plus a bio, both editable from the settings page.
- Forums: create, edit, delete. Public listing with topic counts.
- Topics: created inside a forum by a signed-in user. Forum pages list them
  with reply counts, ordered by most recent activity.
- Replies: posted from the topic page and appended live. Authors can edit and
  delete their own posts.

186 tests pass on `mix precommit`.

## Known gaps in the application

These are true of the code today and are scheduled, not forgotten:

- **No pagination.** `list_topics/1` and `list_replies/1` return everything.
  Lesson 6.
- **No real-time.** A posted reply appears for its author only; other readers
  must reload. Lesson 5.
- **No search.** Lesson 6.
- **Post bodies render as plain text.** No Markdown, and therefore no
  sanitization question to answer yet. Lesson 8.
- **Anyone signed in can create, edit or delete a forum.** Only topics and
  replies are author-restricted. Roles land in lesson 9.
- **No rate limiting.** Not on the outline; worth adding before this is ever
  exposed to the public internet.

## Deviations from the original plan

The outline itself was revised once lessons 1–3 existed; see
[Revisions to this plan](docs/00a-outline.md#revisions-to-this-plan) for the
full account. In short: lessons 4 and 5 were one lesson, real-time moved much
earlier and switched from Channels to PubSub, pagination and search were
missing entirely, testing moved earlier, the animal-names lesson was dropped
as superseded by lesson 2, and the vendor-dependent material (payments, SMS,
browser push) became optional appendices.

## How a lesson gets marked done

1. The lesson is written against code that exists.
2. The code is in the application repository and `mix precommit` passes.
3. Every command and snippet in the lesson was run, not assumed.
4. This file is updated.

## Archive

- Original lessons (2023, ChatGPT-assisted): `docs/archive/original-lessons/`
- Original application: the `archive/initial-attempt` branch of the app repo
