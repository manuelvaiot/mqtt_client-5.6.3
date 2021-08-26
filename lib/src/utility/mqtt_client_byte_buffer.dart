/*
 * Package : mqtt_client
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 31/05/2017
 * Copyright :  S.Hamblett
 */

part of mqtt_client;

// ignore_for_file: cascade_invocations
// ignore_for_file: unnecessary_final
// ignore_for_file: omit_local_variable_types

/// Utility class to allow stream like access to a sized byte buffer.
/// This class is in effect a cut-down implementation of the C# NET
/// System.IO class with Mqtt client specific extensions.
class MqttByteBuffer {
  /// The byte buffer
  MqttByteBuffer(this.buffer);

  /// From a list
  MqttByteBuffer.fromList(List<int> data) {
    buffer = typed.Uint8Buffer();
    buffer!.addAll(data);
  }

  /// The current position within the buffer.
  int _position = 0;

  /// The underlying byte buffer
  typed.Uint8Buffer? buffer;

  /// Position
  int get position => _position;

  /// Length
  int get length => buffer!.length;

  /// Available bytes
  int get availableBytes => length - _position;

  /// Resets the position to 0
  void reset() {
    _position = 0;
  }

  /// Skip bytes
  // ignore: avoid_setters_without_getters
  set skipBytes(int bytes) => _position += bytes;

  /// Add a list
  void addAll(List<int> data) {
    buffer!.addAll(data);
  }

  /// Shrink the buffer
  void shrink() {
    buffer!.removeRange(0, _position);
    _position = 0;
  }

  /// Message available
  bool isMessageAvailable() {
    if (availableBytes > 0) {
      return true;
    }

    return false;
  }

  /// Reads a byte from the buffer and advances the position
  /// within the buffer by one byte, or returns -1 if at the end of the buffer.
  int readByte() {
    final int tmp = buffer![_position];
    if (_position <= (length - 1)) {
      _position++;
    } else {
      return -1;
    }
    return tmp;
  }

  /// Read a short int(16 bits)
  int readShort() {
    final int high = readByte();
    final int low = readByte();
    return (high << 8) + low;
  }

  /// Reads a sequence of bytes from the current
  /// buffer and advances the position within the buffer
  /// by the number of bytes read.
  typed.Uint8Buffer read(int count) {
    if ((length < count) || (_position + count) > length) {
      throw Exception('mqtt_client::ByteBuffer: The buffer did not have '
          'enough bytes for the read operation '
          'length $length, count $count, position $_position, buffer $buffer');
    }
    final typed.Uint8Buffer tmp = typed.Uint8Buffer();
    tmp.addAll(buffer!.getRange(_position, _position + count));
    _position += count;
    final typed.Uint8Buffer tmp2 = typed.Uint8Buffer();
    tmp2.addAll(tmp);
    return tmp2;
  }

  /// Writes a byte to the current position in the buffer
  /// and advances the position within the buffer by one byte.
  void writeByte(int byte) {
    if (buffer!.length == _position) {
      buffer!.add(byte);
    } else {
      buffer![_position] = byte;
    }
    _position++;
  }

  /// Write a short(16 bit)
  void writeShort(int short) {
    writeByte(short >> 8);
    writeByte(short & 0xFF);
  }

  /// Writes a sequence of bytes to the current
  /// buffer and advances the position within the buffer by the number of
  /// bytes written.
  void write(typed.Uint8Buffer? buffer) {
    if (this.buffer == null) {
      this.buffer = buffer;
    } else {
      this.buffer!.addAll(buffer!);
    }
    _position = length;
  }

  /// Seek. Sets the position in the buffer. If overflow occurs
  /// the position is set to the end of the buffer.
  void seek(int seek) {
    if ((seek <= length) && (seek >= 0)) {
      _position = seek;
    } else {
      _position = length;
    }
  }

  /// Writes an MQTT string member
  void writeMqttStringM(String stringToWrite) {
    writeMqttString(this, stringToWrite);
  }

  /// Writes an MQTT string.
  /// stringStream - The stream containing the string to write.
  /// stringToWrite - The string to write.
  static void writeMqttString(
      MqttByteBuffer stringStream, String stringToWrite) {
    final MqttEncoding enc = MqttEncoding();
    final typed.Uint8Buffer stringBytes = enc.getBytes(stringToWrite);
    stringStream.write(stringBytes);
  }

  /// Reads an MQTT string from the underlying stream member
  String readMqttStringM() => MqttByteBuffer.readMqttString(this);

  /// Reads an MQTT string from the underlying stream.
  static String readMqttString(MqttByteBuffer buffer) {
    // Read and check the length
    final typed.Uint8Buffer lengthBytes = buffer.read(2);
    final MqttEncoding enc = MqttEncoding();
    final int stringLength = enc.getCharCount(lengthBytes);
    final typed.Uint8Buffer stringBuff = buffer.read(stringLength);
    return enc.getString(stringBuff);
  }

  @override
  String toString() {
    if (buffer != null && buffer!.isNotEmpty) {
      return 'null or empty';
    } else {
      return buffer!.toList().toString();
    }
  }
}
