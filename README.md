# MTG Playmat

A Rails 8 and SQLite two-player Magic: The Gathering playmat. It demonstrates
how to build a real-time shared application with Solid Objects.

## Architecture

Each room code addresses one `PlaymatRoom` actor through
[Solid Objects](https://solidobjects.dev/). The actor owns room and player state,
serializes every mutation, and persists to SQLite. Synchronous calls need no
worker process.

### Two kinds of observable

An observable declared with `broadcast: :value` reaches every subscriber of the
actor stream, and both players share one stream. Only room-wide public facts
opt in that way: `version` and `life_totals`.

A seat holds a session identifier, a hand, and a library. `player_one` and
`player_two` therefore stay on the default `broadcast: :invalidation`. They
still detect changes and refresh the reactive components, but they persist an
empty value and send nothing over Action Cable. Each component then renders
under the requesting session's own authorization, so a partial shows a hand
only to its owner.

Card identity reaches the browser through two authorized routes: the
`playmat_state` broadcast payload, which projects the room per connection, and
the component refresh endpoint. A player sees their own hand and library. The
opponent sees the same number of cards, each named "Hidden card". Polling
remains active as a fallback.

Archidekt requests happen outside the actor. Loaded deck data enters the actor
as one ordered message.

## Reactive ERB tour

To see Solid Objects in a Rails page, read these files in this repository:

- [`show.html.erb`](https://github.com/cardmagic/mtg-playmat/blob/main/app/views/api/spaces/observers/show.html.erb)
  mounts the room actor and its reactive state payload.
- [`_table.html.erb`](https://github.com/cardmagic/mtg-playmat/blob/main/app/views/actors/playmat_room/_table.html.erb)
  composes the reactive ERB components and assigns their observables.
- [`_player.html.erb`](https://github.com/cardmagic/mtg-playmat/blob/main/app/views/actors/playmat_room/_player.html.erb)
  renders a per-player component with session-aware authorization.
- [`playmat_room.rb`](https://github.com/cardmagic/mtg-playmat/blob/main/app/actors/playmat_room.rb)
  defines the actor methods and the two kinds of observable it publishes.
- [`solid_objects.rb`](https://github.com/cardmagic/mtg-playmat/blob/main/config/initializers/solid_objects.rb)
  shows the authorization boundary used for component refreshes.

The browser keeps these controls and search results as reactive ERB components,
while high-frequency board mutations apply the actor's state payload directly
so the table can update without waiting for a follow-up component request.

## Setup

```bash
bin/setup
bin/dev
```

`bin/dev` starts the Rails server and the Solid Objects runtime as two
processes, so a code reload never touches a running worker thread.

Production runs both in one process. `SOLID_OBJECTS_IN_PUMA` turns on the Puma
plugin in `lib/puma/plugin/solid_objects.rb`, which starts the Solid Objects
supervisor after Puma boots and stops it before Puma stops. One process means
`SolidObjects.wake_up` reaches the runtime threads directly, so a message needs
no poll to cross from a web thread to a worker. The plugin needs Puma in single
mode, and it fails at boot when Puma is configured with workers.

## Honeybadger tracing

Production exports OpenTelemetry spans to Honeybadger when
`HONEYBADGER_API_KEY` is present. The traced interaction spans are
`draw_card`, `play_from_hand`, and `toggle_tap`, with nested actor parse,
apply, and commit spans. Keep the key in your secret manager or deployment
environment. This repository does not store it. Set
`OTEL_EXPORTER_OTLP_ENDPOINT` only when using a different OTLP collector.

The production deployment also runs a private Jaeger all-in-one accessory on
`cf-docker` with persistent Docker-backed Badger storage. To view traces,
open an SSH tunnel with `ssh -N -L 16686:127.0.0.1:16686 cf-docker` and visit
`http://localhost:16686`.

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
