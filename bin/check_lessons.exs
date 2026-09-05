#!/usr/bin/env elixir

# Verifies that annotated code blocks in the lessons still match the
# application they teach. A block is annotated by naming its source file in
# the fence:
#
#     ```elixir lib/elxrbb/forums.ex
#     def list_forums do
#     ...
#     end
#     ```
#
# Every non-elided run of lines must appear, in order, in the named file.
# Whitespace is ignored entirely in the comparison, and so are comments that
# occupy a whole line, so a lesson may re-indent an excerpt, reflow it to the
# page width, or leave out a comment it explains in prose instead. It may not
# change a name, a literal, or the structure.
#
# Elision markers split a block into chunks: a line of bare `...`, or a
# whole-line comment mentioning `...` (`# ... generated fields ...`). Each
# chunk must match whole, and the chunks must appear in the file in the order
# the lesson shows them.
#
# Each lesson is checked against the ref named for it in lessons.exs, not
# against the application's HEAD -- a lesson describes the application as it
# stood when that lesson ended, and later lessons are meant to change it.
#
#     elixir bin/check_lessons.exs [--app PATH] [--strict]
#
# --app     application checkout to verify against (default ../elxrBB, or
#           $ELXRBB_APP)
# --strict  also fail on source blocks that carry no annotation

