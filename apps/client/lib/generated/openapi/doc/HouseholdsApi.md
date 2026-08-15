# pantrypal_api.api.HouseholdsApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**householdsControllerJoin**](HouseholdsApi.md#householdscontrollerjoin) | **POST** /v1/households/join | 
[**householdsControllerLeave**](HouseholdsApi.md#householdscontrollerleave) | **POST** /v1/households/{householdId}/leave | 
[**householdsControllerList**](HouseholdsApi.md#householdscontrollerlist) | **GET** /v1/households | 
[**householdsControllerMembers**](HouseholdsApi.md#householdscontrollermembers) | **GET** /v1/households/{householdId}/members | 
[**householdsControllerRotateCode**](HouseholdsApi.md#householdscontrollerrotatecode) | **POST** /v1/households/{householdId}/invite-code/rotate | 


# **householdsControllerJoin**
> householdsControllerJoin(joinHouseholdDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getHouseholdsApi();
final JoinHouseholdDto joinHouseholdDto = ; // JoinHouseholdDto | 

try {
    api.householdsControllerJoin(joinHouseholdDto);
} on DioException catch (e) {
    print('Exception when calling HouseholdsApi->householdsControllerJoin: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **joinHouseholdDto** | [**JoinHouseholdDto**](JoinHouseholdDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **householdsControllerLeave**
> householdsControllerLeave(householdId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getHouseholdsApi();
final String householdId = householdId_example; // String | 

try {
    api.householdsControllerLeave(householdId);
} on DioException catch (e) {
    print('Exception when calling HouseholdsApi->householdsControllerLeave: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **householdsControllerList**
> householdsControllerList()



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getHouseholdsApi();

try {
    api.householdsControllerList();
} on DioException catch (e) {
    print('Exception when calling HouseholdsApi->householdsControllerList: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **householdsControllerMembers**
> householdsControllerMembers(householdId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getHouseholdsApi();
final String householdId = householdId_example; // String | 

try {
    api.householdsControllerMembers(householdId);
} on DioException catch (e) {
    print('Exception when calling HouseholdsApi->householdsControllerMembers: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **householdsControllerRotateCode**
> householdsControllerRotateCode(householdId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getHouseholdsApi();
final String householdId = householdId_example; // String | 

try {
    api.householdsControllerRotateCode(householdId);
} on DioException catch (e) {
    print('Exception when calling HouseholdsApi->householdsControllerRotateCode: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

