/*
 * Package : mqtt_client
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 15/06/2017
 * Copyright :  S.Hamblett
 */

part of mqtt_client;

// ignore_for_file: unnecessary_final
// ignore_for_file: omit_local_variable_types
// ignore_for_file: cascade_invocations

/// Message that indicates a connection acknowledgement.
class MqttConnectAckMessage extends MqttMessage {
  /// Initializes a new instance of the MqttConnectAckMessage class.
  /// Only called via the MqttMessage.Create operation during processing
  /// of an Mqtt message stream.
  MqttConnectAckMessage() {
    header = MqttHeader().asType(MqttMessageType.connectAck);
    variableHeader = MqttConnectAckVariableHeader();
    variableHeader.returnCode = MqttConnectReturnCode.connectionAccepted;
  }

  /// Initializes a new instance of the MqttConnectAckMessage class.
  MqttConnectAckMessage.fromByteBuffer(
      MqttHeader header, MqttByteBuffer messageStream) {
    this.header = header;
    readFrom(messageStream);
  }

  /// Gets or sets the variable header contents. Contains extended
  /// metadata about the message
  late MqttConnectAckVariableHeader variableHeader;

  /// Reads a message from the supplied stream.
  @override
  void readFrom(MqttByteBuffer messageStream) {
    super.readFrom(messageStream);
    variableHeader = MqttConnectAckVariableHeader.fromByteBuffer(messageStream);
  }

  /// Writes a message to the supplied stream.
  @override
  void writeTo(MqttByteBuffer messageStream) {
    header!.writeTo(variableHeader.getWriteLength(), messageStream);
    variableHeader.writeTo(messageStream);
  }

  /// Sets the return code of the Variable Header.
  // ignore: avoid_returning_this
  MqttConnectAckMessage withReturnCode(MqttConnectReturnCode returnCode) {
    variableHeader.returnCode = returnCode;
    return this;
  }

  @override
  String toString() {
    final StringBuffer sb = StringBuffer();
    sb.write(super.toString());
    sb.writeln(variableHeader.toString());
    return sb.toString();
  }
}
