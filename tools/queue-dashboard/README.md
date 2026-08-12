# Queue dashboard

A local, live view of everything the queue is currently blocked on, with a box to answer
each blocker in place.

```
node tools/queue-dashboard/server.mjs
# http://127.0.0.1:4317
```

## Run it from a pinned worktree, not the shared clone

The dashboard is a long-running service; the clone it runs from is also a working tree
that other sessions check branches out of. Those two facts collide. A concurrent session
switched `claude-harness` from this branch to another mid-session, which silently
replaced `server.mjs` with a pre-auth version while a tailnet proxy was about to be
pointed at the port.

So give it its own checkout and point the hook there:

```
git worktree add ~/Repo/claude-harness-dashboard feature/queue-dashboard
```

`start.ps1` also fails closed: it greps the server file for the token check and refuses
to start anything that lacks it, so a mispointed path degrades to "no dashboard" rather
than "unauthenticated dashboard".

## Starting it automatically

`start.ps1` starts the server only if nothing is already accepting on the port, so it is
safe to run on every Claude Code session. Wire it up as a `SessionStart` hook in
`~/.claude/settings.json` (a local file, deliberately not tracked here):

```json
"hooks": {
  "SessionStart": [
    { "hooks": [ {
      "type": "command",
      "shell": "powershell",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"$env:USERPROFILE\\Repo\\claude-harness-dashboard\\tools\\queue-dashboard\\start.ps1\"",
      "async": true,
      "timeout": 20
    } ] }
  ]
}
```

`async` keeps it off the startup path. If two sessions start at once and both find the
port free, the loser exits quietly on `EADDRINUSE`. Server output goes to
`%TEMP%\queue-dashboard.log`.

## Why it is a server and not an artifact

An artifact is a snapshot. It is published once, so it cannot see a queue file that
changed a minute later, and answers given inside it have to be hand-carried back into
the queue by a later session. This reads the real files on every request and writes
answers straight back, so there is no capture step and nothing to re-transcribe.

## What it shows

**Blocked on you** comes first and holds only items that are genuinely waiting: an item
counts as blocked when it has a `Blocked reason` field, or a log line saying
`DECISION NEEDED` / `BLOCKED ON YOU` / `NEEDS YOUR DECISION`, **and** no `DECIDED` line
answering it yet. Everything else is collapsed underneath. Open PRs come from `gh`,
cached 60s because it is slow; the queue read itself is never cached.

## What answering does

Four presets (Approved / Rejected / Defer / Ask me again) submit immediately; anything
typed in the box is appended to the preset, or sent on its own with **Send answer**.
Each answer writes two things into the item it belongs to:

- a `DECIDED <date> by Faruk, via the queue dashboard: <answer>` line directly under
  `Status:`, because that is the first thing an agent run reads
- an `ANSWERED` entry at the end of that item's `Log:` section, as the audit trail

and one row into `TRIAGE-<date>.md`, under an `## Answers from the live dashboard`
section, so a later run can read the day's decisions in one place.

An answer is a recorded decision, not executed work. Nothing here runs anything.

## Study checklist

`STUDY.md` in the queue directory is rendered as a live checklist under the queue cards.
It is a plain GitHub-flavoured Markdown task list: `## ` headings become tracks, and every
`- [ ]` / `- [x]` line becomes a row with a per-track and an overall count.

Ticking a box rewrites that one line in the file. Nothing else about it is special: no
`DECIDED` line, no `Log:` entry, no `TRIAGE` row, and it never appears under **Blocked on
you**, because finishing a chapter is not a decision anyone is waiting on. Edit the file
by hand whenever you like; the page picks it up on the next 5s poll.

It lives here because this is the page already open on the phone, which is where the
studying actually happens. Delete the file and the section just says so.

## Safety of the write-back

The queue files are long and hand-written, so every write is guarded:

- a `.bak` copy is taken before the file is touched
- the write is temp-file-plus-rename, so a crash cannot leave a half-written queue
- the page sends the mtime it read; a newer mtime on disk returns 409 and refuses the
  write, so a concurrent session or dispatch run is never clobbered
- only the target item's block is rewritten; the rest of the file is passed through
  byte for byte

A study tick is guarded the same way, plus one more check: the page sends the text of the
task it thinks it is ticking, and a mismatch returns 409. The index alone would tick
whatever line happens to sit at that position if the file were reordered between the read
and the click.

Polling pauses while the answer box has focus, so a repaint cannot wipe half-typed text.

## Unlocking

Every request needs a token, including loopback ones. That is deliberate rather than
paranoid: under `tailscale serve` the phone's requests arrive at the server *from*
127.0.0.1, so exempting loopback would exempt the phone too, and telling them apart
would mean trusting a request header the server cannot verify.

The token is generated on first run and stored in `.dashboard-token` inside the queue
directory (outside the repo, never committed). It is also printed at startup, so
`%TEMP%\queue-dashboard.log` has it. Set `QUEUE_TOKEN` to pin your own instead.

Visiting the dashboard shows an unlock form; the cookie it sets is `HttpOnly`,
`SameSite=Strict`, and good for a year, so it is a once-per-browser step. Deleting
`.dashboard-token` and restarting rotates the token and logs every browser out.

## Reaching it from a phone

The server stays bound to `127.0.0.1` and is never exposed to a network directly.
Tailscale puts your phone and PC on a private mesh and proxies into that loopback port:

There are two ways to do it. Both keep the dashboard off the public internet and off the
local network; they differ in whether Tailscale proxies for you or you bind its address
directly.

**Direct tailnet bind (no admin console needed).** Create the marker file and restart:

```
New-Item -ItemType File ~/.claude-harness/queue/.dashboard-tailnet
```

The server then listens on loopback *and* on the machine's `100.x` Tailscale address,
and nothing else. The address is validated against Tailscale's `100.64.0.0/10` range
before binding, so a misreported `0.0.0.0` or LAN address is refused rather than
exposing the queue to the local network. Traffic is WireGuard-encrypted end to end;
there is no TLS certificate, so the browser will call `http://100.x.y.z:4317` insecure
even though the transport is not. Delete the marker to go back to loopback-only.

**`tailscale serve` (HTTPS, needs Serve enabled once on the tailnet).** Gives a real
certificate and a `https://<machine>.<tailnet>.ts.net` name:

```
tailscale up                       # once, on the PC - opens a browser to sign in
tailscale serve --bg 4317          # publish to your tailnet over HTTPS
tailscale serve status             # prints the URL
```

If it answers "Serve is not enabled on your tailnet", that is a one-time toggle in the
Tailscale admin console, not something the CLI can turn on.

Install the Tailscale app on the phone, sign in to the same account, then open that URL
and unlock once. Nothing is exposed publicly, no router port is opened, and only devices
signed in to your own tailnet can reach the hostname at all. The token is the second
layer behind that.

To stop publishing: `tailscale serve --https=443 off`.

## Configuration

| Variable | Default |
|---|---|
| `QUEUE_DIR` | `~/.claude-harness/queue` |
| `PORT` | `4317` |
| `QUEUE_TOKEN` | generated into `.dashboard-token` on first run |

It binds `127.0.0.1` only, and should stay that way. The queue holds private content, so
remote access belongs behind an identity-checked mesh like Tailscale, not behind a
`0.0.0.0` bind or a public tunnel.
