# Original Tutorial Lessons Archive

This directory contains the original tutorial lessons created during the initial project attempt in 2023. These lessons represent the real journey of working with AI assistance (ChatGPT) to build a forum application.

## Contents

- `original-lessons/` - The original tutorial lessons (01-06)
- `README.md` - This file explaining the archive

## Historical Context

These lessons were created in collaboration with ChatGPT (GPT-4) and represent an interesting experiment in AI-assisted development. They include:

- Real debugging notes and challenges encountered
- Personal commentary about working with AI
- Version conflicts and troubleshooting attempts
- Incomplete implementations and lessons learned

## What You'll Find

### Original Lessons (01-06)
- **Lesson 1**: Setting up the environment (with extensive debugging notes)
- **Lesson 2**: User authentication with Pow (with configuration issues)
- **Lesson 3**: Forum functionality (incomplete implementation)
- **Lesson 4**: Threaded replies and voting (outdated syntax)
- **Lesson 5**: Sub-topics (redundant with lesson 4)
- **Lesson 6**: Private messaging and user profiles (incomplete)

### Key Issues in Original Lessons
- Outdated Phoenix syntax (EEx vs HEEx)
- Configuration mismatches between tutorial and implementation
- Missing core functionality
- Inconsistent approaches (manual vs generator)
- Too much debugging narrative mixed with instructions

## Why These Are Archived

The original lessons were archived because:
1. They don't match the actual application implementation
2. They use outdated Phoenix patterns
3. They contain too much debugging narrative
4. They're incomplete and confusing for learners

## Also archived here

- `02-user-authentication-pow.md` — the Pow-based version of lesson 2. It was
  written for the restart and is more coherent than the 2023 original, but Pow
  has not had a release since January 2025 and predates the Phoenix 1.8
  conventions. Lesson 2 now uses `mix phx.gen.auth`. Kept for comparison.

## Current Status

The current lessons live in `docs/`, and each one is written against code that
exists in the application repository:
- `01-setting-up.md` — Phoenix 1.8 on Elixir 1.20 / OTP 28
- `02-user-authentication.md` — `phx.gen.auth`, usernames and bios
- `03-forum-functionality.md` — forums, topics and replies

## Learning Value

Despite their issues, these original lessons provide valuable insights into:
- The challenges of AI-assisted development
- The importance of validating tutorial content
- The evolution of Phoenix patterns
- The need for clean, focused documentation

## Repository Links

- **Current Tutorial**: https://github.com/ephbaum/elxrBB-tutorial
- **Application Repository**: https://github.com/ephbaum/elxrBB
- **Original Application Work**: https://github.com/ephbaum/elxrBB/tree/archive/initial-attempt
