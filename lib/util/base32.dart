
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart' hide base32Rfc;

final base32 = Base32Codec();

class Base32Codec {
  static const String _alphabet = "abcdefghijklmnopqrstuvwxyz234567";
  static const int bitsPerChar = 5;

  const Base32Codec();

  String encode(Uint8List data) {
    final mask = BigInt.from((1 << bitsPerChar) - 1);
    String out = '';

    int bits = 0;
    var buffer = BigInt.zero;

    for (int i = 0; i < data.length; i++) {
      buffer = (buffer << 8) | BigInt.from(data[i]);
      bits += 8;

      while (bits > bitsPerChar) {
        bits -= bitsPerChar;
        out += _alphabet[(mask & (buffer >> bits)).toInt()];
      }
    }

    if (bits != 0) {
      out += _alphabet[(mask & (buffer << (bitsPerChar - bits))).toInt()];
    }

    return out;
  }

  Uint8List decode(String string) => (const Base32Decoder(
        _alphabet,
        '',
        caseInsensitive: false,
      )).convert(string);

}