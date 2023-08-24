import 'dart:typed_data';
import 'package:cbor/simple.dart' as simple;
import 'package:lib5/lib5.dart';

const cidV1BytesLength = 36;

Map<Multihash, Map> parseCARFile(Uint8List bytes) {
  final (headerLength, length) = decodeReader(bytes, 0);

  final headerBytes = bytes.sublist(length, length + headerLength);

  final header = simple.cbor.decode(headerBytes) as Map;
  final rootCID = Multihash(Uint8List.fromList(header['roots'][0]).sublist(1));

  final blocks = <Multihash, Map>{};

  int cursor = length + headerLength;

  while (true) {
    if (cursor >= bytes.length) break;
    final (blockLength, length) = decodeReader(bytes, cursor);
    cursor += length;

    final cid = Multihash(bytes.sublist(cursor, cursor + cidV1BytesLength));

    cursor += cidV1BytesLength;
    try {
      final data = simple.cbor.decode(
              bytes.sublist(cursor, cursor + blockLength - cidV1BytesLength))
          as Map;
      cursor += blockLength - cidV1BytesLength;

      blocks[cid] = data;
    } catch (e, st) {
      // TODO Handle error properly (retr0id case)
      print(e);
      print(st);
    }
  }

  return blocks;
}

// returns (number, number of bytes read)
(int, int) decodeReader(Uint8List bytes, int offset) {
  final a = <int>[];
  int i = 0;
  while (true) {
    final b = bytes[offset + i];
    i++;
    a.add(b);
    if ((b & 0x80) == 0) {
      break;
    }
  }
  return (decode(a), a.length);
}

// decode unsigned leb128
int decode(List<int> b) {
  int r = 0;
  for (int i = 0; i < b.length; i++) {
    int e = b[i];
    r = r + ((e & 0x7F) << (i * 7));
  }
  return r;
}
