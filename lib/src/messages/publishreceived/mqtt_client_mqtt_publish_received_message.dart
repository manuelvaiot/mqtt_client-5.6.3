/*
 * Package : mqtt_client
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 19/06/2017
 * Copyright :  S.Hamblett
 */

part of mqtt_client;

// ignore_for_file: unnecessary_final
// ignore_for_file: omit_local_variable_types
// ignore_for_file: cascade_invocations

/// Implementation of an MQTT Publish Received Message.
class MqttPublishReceivedMessage extends MqttMessage {
  /// Initializes a new instance of the MqttPublishReceivedMessage class.
  MqttPublishReceivedMessage() {
    header = MqttHeader().asType(MqttMessageType.publishReceived);
    variableHeader = MqttPublishReceivedVariableHeader();
  }

  /// Initializes a new instance of the MqttPublishReceivedMessage class.
  MqttPublishReceivedMessage.fromByteBuffer(
      MqttHeader header, MqttByteBuffer messageStream) {
    this.header = header;
    variableHeader =
        MqttPublishReceivedVariableHeader.fromByteBuffer(messageStream);
  }

  /// Gets or sets the variable header contents. Contains extended
  /// metadata about the message.
  late MqttPublishReceivedVariableHeader variableHeader;

  /// Writes the message to the supplied stream.
  @override
  void writeTo(MqttByteBuffer messageStream) {
    header!.writeTo(variableHeader.getWriteLength(), messageStream);
    variableHeader.writeTo(messageStream);
  }

  /// Sets the message identifier of the MqttMessage.
  // ignore: avoid_returning_this
  MqttPublishReceivedMessage withMessageIdentifier(int? messageIdentifier) {
    variableHeader.messageIdentifier = messageIdentifier;
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
