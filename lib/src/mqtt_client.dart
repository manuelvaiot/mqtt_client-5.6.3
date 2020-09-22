/*
 * Package : mqtt_client
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 10/07/2017
 * Copyright :  S.Hamblett
 */

part of mqtt_client;

// ignore_for_file: avoid_types_on_closure_parameters
// ignore_for_file: cascade_invocations
// ignore_for_file: unnecessary_final
// ignore_for_file: omit_local_variable_types
// ignore_for_file: avoid_returning_this

/// The client disconnect callback type
typedef DisconnectCallback = void Function();

/// The client Connect callback type
typedef ConnectCallback = void Function();

/// A client class for interacting with MQTT Data Packets
class MqttClient {
  /// Initializes a new instance of the MqttClient class using the
  /// default Mqtt Port.
  /// The server hostname to connect to
  /// The client identifier to use to connect with
  MqttClient(this.server, this.clientIdentifier) {
    port = Constants.defaultMqttPort;
  }

  /// Initializes a new instance of the MqttClient class using
  /// the supplied Mqtt Port.
  /// The server hostname to connect to
  /// The client identifier to use to connect with
  /// The port to use
  MqttClient.withPort(this.server, this.clientIdentifier, this.port);

  /// Server name
  String server;

  /// Port number
  int port;

  /// Client identifier
  String clientIdentifier;

  /// If set use a websocket connection, otherwise use the default TCP one
  bool useWebSocket = false;

  /// If set use the alternate websocket implementation
  bool useAlternateWebSocketImplementation = false;

  List<String> _websocketProtocols;

  /// User definable websocket protocols. Use this for non default websocket
  /// protocols only if your broker needs this. There are two defaults in
  /// MqttWsConnection class, the multiple protocol is the default. Some brokers
  /// will not accept a list and only expect a single protocol identifier,
  /// in this case use the single protocol default. You can supply your own
  /// list, or to disable this entirely set the protocols to an
  /// empty list , i.e [].
  // ignore: avoid_setters_without_getters
  set websocketProtocols(List<String> protocols) {
    _websocketProtocols = protocols;
    if (_connectionHandler != null) {
      _connectionHandler.websocketProtocols = protocols;
    }
  }

  /// If set use a secure connection, note TCP only, do not use for
  /// secure websockets(wss).
  bool secure = false;

  /// The security context for secure usage
  SecurityContext securityContext = SecurityContext.defaultContext;

  /// Callback function to handle bad certificate. if true, ignore the error.
  bool Function(X509Certificate certificate) onBadCertificate;

  /// The Handler that is managing the connection to the remote server.
  MqttConnectionHandler _connectionHandler;

  /// The subscriptions manager responsible for tracking subscriptions.
  SubscriptionsManager _subscriptionsManager;

  /// Handles the connection management while idle.
  MqttConnectionKeepAlive _keepAlive;

  /// Keep alive period, seconds
  int keepAlivePeriod = Constants.defaultKeepAlive;

  /// Handles everything to do with publication management.
  PublishingManager _publishingManager;

  /// Published message stream. A publish message is added to this
  /// stream on completion of the message publishing protocol for a Qos level.
  /// Attach listeners only after connect has been called.
  Stream<MqttPublishMessage> get published =>
      // ignore: prefer_null_aware_operators
      _publishingManager != null ? _publishingManager.published.stream : null;

  /// Gets the current connection state of the Mqtt Client.
  /// Will be removed, use connectionStatus
  @Deprecated('Use ConnectionStatus, not this')
  MqttConnectionState get connectionState => _connectionHandler != null
      ? _connectionHandler.connectionStatus.state
      : MqttConnectionState.disconnected;

  final MqttClientConnectionStatus _connectionStatus =
      MqttClientConnectionStatus();

  /// Gets the current connection status of the Mqtt Client.
  /// This is the connection state as above also with the broker return code.
  /// Set after every connection attempt.
  MqttClientConnectionStatus get connectionStatus => _connectionHandler != null
      ? _connectionHandler.connectionStatus
      : _connectionStatus;

  /// The connection message to use to override the default
  MqttConnectMessage connectionMessage;

  /// Client disconnect callback, called on unsolicited disconnect.
  DisconnectCallback onDisconnected;

  /// Client connect callback, called on successful connect
  ConnectCallback onConnected;

  /// Subscribed callback, function returns a void and takes a
  /// string parameter, the topic that has been subscribed to.
  SubscribeCallback _onSubscribed;

  /// On subscribed
  SubscribeCallback get onSubscribed => _onSubscribed;

