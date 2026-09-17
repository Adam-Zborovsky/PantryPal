# pantrypal_api.api.ActivityApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**activityControllerList**](ActivityApi.md#activitycontrollerlist) | **GET** /v1/households/{householdId}/activity | 


# **activityControllerList**
> activityControllerList(householdId, limit)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getActivityApi();
final String householdId = householdId_example; // String | 
final String limit = limit_example; // String | 

try {
    api.activityControllerList(householdId, limit);
} on DioException catch (e) {
    print('Exception when calling ActivityApi->activityControllerList: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **limit** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

