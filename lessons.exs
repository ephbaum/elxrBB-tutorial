# Which state of the application each lesson describes.
#
# A lesson is a snapshot, not a view of HEAD: lesson 3 shows replies as a flat
# LiveView stream, and lesson 4 replaces that with a tree. Checking lesson 3
# against the current application would report drift that is really just the
# tutorial doing its job. So each lesson names the ref in the application repo
# whose tree it describes.
#
# These are the commits that conclude each lesson on the modernization branch.
# Once that work lands on main and those commits are tagged `lesson-1` and so
# on, replace the SHAs with the tag names -- tags survive further history and
# read better here. A ref this checkout does not have falls back to the working
# tree, and the checker says so rather than passing quietly.

%{
  "01-setting-up.md" => "97a4e68",
  "02-user-authentication.md" => "0d4ae69",
  "03-forum-functionality.md" => "3e900ff",
  "04-threading-and-voting.md" => "93f6cad"
}