  set onSubscribed(SubscribeCallback cb) {
    _onSubscribed = cb;
    _subscriptionsManager?.onSubscribed = cb;
  }

  /// Subscribed failed callback, function returns a void and takes a
  /// string parameter, the topic that has failed subscription.
  /// Invoked either by subscribe if an invalid topic is supplied or on
  /// reception of a failed subscribe indication from the broker.
  SubscribeFailCallback _onSubscribeFail;

  /// On subscribed fail
  SubscribeFailCallback get onSubscribeFail => _onSubscribeFail;

  set onSubscribeFail(SubscribeFailCallback cb) {
    _onSubscribeFail = cb;
    _subscriptionsManager?.onSubscribeFail = cb;
  }

  /// Unsubscribed callback, function returns a void and takes a
  /// string parameter, the topic that has been unsubscribed.
  UnsubscribeCallback _onUnsubscribed;

  /// On unsubscribed
  UnsubscribeCallback get onUnsubscribed => _onUnsubscribed;

  set onUnsubscribed(UnsubscribeCallback cb) {
    _onUnsubscribed = cb;
    _subscriptionsManager?.onUnsubscribed = cb;
  }

  /// Ping response received callback.
  /// If set when a ping response is received from the broker
  /// this will be called.
  /// Can be used for health monitoring outside of the client itself.
  PongCallback _pongCallback;

  /// The ping received callback
  PongCallback get pongCallback => _pongCallback;

  set pongCallback(PongCallback cb) {
    _pongCallback = cb;
    _keepAlive?.pongCallback = cb;
  }

  /// The event bus
  events.EventBus _clientEventBus;

  /// The stream on which all subscribed topic updates are published to
  Stream<List<MqttReceivedMessage<MqttMessage>>> updates;

  /// Performs a connect to the message broker with an optional
  /// username and password for the purposes of authentication.
  /// If a username and password are supplied these will override
  /// any previously set in a supplied connection message so if you
  /// supply your own connection message and use the authenticateAs method to
  /// set these parameters do not set them again here.
  Future<MqttClientConnectionStatus> connect(
      [String username, String password]) async {
    if (username != null) {
      MqttLogger.log("Authenticating with username '{$username}' "
          "and password '{$password}'");
      if (username.trim().length >
          Constants.recommendedMaxUsernamePasswordLength) {
        MqttLogger.log('Username length (${username.trim().length}) '
            'exceeds the max recommended in the MQTT spec. ');
      }
    }
    if (password != null &&
        password.trim().length >
            Constants.recommendedMaxUsernamePasswordLength) {
      MqttLogger.log('Password length (${password.trim().length}) '
          'exceeds the max recommended in the MQTT spec. ');
    }
    // Set the authentication parameters in the connection
    // message if we have one.
    connectionMessage?.authenticateAs(username, password);

    // Do the connection
    _clientEventBus = events.EventBus();
    _connectionHandler = SynchronousMqttConnectionHandler(_clientEventBus);
    if (useWebSocket) {
      _connectionHandler.secure = false;
      _connectionHandler.useWebSocket = true;
      _connectionHandler.useAlternateWebSocketImplementation =
          useAlternateWebSocketImplementation;
      if (_websocketProtocols != null) {
        _connectionHandler.websocketProtocols = _websocketProtocols;
      }
    }
    if (secure) {
      _connectionHandler.secure = true;
      _connectionHandler.useWebSocket = false;
      _connectionHandler.useAlternateWebSocketImplementation = false;
      _connectionHandler.securityContext = securityContext;
      _connectionHandler.onBadCertificate = onBadCertificate;
    }
    _connectionHandler.onDisconnected = _internalDisconnect;
    _connectionHandler.onConnected = onConnected;
    _publishingManager = PublishingManager(_connectionHandler, _clientEventBus);
    _subscriptionsManager = SubscriptionsManager(
        _connectionHandler, _publishingManager, _clientEventBus);
    _subscriptionsManager.onSubscribed = onSubscribed;
    _subscriptionsManager.onUnsubscribed = onUnsubscribed;
    _subscriptionsManager.onSubscribeFail = onSubscribeFail;
    updates = _subscriptionsManager.subscriptionNotifier.changes;
    _keepAlive = MqttConnectionKeepAlive(_connectionHandler, keepAlivePeriod);
    if (pongCallback != null) {
      _keepAlive.pongCallback = pongCallback;
    }
    final MqttConnectMessage connectMessage =
        _getConnectMessage(username, password);
    return _connectionHandler.connect(server, port, connectMessage);
  }

