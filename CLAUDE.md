# grandma (open source)

You are working on grandma itself: the public, open-source version of the memory
layer for Claude Code. This is the clean-room repo that ships to the world, not
Anshul's private memory home. Role here is writer: you develop grandma, author
changes as Anshul, and the output is his.

## What it is
- A memory layer for Claude Code, written in bash. It gives Claude Code a persistent,
  per-context memory that lives as plain markdown in the user's own git repo.
- Public repo: `anshulforyou/grandma` on GitHub, remote `origin`, branch `master`.
  Currently v0.1. License MIT. No telemetry, no server, no accounts.
- The public README, CONTRIBUTING, CHANGELOG, and docs/ are the user-facing contract.
  Treat them as product, not scratch notes.
- The engine ships here. The user's memory does NOT. Personal data stays in the private
  home repo (`~/.grandma` on an installed machine, and Anshul's own grandma repo during
  development).

## Core promises this repo must never break
- **Clean-room split (security-critical).** This repo is engine only, with fresh history.
  Nothing personal ever lands here: no real names, no employer facts, no absolute user
  paths, no chat-derived analysis, no scope names from anyone's real life. Engine code
  says "the user" and reads identity from memory files at runtime. If a change needs
  context-specific behavior, it belongs in a memory file or a prompt that reads memory,
  never in engine code.
- **Sweater isolation.** Loading context X assembles exactly global plus X and nothing
  else. This is guaranteed by a test, not by care.
- **Nothing acts outward on its own.** Writes land as uncommitted diffs the user reviews
  with git. No auto-commit, no auto-push. See "How to work here."

## Layout
```
bin/grandma          single entry point, dispatches subcommands
lib/                 the engine
  grandma-lib.sh     shared helpers (file_mtime, file_size, epoch_date, notify_user, ...)
  assemble.sh        builds the memory bundle for a session
  grandma-launch.sh  launches Claude Code with the bundle
  grandma-init.sh    first-run setup and interview
  grandma-save.sh    distill a finished session into memory
  grandma-review.sh  review what background distills proposed
  grandma-ingest.sh  catalog an existing folder of projects
  grandma-watch.sh   session-analytics campaigns
  grandma-rehydrate.sh  re-inject memory after compaction
  grandma-session-end.sh  end-of-session distill
  grandma-test.sh    the integrity invariants
prompts/             the LLM prompts (capture, distiller, onboard, ingest, init-interview,
                     new-scope, watch-digest, watch-report)
hooks/pre-commit     the integrity gate, wired via git config core.hooksPath hooks
templates/           what a fresh GRANDMA_HOME is seeded with
test/                run.sh plus one cmd_<name>.sh per command, fixtures in test/lib
docs/                architecture.md (incl. the war stories), use-cases.md
install.sh           curl-pipe installer: clone plus PATH shim plus doctor
```

## Where it is going
Three phases. Remember (scoped memory) and watch (session analytics) are shipped. Knit
(the execution phase, where grandma acts on what it learned) is next and open for design.
The immediate milestone is not yet decided: candidates are building knit, pre-launch and
launch polish (portability, install, docs), and steady maintenance of issues and PRs.
Confirm the current focus with Anshul before starting a large piece of work.

## How to work here
- Plan and scope before coding. Name what the change is, who it is for (open-source devs
  running Claude Code, plus Anshul as maintainer), what "done" means, and what test proves
  it. Ask when unsure rather than guessing.
- **Never act outward without explicit confirmation.** No commit, no push, no PR, no PR
  comment, no posted issue, no release. Draft it and wait. Approval for one push is not
  approval for the next.
- Prefer reuse over rewrite: the helpers in `lib/grandma-lib.sh` and the existing test
  fixtures already cover most needs. Check before adding.

## Engineering rules (these get a change merged)
- **Bash 3.2 compatible** (macOS ships it): no associative arrays, no mapfile, guard empty
  array expansion with `${arr[@]+"${arr[@]}"}`.
