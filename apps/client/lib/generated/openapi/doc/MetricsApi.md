# pantrypal_api.api.MetricsApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**metricsControllerMetrics**](MetricsApi.md#metricscontrollermetrics) | **GET** /v1/metrics | 


# **metricsControllerMetrics**
> metricsControllerMetrics()



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getMetricsApi();

try {
    api.metricsControllerMetrics();
} on DioException catch (e) {
    print('Exception when calling MetricsApi->metricsControllerMetrics: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

