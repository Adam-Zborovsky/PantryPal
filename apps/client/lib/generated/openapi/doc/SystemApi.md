# pantrypal_api.api.SystemApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**healthControllerLive**](SystemApi.md#healthcontrollerlive) | **GET** /v1/live | 
[**healthControllerReady**](SystemApi.md#healthcontrollerready) | **GET** /v1/ready | 


# **healthControllerLive**
> healthControllerLive()



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getSystemApi();

try {
    api.healthControllerLive();
} on DioException catch (e) {
    print('Exception when calling SystemApi->healthControllerLive: $e\n');
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

# **healthControllerReady**
> healthControllerReady()



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getSystemApi();

try {
    api.healthControllerReady();
} on DioException catch (e) {
    print('Exception when calling SystemApi->healthControllerReady: $e\n');
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

