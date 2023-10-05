import "dart:convert";
import "dart:io";
import "package:centrifuge/centrifuge.dart" as centrifuge;

void run() async {
  final url = 'ws://localhost:8000/connection/websocket';
  final channel = 'user:event';
  final userName = 'dart';
  final userJwtToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkYXJ0IiwiZXhwIjoxNjk3MTIyMjc3LCJpYXQiOjE2OTY1MTc0Nzd9.ULB8oIjEYIE3l773b6mqh7pUQhJjK_-EglvHUaYtMaU';
  final subscriptionJwtToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkYXJ0IiwiZXhwIjoxNjk3MTIyNTg5LCJpYXQiOjE2OTY1MTc3ODksImNoYW5uZWwiOiJ1c2VyOmV2ZW50In0.GDtW9otvn9bNIFtKDoqkF7UPbno4o3zKf1X9qwBoqJg';

  void onEvent(dynamic event) {
    print('client> $event');
  }

  try {
    final client = centrifuge.createClient(
        url,
        centrifuge.ClientConfig(
          name: userName,
          token: userJwtToken,
          // Headers are only supported on platforms that support dart:io
          headers: <String, dynamic>{'X-Example-Header': 'example'},
        ));

    // State changes.
    client.connecting.listen(onEvent);
    client.connected.listen(onEvent);
    client.disconnected.listen(onEvent);

    // Handle async errors.
    client.error.listen(onEvent);

    // Server-side subscriptions.
    client.subscribing.listen(onEvent);
    client.subscribed.listen(onEvent);
    client.unsubscribed.listen(onEvent);
    client.publication.listen(onEvent);
    client.join.listen(onEvent);
    client.leave.listen(onEvent);

    final subscription = client.newSubscription(
      channel,
      centrifuge.SubscriptionConfig(
        token: subscriptionJwtToken,
      ),
    );

    void onSubscriptionEvent(dynamic event) async {
      print('subscription $channel> $event');
    }

    // State changes.
    subscription.subscribing.listen(onSubscriptionEvent);
    subscription.subscribed.listen(onSubscriptionEvent);
    subscription.unsubscribed.listen(onSubscriptionEvent);

    // Messages.
    subscription.publication.listen(onSubscriptionEvent);
    subscription.join.listen(onSubscriptionEvent);
    subscription.leave.listen(onSubscriptionEvent);

    // Handle subscription async errors.
    subscription.error.listen(onSubscriptionEvent);

    await subscription.subscribe();

    await client.connect();

    final handler = _handleUserInput(client, subscription);

    await for (List<int> codeUnit in stdin) {
      final message = utf8.decode(codeUnit).trim();
      handler(message);
    }
  } catch (ex) {
    print(ex);
  }
}

Function(String) _handleUserInput(
    centrifuge.Client client, centrifuge.Subscription subscription) {
  return (String message) async {
    switch (message) {
      case '#subscribe':
        await subscription.subscribe();
        break;
      case '#unsubscribe':
        await subscription.unsubscribe();
        break;
      case '#remove':
        await client.removeSubscription(subscription);
        break;
      case '#connect':
        await client.connect();
        break;
      case '#rpc':
        final request = jsonEncode({'param': 'test'});
        final data = utf8.encode(request);
        final result = await client.rpc('test', data);
        print('RPC result: ${utf8.decode(result.data)}');
        break;
      case '#presence':
        final result = await subscription.presence();
        print(result);
        break;
      case '#presenceStats':
        final result = await subscription.presenceStats();
        print(result);
        break;
      case '#history':
        final result = await subscription.history(limit: 10);
        print('History num publications: ${result.publications.length}');
        print('Stream top position: ${result.offset}, epoch: ${result.epoch}');
        break;
      case '#disconnect':
        await client.disconnect();
        break;
      default:
        final output = jsonEncode({'value': message});
        final data = utf8.encode(output);
        try {
          print(data);
          await subscription.publish(data);
        } catch (ex) {
          print("can't publish: $ex");
        }
        break;
    }
    return;
  };
}