defmodule CheckLessons do
  @source_langs ~w(elixir heex eex sql)

  def main(argv) do
    {opts, _rest} = OptionParser.parse!(argv, strict: [app: :string, strict: :boolean])

    app = Path.expand(opts[:app] || System.get_env("ELXRBB_APP") || "../elxrBB", root())
    strict? = Keyword.get(opts, :strict, false)

    File.dir?(app) || abort("application checkout not found at #{app} (pass --app PATH)")

    manifest = manifest()
    blocks = root() |> lesson_files() |> Enum.flat_map(&parse/1)
    {annotated, bare} = Enum.split_with(blocks, & &1.source)

    refs = resolve_refs(app, manifest, annotated)
    failures = annotated |> Enum.map(&verify(&1, app, refs)) |> Enum.reject(&is_nil/1)
    unannotated = Enum.filter(bare, &(&1.lang in @source_langs))

    Enum.each(failures, &report/1)
    if strict?, do: Enum.each(unannotated, &report_unannotated/1)

    summarize(annotated, unannotated, failures, refs)

    cond do
      failures != [] -> System.halt(1)
      strict? and unannotated != [] -> System.halt(1)
      true -> :ok
    end
  end

  defp root, do: __DIR__ |> Path.join("..") |> Path.expand()

  defp lesson_files(dir), do: dir |> Path.join("docs/*.md") |> Path.wildcard() |> Enum.sort()

  defp manifest do
    path = Path.join(root(), "lessons.exs")

    if File.regular?(path) do
      {map, _bindings} = Code.eval_file(path)
      map
    else
      %{}
    end
  end

  # Refs ---------------------------------------------------------------------

  # A lesson with no manifest entry, or one naming a ref the application
  # checkout does not have yet, falls back to the working tree.
  defp resolve_refs(app, manifest, blocks) do
    blocks
    |> Enum.map(&Path.basename(&1.doc))
    |> Enum.uniq()
    |> Map.new(fn lesson ->
      case Map.fetch(manifest, lesson) do
        {:ok, ref} -> {lesson, if(commit?(app, ref), do: ref, else: {:worktree, ref})}
        :error -> {lesson, {:worktree, nil}}
      end
    end)
  end

  defp commit?(app, ref) do
    {_out, status} =
      System.cmd("git", ["-C", app, "rev-parse", "--verify", "--quiet", ref <> "^{commit}"],
        stderr_to_stdout: true
      )

    status == 0
  end

  defp read_source(app, {:worktree, _ref}, path) do
    file = Path.join(app, path)
    if File.regular?(file), do: {:ok, File.read!(file)}, else: :error
  end

  defp read_source(app, ref, path) do
    case System.cmd("git", ["-C", app, "show", "#{ref}:#{path}"], stderr_to_stdout: true) do
      {contents, 0} -> {:ok, contents}
      {_error, _status} -> :error
    end
  end

  # Parsing ------------------------------------------------------------------

  defp parse(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> collect(path, [], nil)
    |> Enum.reverse()
  end

  defp collect([], _path, acc, nil), do: acc

  defp collect([], path, acc, open) do
    abort("#{path}:#{open.line} code block is never closed")
    acc
  end

  defp collect([{line, number} | rest], path, acc, nil) do
    case fence_info(line) do
      nil ->
        collect(rest, path, acc, nil)

      {lang, source} ->
        open = %{lang: lang, source: source, line: number, doc: path, body: []}
        collect(rest, path, acc, open)
    end
  end

  defp collect([{line, _number} | rest], path, acc, open) do
    if closing_fence?(line) do
      collect(rest, path, [%{open | body: Enum.reverse(open.body)} | acc], nil)
    else
      collect(rest, path, acc, %{open | body: [line | open.body]})
    end
  end

  defp fence_info("```" <> info) do
    case info |> String.trim() |> String.split(~r/\s+/, trim: true) do
      [] -> {nil, nil}
      [lang] -> {lang, nil}
      [lang, source | _] -> {lang, source}
    end
  end

  defp fence_info(_line), do: nil

  defp closing_fence?(line), do: String.trim_trailing(line) == "```"

  # Verification -------------------------------------------------------------

  defp verify(block, app, refs) do
    ref = Map.fetch!(refs, Path.basename(block.doc))

    case read_source(app, ref, block.source) do
      :error ->
        %{block: block, ref: ref, reason: {:missing_file, block.source}}

      {:ok, contents} ->
        case block.body |> chunks() |> match_chunks(squash(contents)) do
          :ok -> nil
          {:error, chunk} -> %{block: block, ref: ref, reason: {:no_match, chunk}}
        end
    end
  end

  # A line that is nothing but a comment is presentation, not code: the lesson
  # may carry one the source lacks, or explain it in prose instead.
  @line_comment ~r{^\s*(?:\#|//|--(?!\S)|<!--|<%!--)}

  defp squash(text) do
    text
    |> String.split("\n")
    |> Enum.reject(&Regex.match?(@line_comment, &1))
    |> Enum.join("\n")
    |> String.replace(~r/\s+/, "")
  end

  # A chunk keeps its original lines for reporting alongside the squashed form
  # the comparison actually uses.
  defp chunks(body) do
    body
    |> Enum.chunk_by(&elision?/1)
    |> Enum.reject(fn [first | _] -> elision?(first) end)
    |> Enum.map(fn lines ->
      %{
        lines: Enum.reject(lines, &(String.trim(&1) == "")),
        squashed: squash(Enum.join(lines, "\n"))
      }
    end)
    |> Enum.reject(&(&1.squashed == ""))
  end

  # A line of bare `...`, or a whole-line comment mentioning `...`, stands in
  # for code the lesson is not showing.
  defp elision?(line) do
    trimmed = String.trim(line)
    trimmed == "..." or (Regex.match?(@line_comment, line) and String.contains?(trimmed, "..."))
  end

  # Each chunk must appear whole, and after the chunk before it.
  defp match_chunks([], _haystack), do: :ok

  defp match_chunks([chunk | rest], haystack) do
    case :binary.match(haystack, chunk.squashed) do
      :nomatch ->
        {:error, chunk}

      {start, length} ->
        match_chunks(rest, binary_part(haystack, start + length, byte_size(haystack) - start - length))
    end
  end

  # Reporting ----------------------------------------------------------------

  defp report(%{block: block, ref: ref, reason: {:missing_file, source}}) do
    warn("#{location(block)} names #{source}, which does not exist in #{describe(ref)}")
  end

  defp report(%{block: block, ref: ref, reason: {:no_match, chunk}}) do
    warn("#{location(block)} has drifted from #{block.source} in #{describe(ref)}")
    warn("  this run of lines is not there:")
    chunk.lines |> Enum.take(6) |> Enum.each(&warn("    #{String.trim_trailing(&1)}"))
    if length(chunk.lines) > 6, do: warn("    ... (#{length(chunk.lines) - 6} more lines)")
  end

  defp report_unannotated(block) do
    warn("#{location(block)} is a #{block.lang} block with no source annotation")
  end

  defp describe({:worktree, nil}), do: "the working tree"
  defp describe({:worktree, ref}), do: "the working tree (#{ref} not found)"
  defp describe(ref), do: ref

  defp location(block), do: "#{Path.relative_to(block.doc, root())}:#{block.line}"

  defp summarize(annotated, unannotated, failures, refs) do
    IO.puts("")

    for {lesson, {:worktree, ref}} <- Enum.sort(refs), ref != nil do
      IO.puts("note: #{lesson} is pinned to #{ref}, which this checkout does not have")
    end

    IO.puts(
      "#{length(annotated)} annotated block(s) checked, #{length(failures)} drifted, " <>
        "#{length(unannotated)} source block(s) not yet annotated"
    )

    if failures == [], do: IO.puts("lessons match the application")
  end

  defp warn(message), do: IO.puts(:stderr, message)

  defp abort(message) do
    warn("check_lessons: #{message}")
    System.halt(2)
  end
end

CheckLessons.main(System.argv())
