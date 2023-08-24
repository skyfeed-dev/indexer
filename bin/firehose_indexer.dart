import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:indexer/logger.dart';
import 'package:indexer/surrealdb.dart';
import 'package:indexer/process_graph_operation.dart';
import 'package:indexer/util/parse_car_file.dart';

import 'package:cbor/simple.dart' as simple;
import 'package:dotenv/dotenv.dart';
import 'package:lib5/lib5.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final surreal = Surreal();

void main(List<String> arguments) async {
  final env = DotEnv(includePlatformEnvironment: true)..load();

  await surreal.init(env);

  final List cursorRes = await surreal.db.select(
    'cursor:`bsky.social`',
  );

  String? cursor;
  if (cursorRes.isNotEmpty && cursorRes[0].isNotEmpty) {
    cursor = cursorRes[0]['cursor'].toString();
  }

  final uri =
      'wss://bsky.social/xrpc/com.atproto.sync.subscribeRepos${cursor == null ? '' : '?cursor=$cursor'}';

  logger.i('WebSocket URI: $uri');

  var channel = WebSocketChannel.connect(Uri.parse(uri));

  channel.stream.listen((msg) async {
    final message = msg as Uint8List;

    final data = simple.cbor.decode([0x82] + message) as List;
    try {
      await processMessage(data[0] as Map, data[1] as Map);
    } catch (e, st) {
      logger.e('Processing event ${json.encode(data)} failed', e, st);
    }
  });
}

int messageCounter = 0;

Future<void> processMessage(Map header, Map obj) async {
  ensureOnlyKeys(header, {'t', 'op'});

  if (header['t'] != '#commit') {
    if (header['t'] == '#handle') {
      surreal.db.change(didToKey(obj['did']), {'handle': obj['handle']});

      return;
    } else {
      throw 'INVALID HEADER $header';
    }
  }

  if (header['op'] != 1) {
    throw 'INVALID HEADER $header';
  }

  ensureOnlyKeys(obj, {
    'ops',
    'seq',
    'prev',
    'repo',
    'time',
    'blobs', // TODO Process blobs
    'blocks',
    'commit',
    'rebase',
    'tooBig',
  });

  final List ops = obj['ops'];

  final blocks = parseCARFile(Uint8List.fromList(obj['blocks']));

  for (final op in ops) {
    ensureOnlyKeys(op, {'cid', 'path', 'action'});

    final String action = op['action'];
    final String path = op['path'];

    final parts = path.split('/');

    final String recordType = parts[0];

    Map<String, dynamic>? block;

    try {
      final cid = Multihash(Uint8List.fromList(op['cid']).sublist(1));
      block = blocks[cid]!.cast<String, dynamic>();
    } catch (_) {}

    await processGraphOperation(
      obj['repo'],
      action,
      recordType,
      parts[1],
      block,
      surreal: surreal,
      doRethrow: false,
    );
  }

  if (obj['rebase']) {
    throw 'REBASE $obj';
  }
  if (obj['tooBig']) {
    throw 'TOO BIG $obj';
  }
  final cursor = obj['seq'] as int;

  messageCounter++;
  if (messageCounter % 1000 == 0) {
    Future.delayed(Duration(seconds: 30)).then((value) {
      surreal.db.update(
        'cursor:`bsky.social`',
        {'cursor': cursor},
      );
    });
  }
}

void ensureOnlyKeys(Map map, Set<String> keys) {
  for (final key in map.keys) {
    if (!keys.contains(key)) {
      throw 'Invalid key: $key in $map';
    }
  }
}