  ///  Gets a pre-configured connect message if one has not been
  ///  supplied by the user.
  ///  Returns an MqttConnectMessage that can be used to connect to a
  ///  message broker.
  MqttConnectMessage _getConnectMessage(String username, String password) =>
      connectionMessage ??= MqttConnectMessage()
          .withClientIdentifier(clientIdentifier)
          // Explicitly set the will flag
          .withWillQos(MqttQos.atMostOnce)
          .keepAliveFor(Constants.defaultKeepAlive)
          .authenticateAs(username, password)
          .startClean();

  /// Initiates a topic subscription request to the connected broker
  /// with a strongly typed data processor callback.
  /// The topic to subscribe to.
  /// The qos level the message was published at.
  /// Returns the subscription or null on failure
  Subscription subscribe(String topic, MqttQos qosLevel) {
    if (connectionStatus.state != MqttConnectionState.connected) {
      throw ConnectionException(_connectionHandler?.connectionStatus?.state);
    }
    return _subscriptionsManager.registerSubscription(topic, qosLevel);
  }

  /// Publishes a message to the message broker.
  /// Returns The message identifer assigned to the message.
  /// Raises InvalidTopicException if the topic supplied violates the
  /// MQTT topic format rules.
  int publishMessage(
      String topic, MqttQos qualityOfService, typed.Uint8Buffer data,
      {bool retain = false}) {
    if (_connectionHandler?.connectionStatus?.state !=
        MqttConnectionState.connected) {
      throw ConnectionException(_connectionHandler?.connectionStatus?.state);
    }
    try {
      final PublicationTopic pubTopic = PublicationTopic(topic);
      return _publishingManager.publish(
          pubTopic, qualityOfService, data, retain);
    } on Exception catch (e) {
      throw InvalidTopicException(e.toString(), topic);
    }
  }

  /// Unsubscribe from a topic
  void unsubscribe(String topic) {
    _subscriptionsManager.unsubscribe(topic);
  }

  /// Gets the current status of a subscription.
  MqttSubscriptionStatus getSubscriptionsStatus(String topic) =>
      _subscriptionsManager.getSubscriptionsStatus(topic);

  /// Disconnect from the broker.
  /// This is a hard disconnect, a disconnect message is sent to the
  /// broker and the client is then reset to its pre-connection state,
  /// i.e all subscriptions are deleted, on subsequent reconnection the
  /// use must re-subscribe, also the updates change notifier is re-initialised
  /// and as such the user must re-listen on this stream.
  ///
  /// Do NOT call this in any onDisconnect callback that may be set,
  /// this will result in a loop situation.
  void disconnect() {
    _disconnect(unsolicited: false);
  }

  /// Internal disconnect
  /// This is always passed to the connection handler to allow the
  /// client to close itself down correctly on disconnect.
  void _internalDisconnect() {
    // Only call disconnect if we are connected, i.e. a connection to
    // the broker has been previously established.
    if (connectionStatus.state == MqttConnectionState.connected) {
      _disconnect(unsolicited: true);
    }
  }

  /// Actual disconnect processing
  void _disconnect({bool unsolicited = true}) {
    // Only disconnect the connection handler if the request is
    // solicited, unsolicited requests, ie broker termination don't
    // need this.
    MqttConnectReturnCode returnCode = MqttConnectReturnCode.unsolicited;
    if (!unsolicited) {
      _connectionHandler?.disconnect();
      returnCode = MqttConnectReturnCode.solicited;
    }
    _publishingManager?.published?.close();
    _publishingManager = null;
    _subscriptionsManager = null;
    _keepAlive?.stop();
    _keepAlive = null;
    _connectionHandler = null;
    _clientEventBus?.destroy();
    _clientEventBus = null;
    // Set the connection status before calling onDisconnected
    _connectionStatus.state = MqttConnectionState.disconnected;
    _connectionStatus.returnCode = returnCode;
    if (onDisconnected != null) {
      onDisconnected();
    }
  }

  /// Turn on logging, true to start, false to stop
  void logging({bool on}) {
    MqttLogger.loggingOn = false;
    if (on) {
      MqttLogger.loggingOn = true;
    }
  }

  /// Set the protocol version to V3.1 - default
  void setProtocolV31() {
    Protocol.version = Constants.mqttV31ProtocolVersion;
    Protocol.name = Constants.mqttV31ProtocolName;
  }

  /// Set the protocol version to V3.1.1
  void setProtocolV311() {
    Protocol.version = Constants.mqttV311ProtocolVersion;
    Protocol.name = Constants.mqttV311ProtocolName;
  }
}
