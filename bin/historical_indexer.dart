import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dotenv/dotenv.dart';
import 'package:indexer/process_graph_operation.dart';
import 'package:indexer/surrealdb.dart';
import 'package:indexer/util/parse_car_file.dart';
import 'package:lib5/lib5.dart';
import 'package:http/http.dart' as http;

int reqs = 0;

final surreal = Surreal();
final httpClient = http.Client();

// This delay combined with the concurrency limit of 10 tries to keep the requests/second below 10 to not hit the rate limit
int extraDelayMillis = 1000;

late final Set<String> ignoredRecordTypes;

void main(List<String> args) async {
  final env = DotEnv(includePlatformEnvironment: true)..load();

  ignoredRecordTypes = env['HISTORICAL_INDEXER_IGNORE']?.split(',').toSet() ??
      <String>{
        'app.bsky.feed.post',
        'app.bsky.feed.repost',
        'app.bsky.feed.like',
      };
  print('IGNORED RECORD TYPES: $ignoredRecordTypes');

  await surreal.init(env);

  final allDIDs = <String>[];

  String? repoCursor;

  print('Listing all repos...');

  while (true) {
    final res = await httpClient.get(
      Uri.parse(
        'https://bsky.social/xrpc/com.atproto.sync.listRepos?limit=1000' +
            (repoCursor == null ? '' : '&cursor=$repoCursor'),
      ),
    );

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final repos = data['repos'];
    if (repos.isEmpty) break;
    for (final repo in repos) {
      allDIDs.add(repo['did']);
    }
    repoCursor = data['cursor'];
    print('progress: ${allDIDs.length} repos (cursor: $repoCursor)');

    await Future.delayed(Duration(milliseconds: 130));
  }
  print('Starting indexer...');
  final progressCursorFile = File('historical_indexer_progress_cursor');

  String? progressCursor;

  if (progressCursorFile.existsSync()) {
    progressCursor = progressCursorFile.readAsStringSync();
    print('Found progress cursor, continuing at "$progressCursor"');
  }

  int i = 0;

  Stream.periodic(Duration(seconds: 5)).listen((event) {
    final reqPerSecond = reqs / 5;
    print('${reqPerSecond.round()} req/s');
    if (reqPerSecond > 9) {
      extraDelayMillis += 500;
    } else if (reqPerSecond < 8) {
      if (extraDelayMillis > 100) {
        extraDelayMillis -= 100;
      }
    }
    reqs = 0;
  });

  bool skip = progressCursor != null;

  for (final did in allDIDs) {
    if (skip) {
      if (progressCursor == did) {
        skip = false;
      } else {
        continue;
      }
    } else {
      if (i % 500 == 200) {
        Future.delayed(Duration(seconds: 60 * 5)).then((value) {
          progressCursorFile.writeAsStringSync(did);
        });
      }
    }
    i++;
    print(
      '[${(i / allDIDs.length).toStringAsFixed(2)}] $did (delay: $extraDelayMillis)',
    );

    while (concurrency >= 10) {
      await Future.delayed(Duration(milliseconds: 10));
    }
    processRepo(did);
  }
  while (concurrency > 0) {
    await Future.delayed(Duration(milliseconds: 100));
  }
  print('DONE');

  exit(0);
}

int concurrency = 0;

final actors = [];

Future<void> processRepo(String did) async {
  concurrency++;

  try {
    await Future.delayed(Duration(milliseconds: extraDelayMillis));

    reqs++;
    final res = await httpClient.get(
      Uri.parse(
        'https://bsky.social/xrpc/com.atproto.sync.getCheckout?did=$did',
      ),
    );
    final mb = (res.bodyBytes.length / 1000 / 1000);

    print(
      'checkout $did (${mb.toStringAsFixed(2)} MB)',
    );

    if (res.statusCode != 200) {
      throw 'HTTP ${res.statusCode}';
    }

    final blocks = parseCARFile(res.bodyBytes);

    for (final key in blocks.keys) {
      final block = blocks[key]!.cast<String, dynamic>();
      if (block.containsKey('e')) {
        String lastStr = '';
        for (final e in block['e']) {
          int prefixLength = e['p'];
          String keySuffix = ascii.decode(e['k']);
          lastStr = lastStr.substring(0, prefixLength) + keySuffix;

          final valueCID = Multihash(Uint8List.fromList(e['v'].sublist(1)));
          final block = blocks[valueCID]!;
          final parts = lastStr.split('/');

          if (parts[0] != block['\$type']) {
            throw '$did $parts $block hmm';
          }
          if (!ignoredRecordTypes.contains(block['\$type'])) {
            await processGraphOperation(
              did,
              'create',
              block['\$type'],
              parts[1],
              block.cast<String, dynamic>(),
              surreal: surreal,
            );
          }
        }
      } else if (block.containsKey('\$type')) {
      } else if (block['version'] == 2) {
      } else if (block.isEmpty) {
      } else if (block.containsKey('unofficial')) {
      } else {
        throw 'IGNORETHISERROR $block';
      }
    }
  } catch (e, st) {
    final errStr = e.toString();
    if (errStr.contains('HTTP 502') ||
        errStr.contains('Connection closed before full header was received') ||
        errStr.contains('Connection closed while receiving data')) {
      concurrency--;
      await processRepo(did);
      return;
    }
    if (!e.toString().contains('Could not find user')) {
      if (!e.toString().contains('IGNORETHISERROR')) {
        File('error_log.txt').writeAsStringSync(
          '$did $e: $st\n\n',
          mode: FileMode.writeOnlyAppend,
        );
      }
    }
    await Future.delayed(Duration(seconds: 1));
  }
  concurrency--;
}
