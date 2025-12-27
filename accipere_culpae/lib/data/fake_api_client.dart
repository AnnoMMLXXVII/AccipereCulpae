import 'api_client.dart';

class FakeApiClient implements ApiClient {
  @override
  Future<void> createTransaction(Map<String, dynamic> payload) async {
    // Simulate latency. Replace with real HTTP later.
    await Future.delayed(const Duration(milliseconds: 650));

    // Simulate success. If you want to test failures:
    // throw Exception('Simulated backend failure');
  }
}
