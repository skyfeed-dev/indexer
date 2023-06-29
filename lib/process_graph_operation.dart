import 'dart:typed_data';

import 'package:atproto/atproto.dart';
import 'package:indexer/surrealdb.dart';
import 'package:lib5/lib5.dart';

import 'logger.dart';

final hashtagRegex = RegExp(r'( |\n)#([a-zA-Z0-9\-]{2,100})');

Future<void> processGraphOperation(
  String repo,
  String action,
  String recordType,
  String rkey,
  Map<String, dynamic>? block, {
  required Surreal surreal,
}) async {
  try {
    if (action == 'create' || action == 'update') {
      block!;
      ensureValidRKey(rkey);
      if (recordType == 'app.bsky.actor.profile') {
        surreal.db.change(didToKey(repo), {
          'avatar': prepareBlob(surreal, block['avatar']),
          'banner': prepareBlob(surreal, block['banner']),
          'displayName': block['displayName'],
          'description': block['description'],
        });
      } else if (recordType == 'app.bsky.feed.generator') {
        final id = 'feed:`${didToKey(repo, false)}_$rkey`';

        final uri = 'at://$repo/app.bsky.feed.generator/$rkey';

        final vars = {
          'uri': uri,
          'author': didToKey(repo),
          'did': block['did'] as String,
          'displayName': block['displayName'],
          'description': block['description'],
          'rkey': rkey,
          'createdAt': getCreatedAt(block),
          'avatar': prepareBlob(surreal, block['avatar']),
        };

        surreal.db.update(id, vars);
      } else if (recordType == 'app.bsky.feed.post') {
        final id = 'post:${didToKey(repo, false)}_$rkey';

        final post = <String, dynamic>{
          'author': didToKey(repo),
          'text': block['text'],
          'createdAt': getCreatedAt(block),
        };

        for (final match
            in hashtagRegex.allMatches(' ${block['text']} '.toLowerCase())) {
          final hashtag = match.group(2)!.toLowerCase();

          surreal.db.query(
            "RELATE hashtag:`$hashtag`->usedin->$id CONTENT { createdAt: '${getCreatedAt(post)}', id: '${didToKey(repo, false)}_${rkey}_$hashtag' };",
          );
        }

        block.remove('text');
        block.remove('\$type');
        block.remove('createdAt');

        if (block['reply'] != null) {
          post['parent'] = atUriToPostId(block['reply']['parent']['uri']);
          post['root'] = atUriToPostId(block['reply']['root']['uri']);
          block.remove('reply');
        }

        if (block['langs'] != null) {
          post['langs'] = block['langs'];
          block.remove('langs');
        }

        if (block['embed'] != null) {
          if (block['embed']['images'] != null ||
              block['embed']['media']?['images'] != null) {
            post['images'] ??= [];
            for (final image in (block['embed']?['images'] ??
                block['embed']['media']['images'])) {
              final blob = prepareBlob(surreal, image['image']);

              post['images'].add({
                'alt': image['alt'],
                'blob': blob,
              });
            }
            block['embed'].remove('images');
            block['embed'].remove('media');
            block['embed'].remove('\$type');
          }
          if (block['embed']['record'] != null) {
            post['record'] = atUriToPostOrFeedId(block['embed']['record']
                    ?['uri'] ??
                block['embed']['record']['record']['uri']);

            block['embed'].remove('record');
            block['embed'].remove('\$type');
          }

          if (block['embed']['external'] != null ||
              block['embed']['media']?['external'] != null) {
            final link = block['embed']['external']?['uri'] ??
                block['embed']['media']['external']['uri'];

            addLinkSafe(post, prepareLink(surreal, link));

            block['embed'].remove('external');
            block['embed'].remove('\$type');
          }

          if (block['embed'].isEmpty) {
            block.remove('embed');
          }
        }
        if (block['facets'] != null) {
          for (final facet in block['facets']) {
            for (final feature in facet['features']) {
              if (feature['\$type'] == 'app.bsky.richtext.facet#mention') {
                post['mentions'] ??= [];
                post['mentions'].add(didToKey(feature['did']));
              } else if (feature['\$type'] == 'app.bsky.richtext.facet#link') {
                addLinkSafe(post, prepareLink(surreal, feature['uri']));
              } else {
                throw feature;
              }
            }
          }
          block.remove('facets');
        }
        if (block['entities'] != null) {
          for (final entity in block['entities']) {
            if (entity['type'] == 'link') {
              addLinkSafe(post, prepareLink(surreal, entity['value']));
            } else if (entity['type'] == 'mention') {
              if (entity['value'].startsWith('did:')) {
                post['mentions'] ??= [];
                post['mentions'].add(didToKey(entity['value']));
              } else {
                continue;
              }
            } else {
              throw block;
            }
          }
          block.remove('entities');
        }
        if (block.isNotEmpty) {
          logger.d('skipped unknown fields for $id: $block');
        }
        // TODO Create graph relations for mentions
        surreal.db.update(id, post);

        if (post.containsKey('parent')) {
          surreal.db.query(
            "RELATE ${didToKey(repo)}->replies->$id CONTENT { createdAt: '${getCreatedAt(post)}', id: '${didToKey(repo, false)}_$rkey' };",
          );
        } else {
          surreal.db.query(
            "RELATE ${didToKey(repo)}->posts->$id CONTENT { createdAt: '${getCreatedAt(post)}', id: '${didToKey(repo, false)}_$rkey' };",
          );
        }
      } else if (recordType == 'app.bsky.graph.follow') {
        final subjectDID = block['subject'];

        surreal.db.query(
          "RELATE ${didToKey(repo)}->follow->${didToKey(subjectDID)} CONTENT { createdAt: '${getCreatedAt(block)}', id: '${didToKey(repo, false)}_$rkey' };",
        );
      } else if (recordType == 'app.bsky.graph.block') {
        final subjectDID = block['subject'];

        surreal.db.query(
          "RELATE ${didToKey(repo)}->block->${didToKey(subjectDID)} CONTENT { createdAt: '${getCreatedAt(block)}', id: '${didToKey(repo, false)}_$rkey' };",
        );
      } else if (recordType == 'app.bsky.feed.like') {
        final String subjectUri = block['subject']['uri'];

        surreal.db.query(
          "RELATE ${didToKey(repo)}->like->${atUriToPostOrFeedId(subjectUri)} CONTENT { createdAt: '${getCreatedAt(block)}', id: '${didToKey(repo, false)}_$rkey' };",
        );
      } else if (recordType == 'app.bsky.feed.repost') {
        final subjectUri = block['subject']['uri'];

        surreal.db.query(
          "RELATE ${didToKey(repo)}->repost->${atUriToPostId(subjectUri)} CONTENT { createdAt: '${getCreatedAt(block)}', id: '${didToKey(repo, false)}_$rkey' };",
        );
      } else if (recordType == 'app.bsky.graph.listitem') {
        final subjectDID = block['subject'];

        surreal.db.query(
          "RELATE ${atUriToListId(block['list'])}->listitem->${didToKey(subjectDID)} CONTENT { createdAt: '${getCreatedAt(block)}', id: '${didToKey(repo, false)}_$rkey' };",
        );
      } else {
        logger.w('could not process $repo $action $recordType $rkey');
      }
    } else if (action == 'delete') {
      ensureValidRKey(rkey);

      if (recordType == 'app.bsky.graph.follow') {
        surreal.db.query(
          "DELETE follow:${didToKey(repo, false)}_$rkey;",
        );
      } else if (recordType == 'app.bsky.feed.repost') {
        surreal.db.query(
          "DELETE repost:${didToKey(repo, false)}_$rkey;",
        );
      } else if (recordType == 'app.bsky.feed.like') {
        surreal.db.query(
          "DELETE like:${didToKey(repo, false)}_$rkey;",
        );
      } else if (recordType == 'app.bsky.graph.block') {
        surreal.db.query(
          "DELETE block:${didToKey(repo, false)}_$rkey;",
        );
      } else if (recordType == 'app.bsky.feed.post') {
        surreal.db.query(
          "DELETE post:${didToKey(repo, false)}_$rkey;",
        );
        surreal.db.query(
          "DELETE posts:${didToKey(repo, false)}_$rkey;",
        );
        surreal.db.query(
          "DELETE replies:${didToKey(repo, false)}_$rkey;",
        );
      } else if (recordType == 'app.bsky.feed.listitem') {
        surreal.db.query(
          "DELETE listitem:${didToKey(repo, false)}_$rkey;",
        );
      } else if (recordType == 'app.bsky.feed.post') {
        surreal.db.query(
          "DELETE post:${didToKey(repo, false)}_$rkey;",
        );
      } else if (recordType == 'app.bsky.feed.generator') {
        surreal.db.query(
          "DELETE feed:`${didToKey(repo, false)}_$rkey`;",
        );
      } else {
        logger.w('could not handle operation $repo $action $recordType $rkey');
      }
    } else {
      throw 'Unknown action $action $repo $rkey';
    }
  } catch (e, st) {
    logger.e('Failed to process operation', e, st);
  }
}

