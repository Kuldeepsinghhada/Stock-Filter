import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

class KiteWebSocket {
  final String apiKey;
  final String accessToken;
  IOWebSocketChannel? _channel;

  KiteWebSocket({required this.apiKey, required this.accessToken});

  void connect() {
    final wsUrl =
        'wss://ws.kite.trade?api_key=$apiKey&access_token=$accessToken';
    _channel = IOWebSocketChannel.connect(wsUrl);

    _channel!.stream.listen(
      (message) {
        _handleMessage(message);
      },
      onDone: () {
        print("WebSocket closed");
        // Optionally reconnect
      },
      onError: (error) {
        print("WebSocket error: $error");
        // Optionally reconnect
      },
    );
  }

  void subscribe(List<int> tokens) {
    if (_channel == null) return;

    final request = {"a": "subscribe", "v": tokens};

    _channel!.sink.add(jsonEncode(request));
  }

  void unsubscribe(List<int> tokens) {
    if (_channel == null) return;

    final request = {"a": "unsubscribe", "v": tokens};

    _channel!.sink.add(jsonEncode(request));
  }

  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        try {
          final data = jsonDecode(message);
          print("Received JSON: $data");
        } catch (e) {
          print("Received non-JSON string: $message");
        }
      } else if (message is Uint8List) {
        print("Received binary message, length: ${message.length}");
        int offset = 0;
        while (offset < message.length) {
          if (message.length - offset < 2) break;
          final packetLen = (message[offset] << 8) | message[offset + 1];
          offset += 2;
          if (message.length - offset < packetLen) break;
          final packet = message.sublist(offset, offset + packetLen);
          offset += packetLen;
          // Handle tick packets of length 44 (LTP), 48 (quote), 60+ (full)
          if (packet.length == 44 || packet.length == 48 || packet.length >= 60) {
            try {
              final tickJson = parseKiteTickToJson(Uint8List.fromList(packet));
              print("Parsed Tick JSON: $tickJson");
            } catch (e) {
              print("Failed to parse tick from binary: $packet, error: $e");
            }
          } else if (packet.length == 1) {
            print("Heartbeat packet: $packet");
          } else {
            print("Unknown packet length: ${packet.length}, data: $packet");
          }
        }
      } else {
        print("Unknown message type: $message");
      }
    } catch (e) {
      print("General message parse error: $message, error: $e");
    }
  }

  Map<String, dynamic> parseKiteTickToJson(Uint8List data) {
    final byteData = ByteData.sublistView(data);
    int offset = 0;
    final instrumentToken = byteData.getInt32(offset, Endian.big);
    offset += 4;
    final segment = byteData.getUint8(offset);
    offset += 1;
    final length = byteData.getUint8(offset);
    offset += 1;
    final lastPrice = byteData.getInt32(offset, Endian.big) / 100;
    offset += 4;
    final lastTradedQty = byteData.getInt32(offset, Endian.big);
    offset += 4;
    final avgTradedPrice = byteData.getInt32(offset, Endian.big) / 100;
    offset += 4;
    final volumeTraded = byteData.getInt32(offset, Endian.big);
    offset += 4;
    final totalBuyQty = byteData.getInt32(offset, Endian.big);
    offset += 4;
    final totalSellQty = byteData.getInt32(offset, Endian.big);
    offset += 4;
    final open = byteData.getInt32(offset, Endian.big) / 100;
    offset += 4;
    final high = byteData.getInt32(offset, Endian.big) / 100;
    offset += 4;
    final low = byteData.getInt32(offset, Endian.big) / 100;
    offset += 4;
    final close = byteData.getInt32(offset, Endian.big) / 100;
    offset += 4;
    final timestamp = byteData.getInt64(offset, Endian.big);
    offset += 8;
    // You can parse more fields if needed (e.g., OI, depth, etc.)
    return {
      'instrument_token': instrumentToken,
      'segment': segment,
      'length': length,
      'last_price': lastPrice,
      'last_traded_quantity': lastTradedQty,
      'average_traded_price': avgTradedPrice,
      'volume_traded': volumeTraded,
      'total_buy_quantity': totalBuyQty,
      'total_sell_quantity': totalSellQty,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'timestamp': timestamp,
    };
  }

  void disconnect() {
    _channel?.sink.close(status.goingAway);
  }
}
