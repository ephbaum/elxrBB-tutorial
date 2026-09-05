# elxrBB-tutorial

Build a forum web application with Elixir and Phoenix, one lesson at a time.

## Start here

| | |
|---|---|
| [Outline](docs/00a-outline.md) | The whole series at a glance |
| [Introduction](docs/00b-introduction.md) | What elxrBB is and what it will do |
| [Lesson 1](docs/01-setting-up.md) | Environment setup and generating the project |
| [Lesson 2](docs/02-user-authentication.md) | Accounts, magic-link login, usernames and bios |
| [Lesson 3](docs/03-forum-functionality.md) | Forums, topics and replies |
| [Lesson 4](docs/04-threading-and-voting.md) | Threaded replies, sub-topics and voting |
| [Status](STATUS.md) | Which lessons are written, and which are implemented |

The reference application lives at
[ephbaum/elxrBB](https://github.com/ephbaum/elxrBB). Lessons 1–4 are written
against code that is actually in that repository and passes its test suite;
everything from lesson 5 on is still an outline.

Written against Phoenix 1.8 on Elixir 1.20 / OTP 28, using `mix phx.gen.auth`,
LiveView, Tailwind 4 and daisyUI.

## Checking the lessons

The lessons quote the application's source, and quoted code goes stale. Blocks
that name their source file in the fence are checked against it:

    elixir bin/check_lessons.exs --app ../elxrBB

Each lesson is checked against the commit that concludes it, named in
`lessons.exs` -- lesson 3 shows replies as a flat stream and lesson 4 replaces
that with a tree, so checking either against the application's HEAD would
report drift that is really the tutorial doing its job.

Whitespace and whole-line comments are ignored, so a lesson may re-indent or
reflow an excerpt and leave out a comment it explains in prose. A line of bare
`...`, or a comment mentioning `...`, stands in for code the lesson is not
showing. Pass `--strict` to also fail on source blocks that name no file; not
every block names one yet, so the unannotated count is a backlog, not a bug.

## Where this came from

A (an ambitious) collaborative effort with ChatGPT (GPT-4) to create a tutorial for, and open source, a forum web application

### What?

This repo is the result of a recent conversation with [ChatGPT](https://help.openai.com/en/collections/3742473-chatgpt) ([GPT4](https://openai.com/research/gpt-4)). The clever little chatbot suggested in true ChatGPT Dunning-Kruger style, and I figured 🤷‍♂️, okay, maybe we can build a real tutorial from this conversation

Essentially, I asked ChatGPT about how to build a forum web app using Elixir and Phoenix

### Why?

The conversation around ChatGPT right now is wild. There's a lot of [doomers](https://www.reuters.com/technology/musk-experts-urge-pause-training-ai-systems-that-can-outperform-gpt-4-2023-03-29/) out there, [some moreso](https://time.com/6266923/ai-eliezer-yudkowsky-open-letter-not-enough/) than [others](https://astralcodexten.substack.com/p/why-i-am-not-as-much-of-a-doomer).

A [recent toot](https://hachyderm.io/@aburka/110098164435536382) on hachyderm.io seems to suggest another point of view:

> Updating a classic:
> Some people, when presented with a problem, think "I'll use ChatGPT to solve this problem!"
> Now they have two problems. 

- [@durka](https://github.com/durka)

This intance I'm working with keeps forgetting things, and I've spotted plenty of issues with its code as we've gone along so far, but this feels like a good opportunity to try to learn how to work with a LLM to accomplish larger projects

I harbor no illusions that this will be successful. I'm sure some, if not most, of its code is crap, maybe even already outdated

There is something amazing about working with an always-there (except when you hit the 25 message cap) knowledge partner that is omniscient (presenting). 

ChatGPT is a hell of a "yes-man" and has a pretty wide array of knowledge to draw from-

### How?

I am just working with ChatGPT to build both this tutorial and the application

I intend to opensource the final product (should one be built, I definitely harbor no illusions about my ability to focus on this, nor my skill level with Elixir, that it will actually get done)

I do hope some folks might [contribute]() in the future, maybe even some folks with actual Elixir experience will be willing to vet the project

Or maybe it will be another repo gathering dust :shrug:

### Important Note

I make no warranty. This is a work in progress and I have no idea what I'm doing (probably). ChatGPT and I seem to be having a pretty productive conversation, but this may all be made up bullshit. Do not rely on it until this document suggests otherwise. 