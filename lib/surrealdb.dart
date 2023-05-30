import 'package:dotenv/dotenv.dart';

import 'package:surrealdb/surrealdb.dart';

import 'logger.dart';

class Surreal {
  late final SurrealDB db;

  Future<void> init(DotEnv env) async {
    db = SurrealDB(
      env['SURREAL_URL']!,
      onError: (e) => logger.e(e),
      options: SurrealDBOptions(
        timeoutDuration: Duration(minutes: 60),
      ),
    );
    db.connect();
    await db.wait();
    await db.use(env['SURREAL_NS'] ?? 'atproto', env['SURREAL_DB'] ?? 'bsky');
    await db.signin(user: env['SURREAL_USER']!, pass: env['SURREAL_PASS']!);
  }
}

final validDidKeyRegex = RegExp(r'^(plc|web)_[a-z0-9\_]+$');

String didToKey(String did, [bool full = true]) {
  String val;
  if (did.startsWith('did:plc:')) {
    val = 'plc_${did.substring(8)}';
  } else if (did.startsWith('did:web:')) {
    val = 'web_${did.substring(8).replaceAll('.', '_').replaceAll('-', '__')}';
  } else {
    throw 'Invalid DID $did';
  }

  if (!validDidKeyRegex.hasMatch(val)) {
    throw 'Found invalid DID: $did $full $val';
  }

  if (full) {
    return 'did:$val';
  } else {
    return val;
  }
}
