# MTG Playmat

A Rails 8 and SQLite two-player Magic: The Gathering playmat. It demonstrates
how to build a real-time shared application with Solid Objects.

## Architecture

Each room code addresses one `PlaymatRoom` actor through
[Solid Objects](https://solidobjects.dev/). The actor owns room and player state,
serializes every mutation, and persists to SQLite. Synchronous calls need no
worker process.

The actor explicitly exposes only its version as an observable. Solid Objects
broadcasts that version over Action Cable, and the browser fetches the
session-filtered room snapshot. An opponent can see hand size but never card
details. Polling remains active as a fallback.

Archidekt requests happen outside the actor. Loaded deck data enters the actor
as one ordered message.

## Setup

```bash
bin/setup
bin/dev
```

`bin/dev` starts the Rails server and the Solid Objects runtime. Production
needs both processes from the included `Procfile`.

## Kamal deployment

The public deployment configuration contains no infrastructure addresses or
credentials. Supply those values at deploy time and keep `.kamal/secrets` out
of version control:

```bash
KAMAL_SERVER_HOST=your-server.example \
KAMAL_PROXY_HOST=playmat.example \
bin/kamal deploy
```

The deployment secrets file can source values from a password manager, the
environment, or a local file. Never commit certificates, private keys,
`config/master.key`, registry passwords, or database files.

## Verification

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
bin/rails zeitwerk:check
bin/rails solid_objects:doctor
```

The doctor reports a neutral-context authorization warning by design. The app
authorizes actor calls with a signed playmat session and room-bound server
context while destroy and administration remain denied.
