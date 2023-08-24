import 'package:dotenv/dotenv.dart';
import 'package:indexer/logger.dart';
import 'package:indexer/surrealdb.dart';

void main(List<String> args) async {
  final surreal = Surreal();

  final env = DotEnv(includePlatformEnvironment: true)..load();

  logger.i('Connecting to SurrealDB...');

  await surreal.init(env);

  logger.i('Setting up tables...');

  await surreal.db.query(initQueries);

  logger.i('Done!');
}

const initQueries = '''DEFINE TABLE did SCHEMAFULL;

DEFINE FIELD handle ON TABLE did TYPE option<string>;
DEFINE FIELD displayName ON TABLE did TYPE option<string>;
DEFINE FIELD description ON TABLE did TYPE option<string>;
DEFINE FIELD avatar ON TABLE did TYPE option<record(blob)>;
DEFINE FIELD banner ON TABLE did TYPE option<record(blob)>;

DEFINE TABLE blob SCHEMAFULL;
DEFINE FIELD mediaType ON TABLE blob TYPE string;
DEFINE FIELD mediaSubtype ON TABLE blob TYPE string;
DEFINE FIELD size ON TABLE blob TYPE option<int>;

DEFINE TABLE post SCHEMAFULL;
DEFINE FIELD text ON TABLE post TYPE string;
DEFINE FIELD createdAt ON TABLE post TYPE datetime;
DEFINE FIELD author ON TABLE post TYPE record(did);
DEFINE FIELD parent ON TABLE post TYPE option<record(post)>;
DEFINE FIELD root ON TABLE post TYPE option<record(post)>;

DEFINE FIELD images ON TABLE post TYPE option<array>;
DEFINE FIELD images.* ON TABLE post TYPE object;

DEFINE FIELD images.*.alt ON TABLE post TYPE string;
DEFINE FIELD images.*.blob ON TABLE post TYPE record(blob);

DEFINE FIELD record ON TABLE post TYPE option<record>;

DEFINE FIELD mentions ON TABLE post TYPE option<array>;
DEFINE FIELD mentions.* ON TABLE post TYPE record(did);
DEFINE FIELD links ON TABLE post TYPE option<array>;
DEFINE FIELD links.* ON TABLE post TYPE string;

DEFINE FIELD langs ON TABLE post TYPE option<array>;
DEFINE FIELD langs.* ON TABLE post TYPE string;

DEFINE FIELD labels ON TABLE post TYPE option<array>;
DEFINE FIELD labels.* ON TABLE post TYPE string;

DEFINE TABLE like_count_view AS
SELECT
  count() AS c
  FROM like
  GROUP BY out
;

DEFINE TABLE repost_count_view AS
SELECT
  count() AS c
  FROM repost
  GROUP BY out
;

DEFINE TABLE reply_count_view AS
SELECT
  count() AS c
  FROM replyto
  GROUP BY out
;

''';


/* DEFINE TABLE link SCHEMAFULL;
DEFINE FIELD scheme ON TABLE link TYPE string;
DEFINE FIELD authority ON TABLE link TYPE string;
DEFINE FIELD path ON TABLE link TYPE string;
DEFINE FIELD query ON TABLE link TYPE string;
DEFINE FIELD fragment ON TABLE link TYPE string; */