String getCreatedAt(Map record) {
  final dtStr = record['createdAt'];
  final dt = DateTime.parse(dtStr);
  if (dt.isAfter(DateTime.now().toUtc().add(Duration(seconds: 60)))) {
    final newStr = DateTime.now().toUtc().toIso8601String();
    logger.v('overriding timestamp $dtStr -> $newStr');
    return newStr;
  }
  return dtStr;
}

void addLinkSafe(Map post, String? link) {
  if (link == null) return;
  post['links'] ??= [];
  if (!post['links'].contains(link)) {
    post['links'].add(link);
  }
}

final rkeyRegex = RegExp(r'^[a-z0-9\-]+$');

void ensureValidRKey(String rkey) {
  if (!rkeyRegex.hasMatch(rkey)) {
    throw 'Invalid rkey $rkey';
  }
}

String atUriToPostId(String uri) {
  final u = AtUri.parse(uri);
  if (u.collection != 'app.bsky.feed.post') throw 'Not a post $uri';

  String did = didToKey(u.hostname, false);
  if (did.startsWith('plc_did:plc:')) {
    did = 'plc_${did.substring(12)}';
  }
  ensureValidRKey(u.rkey);
  return 'post:${did}_${u.rkey}';
}

String atUriToPostOrFeedId(String uri) {
  final u = AtUri.parse(uri);
  if (u.collection == 'app.bsky.feed.post') {
    return atUriToPostId(uri);
  }
  if (u.collection != 'app.bsky.feed.generator') throw 'Not a feed $uri';
  ensureValidRKey(u.rkey);
  return 'feed:`${didToKey(u.hostname, false)}_${u.rkey}`';
}

