import 'dart:convert';

import 'package:dotenv/dotenv.dart';
import 'package:indexer/logger.dart';
import 'package:indexer/surrealdb.dart';

void main(List<String> args) async {
  final surreal = Surreal();

  final env = DotEnv(includePlatformEnvironment: true)..load();

  logger.i('Connecting to SurrealDB...');

  await surreal.init(env);

  logger.i('Setting up tables...');

  final res = await surreal.db.query(initQueries);
  print(JsonEncoder.withIndent('  ').convert(res));

  logger.i('Done!');
}

// ! INFO FOR DB;

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

DEFINE FIELD tags ON TABLE post TYPE option<array>;
DEFINE FIELD tags.* ON TABLE post TYPE string;

DEFINE FIELD labels ON TABLE post TYPE option<array>;
DEFINE FIELD labels.* ON TABLE post TYPE string;

DEFINE TABLE feed SCHEMAFULL;
DEFINE FIELD uri ON TABLE feed TYPE string;
DEFINE FIELD author ON TABLE feed TYPE record(did);
DEFINE FIELD rkey ON TABLE feed TYPE string;
DEFINE FIELD did ON TABLE feed TYPE string;
DEFINE FIELD displayName ON TABLE feed TYPE string;
DEFINE FIELD description ON TABLE feed TYPE option<string>;
DEFINE FIELD avatar ON TABLE feed TYPE option<record(blob)>;
DEFINE FIELD createdAt ON TABLE feed TYPE datetime;

DEFINE TABLE list SCHEMAFULL;
DEFINE FIELD name ON TABLE list TYPE string;
DEFINE FIELD purpose ON TABLE list TYPE string;
DEFINE FIELD createdAt ON TABLE list TYPE datetime;
DEFINE FIELD description ON TABLE list TYPE option<string>;
DEFINE FIELD avatar ON TABLE list TYPE option<record(blob)>;
DEFINE FIELD labels ON TABLE list TYPE option<array>;
DEFINE FIELD labels.* ON TABLE list TYPE string;

DEFINE TABLE follow SCHEMAFULL;
DEFINE FIELD createdAt ON TABLE follow TYPE datetime;
DEFINE FIELD in ON TABLE follow TYPE record(did);
DEFINE FIELD out ON TABLE follow TYPE record(did);

DEFINE TABLE block SCHEMAFULL;
DEFINE FIELD createdAt ON TABLE block TYPE datetime;
DEFINE FIELD in ON TABLE block TYPE record(did);
DEFINE FIELD out ON TABLE block TYPE record(did);

DEFINE TABLE like SCHEMAFULL;
DEFINE FIELD createdAt ON TABLE like TYPE datetime;
DEFINE FIELD in ON TABLE like TYPE record(did);
DEFINE FIELD out ON TABLE like TYPE record<post | feed>;

DEFINE TABLE listitem SCHEMAFULL;
DEFINE FIELD createdAt ON TABLE listitem TYPE datetime;
DEFINE FIELD in ON TABLE listitem TYPE record<list>;
DEFINE FIELD out ON TABLE listitem TYPE record(did);

DEFINE TABLE posts SCHEMAFULL;
DEFINE FIELD in ON TABLE posts TYPE record(did);
DEFINE FIELD out ON TABLE posts TYPE record(post);

DEFINE TABLE replies SCHEMAFULL;
DEFINE FIELD in ON TABLE replies TYPE record(did);
DEFINE FIELD out ON TABLE replies TYPE record(post);

DEFINE TABLE quotes SCHEMAFULL;
DEFINE FIELD in ON TABLE quotes TYPE record(post);
DEFINE FIELD out ON TABLE quotes TYPE record(post);

DEFINE TABLE replyto SCHEMAFULL;
DEFINE FIELD in ON TABLE replyto TYPE record(post);
DEFINE FIELD out ON TABLE replyto TYPE record(post);

DEFINE TABLE repost SCHEMAFULL;
DEFINE FIELD createdAt ON TABLE repost TYPE datetime;
DEFINE FIELD in ON TABLE repost TYPE record(did);
DEFINE FIELD out ON TABLE repost TYPE record(post);


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

DEFINE TABLE quote_count_view AS
SELECT
  count() AS c
  FROM quotes
  GROUP BY out
;

DEFINE TABLE following_count_view AS
SELECT
  count() AS c
  FROM follow
  GROUP BY in
;

DEFINE TABLE follower_count_view AS
SELECT
  count() AS c
  FROM follow
  GROUP BY out
;

INFO FOR DB;

''';

/*

--DEFINE TABLE hastag SCHEMAFULL;
--DEFINE FIELD in ON TABLE hastag TYPE record(post);
--DEFINE FIELD out ON TABLE hastag TYPE record(tag);
-- TODO -- DEFINE INDEX idx_tags ON post FIELDS tags;

-- DEFINE ANALYZER simple TOKENIZERS class FILTERS lowercase;
-- DEFINE ANALYZER typeahead TOKENIZERS class FILTERS lowercase,edgengram(2,10);

-- DEFINE INDEX post_text ON post FIELDS text SEARCH ANALYZER simple BM25 HIGHLIGHTS;
-- DEFINE INDEX post_img_alt_text ON post FIELDS images.*.alt SEARCH ANALYZER simple BM25 HIGHLIGHTS;

-- DEFINE INDEX feed_name ON feed FIELDS displayName SEARCH ANALYZER typeahead BM25;
-- DEFINE INDEX feed_description ON feed FIELDS description SEARCH ANALYZER simple BM25 HIGHLIGHTS;

-- DEFINE INDEX list_name ON list FIELDS name SEARCH ANALYZER typeahead BM25;
-- DEFINE INDEX list_description ON list FIELDS description SEARCH ANALYZER simple BM25 HIGHLIGHTS;

-- DEFINE INDEX did_handle ON did FIELDS handle SEARCH ANALYZER typeahead BM25;
-- DEFINE INDEX did_name ON did FIELDS displayName SEARCH ANALYZER typeahead BM25;
-- DEFINE INDEX did_description ON did FIELDS description SEARCH ANALYZER simple BM25 HIGHLIGHTS;
*/