# SkyFeed Indexer

ATProto/Bluesky Indexer, powered by [SurrealDB](https://github.com/surrealdb/surrealdb) and written in the [Dart programming language](https://dart.dev/).

The Firehose indexer subscribes to one (or multiple) Bluesky Firehose endpoints (`/xrpc/com.atproto.sync.subscribeRepos`), converts all events to SurrealQL queries and inserts them into the database.

This repository also includes a historical indexer for the full current state of the network using the `com.atproto.sync.listRepos` and `com.atproto.sync.getCheckout` endpoints. It can be configured to only persist specific events, for example the social graph (follows, blocks, profiles).

The database can then be used to run powerful queries on the network data or build advanced custom feeds. All skyfeed.xyz feeds are powered by this service.

Warning: The implementation does NOT verify the integrity of events or blocks right now.

## Setup SurrealDB

1. Install **SurrealDB Nightly** on your system, instructions are available here: https://surrealdb.com/docs/installation/nightly
2. Generate a secure password, for example using `pwgen -s 32 1`
3. Run SurrealDB with `surreal start --user root --pass CHANGEME_TO_YOUR_PASSWORD --bind 127.0.0.1:8000 file:surreal.db`

When using `file:surreal.db`, all data is stored in the subdirectory `surreal.db/` of your current working directory.

If you want to expose the database to your network, use `--bind 0.0.0.0:8000` instead.

## Setup the indexer

1. Install Dart (https://dart.dev/get-dart)
2. Clone this repository using `git clone https://github.com/skyfeed-dev/indexer.git`
3. Copy the `.env.example` file to `.env`
4. Put your SurrealDB password in `.env`
5. Run `dart pub get` to install dependencies
6. Run `dart run bin/setup_surreal.dart` to create tables

## Run the Firehose indexer

`dart run bin/firehose_indexer.dart`

## Run the Historical indexer

`dart run bin/historical_indexer.dart`
