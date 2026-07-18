#!/usr/bin/env bash
# grandma-lib — shared helpers. Source this; it expects $ROOT (grandma repo root) set.

# Resolve a scope name (case-insensitive) to its dir under ROOT. Prints dir or fails.
resolve_scope_dir() {
  local d name
  for d in "$ROOT"/*/; do
    name="$(basename "$d")"; [[ "$name" == "global" ]] && continue
    if [[ "$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')" == "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" ]]; then
      printf '%s' "${d%/}"; return 0
    fi
  done
  return 1
}

# Normalize a name for fuzzy matching: lowercase, alphanumeric only.
norm() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'; }

# Emit "rawname<TAB>dir" for each project in a scope's projects.md (dir = folder holding CLAUDE.md).
project_entries() {
  local reg="$1"
  [[ -f "$reg" ]] || return 0
  awk '
    /^## / { raw=substr($0,4); sub(/[ \t]+$/,"",raw); haveraw=1; next }
    /^- source:/ && haveraw==1 {
      src=$0; sub(/^- source:[ \t]*/,"",src); sub(/[ \t]+$/,"",src);
      dir=src; sub(/\/[^\/]*$/,"",dir);
      print raw "\t" dir; haveraw=0
    }
  ' "$reg"
}

# Fuzzy-resolve a project name against a scope dir's registry.
# Sets RP_STATUS (OK|AMBIG|NONE), RP_NAME, RP_DIR, RP_CANDS.
# shellcheck disable=SC2034  # RP_STATUS/RP_NAME/RP_DIR/RP_CANDS are outputs read by callers
resolve_project() {
  local reg="$1/projects.md" q raw dir nraw matches=0
  q="$(norm "$2")"
  RP_STATUS=NONE; RP_NAME=""; RP_DIR=""; RP_CANDS=""
  while IFS=$'\t' read -r raw dir; do
    [[ -z "$raw" ]] && continue
    nraw="$(norm "$raw")"
    if [[ -n "$q" && ( "$nraw" == *"$q"* || "$q" == *"$nraw"* ) ]]; then
      matches=$((matches+1)); RP_NAME="$raw"; RP_DIR="$dir"
      RP_CANDS+="${RP_CANDS:+, }$raw"
    fi
  done < <(project_entries "$reg")
  if   [[ $matches -eq 1 ]]; then RP_STATUS=OK
  elif [[ $matches -gt 1 ]]; then RP_STATUS=AMBIG; fi
}

# Munge an absolute path to its Claude projects dir name (/ -> -).
claude_proj_dir() { printf '%s/.claude/projects/%s' "$HOME" "$(printf '%s' "$1" | sed 's#/#-#g')"; }

# List scope names: a scope dir is one whose top-level .md has `scope:` frontmatter
# (excludes global, prompts, assets, proposals, tools, test, etc.).
list_scopes() {
  local d n
  for d in "$ROOT"/*/; do
    n="$(basename "$d")"; [[ "$n" == "global" ]] && continue
    if grep -lqE '^scope:' "$d"/*.md 2>/dev/null; then echo "$n"; fi
  done
}

# ---- portability helpers (BSD/macOS vs GNU/Linux) ----
# GNU form (-c) FIRST: on Linux it succeeds cleanly; on macOS it fails with no stdout, so
# the BSD (-f) fallback runs. The reverse order is unsafe — GNU parses `stat -f %m FILE` as
# `-f` (file-system mode) plus a bogus filename `%m`, printing the real file's fs block
# ("File: ...") to stdout AND exiting nonzero, which then also runs the fallback and yields
# contaminated output. That fed non-numeric junk into arithmetic (the watch tick crash).
file_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }
file_size()  { stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null || echo 0; }
epoch_date() { date -r "$1" '+%Y-%m-%d' 2>/dev/null || date -d "@$1" '+%Y-%m-%d' 2>/dev/null || echo "$1"; }
notify_user() {
  # title, body — macOS notification, Linux notify-send, else log-and-skip.
  # Returns 0 if a backend delivered, 1 if none did (and logs why). A detached watch
  # tick has no terminal, so failures must land in a file to be verifiable, not /dev/null.
  local root="${GRANDMA_HOME:-$HOME/.grandma}" log="${GRANDMA_HOME:-$HOME/.grandma}/.distill/notify.log" err
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$2\" with title \"$1\" sound name \"Glass\"" 2>/dev/null && return 0
  fi
  if command -v notify-send >/dev/null 2>&1; then
    # A backgrounded/nohup'd tick can inherit a shell with no session bus (SSH, tty, cron).
    # notify-send then fails "cannot connect to bus". Derive it from the runtime dir if we can.
    [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "${XDG_RUNTIME_DIR:-}/bus" ]] \
      && export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
    if err="$(notify-send -a grandma "$1" "$2" 2>&1)"; then return 0; fi
    mkdir -p "$root/.distill" 2>/dev/null
    printf '%s notify-send failed: %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$err" >> "$log" 2>/dev/null
    return 1
  fi
  mkdir -p "$root/.distill" 2>/dev/null
  printf '%s no notifier (install libnotify-bin / libnotify): [%s] %s\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" "$2" >> "$log" 2>/dev/null
  return 1
}
