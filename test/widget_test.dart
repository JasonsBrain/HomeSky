// Tests for the privacy gate: run with `flutter test`.
// (This file also stops `flutter create` adding its default counter-app test.)

import 'package:flutter_test/flutter_test.dart';
import 'package:homesky/services/local_network.dart';

void main() {
  test('home-network addresses are allowed', () {
    expect(LocalNetwork.isPrivateIPv4('192.168.1.21'), isTrue);
    expect(LocalNetwork.isPrivateIPv4('10.0.0.5'), isTrue);
    expect(LocalNetwork.isPrivateIPv4('172.16.4.2'), isTrue);
  });

  test('anything else is blocked', () {
    expect(LocalNetwork.isPrivateIPv4('8.8.8.8'), isFalse); //          public internet
    expect(LocalNetwork.isPrivateIPv4('172.32.0.1'), isFalse); //       just outside the private range
    expect(LocalNetwork.isPrivateIPv4('example.com'), isFalse); //      names are never allowed
    expect(LocalNetwork.isPrivateIPv4('192.168.1.256'), isFalse); //    not a real address
  });
}
