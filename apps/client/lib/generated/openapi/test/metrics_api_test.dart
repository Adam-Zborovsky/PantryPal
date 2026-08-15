import 'package:test/test.dart';
import 'package:pantrypal_api/pantrypal_api.dart';

/// tests for MetricsApi
void main() {
  final instance = PantrypalApi().getMetricsApi();

  group(MetricsApi, () {
    //Future metricsControllerMetrics() async
    test('test metricsControllerMetrics', () async {
      // TODO
    });
  });
}