- **Portable**: use the lib helpers (file_mtime, file_size, epoch_date, notify_user), not
  `stat -f` / `date -r` / osascript directly. Target macOS and Linux, bash 3.2 plus.
- **Shellcheck clean at warning**: `shellcheck -S warning lib/grandma-<name>.sh` must pass.
  Suppress only genuine false positives, annotated with a one-line reason. Do not blanket
  ignore SC2154 / SC2034; those are how var-name bugs surface.
- **Anything that spawns a headless model call needs three guards**: a recursion guard, a
  cost cap, and a lockfile or circuit breaker. Read docs/architecture.md for why (a hook
  recursion once produced 4,718 files). Prove the guard fires with the fake-claude shim,
  do not just assert the string exists.
- **New bug class means a new invariant.** If you fix something the suite would have missed,
  add the check to lib/grandma-test.sh.

## Definition of done for a command (or a new sub-path of one)
Every command ships with all of these, or it is not done:
1. A dry-run smoke assertion. If it ends in `exec claude` / `claude -p`, it MUST honor
   `GRANDMA_DRY_RUN=1` (print a plan, exit 0, no exec). Add `test/cmd_<name>.sh` against the
   populated fixture and assert the exit code and that output has no `unbound variable`.
   Every command must survive `set -u`.
2. A correctness assertion for any name or path parsing, tested against the kebab-case
   fixture sweater `home-ops`, not a one-word name. Splitting a scope on `-` is a bug.
3. Shellcheck clean at warning.
4. If it spawns a headless call, a delta-test showing the guard actually stops work (with
   vs without), using the fake-claude shim.
5. Registered by dropping the file at `test/cmd_<name>.sh`; run.sh picks it up. Must pass on
   ubuntu-latest and macos-latest.

Fixture scope names must never appear in a core engine file (check 2 is case-insensitive):
use invented names like `globex` / `home-ops`, never a real example word from a prompt.

## Test gate
- `./test/run.sh` runs everything: the structural invariants (`grandma test`), the cold
  install smoke, the onboarding e2e, and one behavioral test per command. Run a single one
  directly while iterating, for example `./test/cmd_review.sh`.
- Install the gate locally with `git config core.hooksPath hooks` so the invariants run
  pre-commit. CI runs the same suite on macOS and Linux plus `shellcheck -S warning`.
- Green tests are the bar. If they fail, say so plainly with the output.

## Writing that ships (README, docs, commits, PRs, issues, release notes)
- Everything here is public and reads as Anshul's own work. Write in his voice.
- No LLM artifacts: no em-dashes, no semicolons, no arrows, no curly quotes, ASCII prose
  only. No "as an AI" phrasing. Vary sentence length, do not mirror a spec's headings 1:1.
- Never name Claude, any LLM, or AI as the author anywhere a human will read it. No
  co-author trailers, no attribution lines, in any commit, PR, or shipped file.
- Match the existing README and docs tone: concrete, transcript-driven, honest about
  failure modes.

## Working style with Anshul (confirmed in practice)
- Verify assumptions empirically before building. Write a probe or a fail-first test that
  proves the gap exists, do not reason about it and move on.
- A test must bite: it fails before the fix and passes after. Prove both, and keep the
  before and after in the change notes.
- Land the change and its test together so master CI never goes red.
- Commit minimally and cleanly. Never iterate or debug in public history. Cosmetic and
  asset work happens locally, is verified, and lands in one commit.
- Communicate plainly. Save marketing language for marketing. In docs and prompts, land
  the point, do not perform. Define a new term functionally with a concrete example first,
  metaphor second.
- For input UX or anything a test cannot cover, verify in a real terminal before shipping.

## Hard-won learnings (read before touching the launch path, hooks, or tests)
- The shell that runs ad hoc commands during development may be zsh, but the engine scripts
  run under bash via their shebang. Do not validate by sourcing a lib into an interactive
  shell, because BASH_SOURCE is empty in zsh and an unmatched glob aborts under zsh nomatch.
  Test by running a real bash script file.