String atUriToListId(String uri) {
  final u = AtUri.parse(uri);
  if (u.collection != 'app.bsky.graph.list') throw 'Not a list $uri';
  ensureValidRKey(u.rkey);
  return 'list:${didToKey(u.hostname, false)}_${u.rkey}';
}

final cidRegex = RegExp(r'^[a-z0-9]+$');

String? prepareBlob(Surreal surreal, Map? blob) {
  if (blob == null) {
    return null;
  }
  String cid;
  if (blob['cid'] is String) {
    cid = blob['cid'];
  } else if (blob['ref'] is List) {
    final List<int> ref = blob['ref'];

    if (ref[0] == 0) {
      ref.removeAt(0);
    }
    cid = 'b${Multihash(Uint8List.fromList(ref)).toBase32()}';
  } else {
    if (blob['ref'] == null) return null;
    cid = blob['ref']['\$link'];
  }
  if (!cidRegex.hasMatch(cid)) {
    throw 'Invalid CID $cid in blob $blob';
  }
  final mimeType = (blob['mimeType'] as String).split('/');

  surreal.db.update('blob:$cid', {
    'mediaType': mimeType[0],
    'mediaSubtype': mimeType[1],
    'size': blob['size'],
  });

  return 'blob:$cid';
}

String? prepareLink(Surreal surreal, String link) {
  final uri = Uri.parse(link);
  if (link.contains('`')) {
    throw 'Invalid link $link';
  }
  final id = '`$link`';

  surreal.db.update('link:$id', {
    'scheme': uri.scheme,
    'authority': uri.authority,
    'path': uri.path,
    'query': uri.query,
    'fragment': uri.fragment,
  });

  return 'link:$id';
}