- stat and date differ on BSD (macOS) and GNU (Linux). In the helpers, probe the GNU form
  first: stat -c before stat -f, and date -d before date -r. BSD stat -c fails cleanly with
  no stdout, but GNU stat -f prints a filesystem block to stdout and still exits nonzero,
  which contaminates the result and once crashed watch on Linux.
- Do not rely on the SessionEnd hook for a closed window. Whether it fires on SIGHUP is
  undocumented, and hooks have a hard 1.5 second timeout with a process tree kill. The
  launcher wraps the session (it does not exec) and traps HUP and TERM to run the exit
  distill itself. SIGKILL and hard crashes still cannot be caught, though in-flight
  captures survive those because they are written during the session.
- Claude Code cannot rewrite a user prompt. UserPromptSubmit can only inject context or
  block the prompt. PreToolUse can rewrite a tool call with updatedInput, or block it. This
  is the hinge for the knit phase: advise or guard at the prompt, rewrite or block the action.
- curl pipe bash makes stdin a pipe, so [ -t 0 ] is false and an interactive TUI cannot
  attach even through a /dev/tty redirect. Never launch an interactive claude from a piped
  installer. init sets up and hands off, and the interview runs on the first real grandma.
- shellcheck at warning flags the unbound and unused variable classes (SC2154 and SC2034)
  that once shipped a dead ingest and a crashing review. SC2034 reads as a harmless unused
  variable, so the behavioral tests that run every command under set -u are the real guard,
  not the linter.
- In tests, signal a process group with kill -s HUP -- -"$pgid". Without the double dash the
  negative pgid is read as a signal. kill -0 is fooled by a zombie, so confirm a process is
  really gone by watching for its side effect, not the pid.
- Do not put a concrete sweater-like name anywhere in a core file, not even as an example in
  a prompt or an inline comment. check 2 is case-insensitive and strips only full-line
  comments, so an example word in an inline comment or a prompt collides the day a user
  creates a sweater with that name. This has bitten more than once. Use a
  <name> placeholder, or an invented fixture name like globex or home-ops.

## Recent decisions and open threads (as of 2026-07-13)
Newest first. Trim this as it ages. The git log is the full record.
- Shipped: grandma <unknown-sweater> offers to knit it instead of a raw scope error, and the
  free-text new-sweater prompt uses read -e for cursor editing.
- Shipped: closing the window no longer loses a session. The launcher HUP and TERM trap runs
  a detached background distill. A No durable learnings distill leaves no file and does not
  ping. The next launch offers to review a prior session's proposal.
- Shipped: the session review happens at exit. The launcher wraps the session and
  post_session distills and offers review on a clean exit. GRANDMA_DEFER_DISTILL keeps the
  SessionEnd hook from distilling the same session twice.
- Shipped: the behavioral test harness, added after four real bugs reached the public repo
  from untested command paths (a dead ingest, a review that crashed and mis-resolved kebab
  scopes, a Linux-broken file_mtime). Every command now has a fail-first cmd_ test.
- Open: knit, the execution phase, is designed but not built. Rules stored as reviewable
  markdown, cheap mechanical matchers only at prompt time to keep latency low. The README
  knit teaser about improving a prompt needs reframing, since a prompt cannot be silently
  rewritten. The real rewriting power is at the action layer via PreToolUse.
- Open idea, not built: treat declining a live capture as defer to the exit review, so the
  distiller reliably re-proposes it instead of leaving it to the model's judgment.
- Set aside: an OS notification when a background distill drafts a note, judged possibly too
  intrusive before launch. The design is recoverable if wanted.

## Local development note
Develop from a local engine checkout that is separate from the private memory home. On the
dev machine, grandma on PATH points at this checkout, and GRANDMA_HOME points at the private
home repo rather than the default. To try a change end to end without touching real memory,
point GRANDMA_HOME at a throwaway directory, run bin/grandma init, make a sweater, and
exercise the flow there. This CLAUDE.md stays free of personal paths and data on purpose,
per the clean-room split. Personal and operational context lives in the private home.
