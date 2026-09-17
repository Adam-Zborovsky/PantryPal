# pantrypal_api.api.CookingApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**cookingControllerAssignTrip**](CookingApi.md#cookingcontrollerassigntrip) | **PATCH** /v1/households/{householdId}/cooking/{cookingInstanceId} | 
[**cookingControllerCookAgain**](CookingApi.md#cookingcontrollercookagain) | **POST** /v1/households/{householdId}/cooking/{cookingInstanceId}/cook-again | 
[**cookingControllerCreate**](CookingApi.md#cookingcontrollercreate) | **POST** /v1/households/{householdId}/cooking | 
[**cookingControllerList**](CookingApi.md#cookingcontrollerlist) | **GET** /v1/households/{householdId}/cooking | 
[**cookingControllerMarkCooked**](CookingApi.md#cookingcontrollermarkcooked) | **POST** /v1/households/{householdId}/cooking/{cookingInstanceId}/mark-cooked | 
[**cookingControllerRequestTransfer**](CookingApi.md#cookingcontrollerrequesttransfer) | **POST** /v1/households/{householdId}/cooking/{cookingInstanceId}/cook-transfer | 
[**cookingControllerResolveTransfer**](CookingApi.md#cookingcontrollerresolvetransfer) | **POST** /v1/households/{householdId}/cooking/{cookingInstanceId}/cook-transfer/resolve | 


# **cookingControllerAssignTrip**
> cookingControllerAssignTrip(householdId, cookingInstanceId, updateCookingTripDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getCookingApi();
final String householdId = householdId_example; // String | 
final String cookingInstanceId = cookingInstanceId_example; // String | 
final UpdateCookingTripDto updateCookingTripDto = ; // UpdateCookingTripDto | 

try {
    api.cookingControllerAssignTrip(householdId, cookingInstanceId, updateCookingTripDto);
} on DioException catch (e) {
    print('Exception when calling CookingApi->cookingControllerAssignTrip: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **cookingInstanceId** | **String**|  | 
 **updateCookingTripDto** | [**UpdateCookingTripDto**](UpdateCookingTripDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cookingControllerCookAgain**
> cookingControllerCookAgain(householdId, cookingInstanceId, cookAgainDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getCookingApi();
final String householdId = householdId_example; // String | 
final String cookingInstanceId = cookingInstanceId_example; // String | 
final CookAgainDto cookAgainDto = ; // CookAgainDto | 

try {
    api.cookingControllerCookAgain(householdId, cookingInstanceId, cookAgainDto);
} on DioException catch (e) {
    print('Exception when calling CookingApi->cookingControllerCookAgain: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **cookingInstanceId** | **String**|  | 
 **cookAgainDto** | [**CookAgainDto**](CookAgainDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cookingControllerCreate**
> cookingControllerCreate(householdId, createCookingInstanceDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getCookingApi();
final String householdId = householdId_example; // String | 
final CreateCookingInstanceDto createCookingInstanceDto = ; // CreateCookingInstanceDto | 

try {
    api.cookingControllerCreate(householdId, createCookingInstanceDto);
} on DioException catch (e) {
    print('Exception when calling CookingApi->cookingControllerCreate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **createCookingInstanceDto** | [**CreateCookingInstanceDto**](CreateCookingInstanceDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cookingControllerList**
> cookingControllerList(householdId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getCookingApi();
final String householdId = householdId_example; // String | 

try {
    api.cookingControllerList(householdId);
} on DioException catch (e) {
    print('Exception when calling CookingApi->cookingControllerList: $e\n');
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

# **cookingControllerMarkCooked**
> cookingControllerMarkCooked(householdId, cookingInstanceId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getCookingApi();
final String householdId = householdId_example; // String | 
final String cookingInstanceId = cookingInstanceId_example; // String | 

try {
    api.cookingControllerMarkCooked(householdId, cookingInstanceId);
} on DioException catch (e) {
    print('Exception when calling CookingApi->cookingControllerMarkCooked: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **cookingInstanceId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cookingControllerRequestTransfer**
> cookingControllerRequestTransfer(householdId, cookingInstanceId, requestCookTransferDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getCookingApi();
final String householdId = householdId_example; // String | 
final String cookingInstanceId = cookingInstanceId_example; // String | 
final RequestCookTransferDto requestCookTransferDto = ; // RequestCookTransferDto | 

try {
    api.cookingControllerRequestTransfer(householdId, cookingInstanceId, requestCookTransferDto);
} on DioException catch (e) {
    print('Exception when calling CookingApi->cookingControllerRequestTransfer: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **cookingInstanceId** | **String**|  | 
 **requestCookTransferDto** | [**RequestCookTransferDto**](RequestCookTransferDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **cookingControllerResolveTransfer**
> cookingControllerResolveTransfer(householdId, cookingInstanceId, resolveCookTransferDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getCookingApi();
final String householdId = householdId_example; // String | 
final String cookingInstanceId = cookingInstanceId_example; // String | 
final ResolveCookTransferDto resolveCookTransferDto = ; // ResolveCookTransferDto | 

try {
    api.cookingControllerResolveTransfer(householdId, cookingInstanceId, resolveCookTransferDto);
} on DioException catch (e) {
    print('Exception when calling CookingApi->cookingControllerResolveTransfer: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **cookingInstanceId** | **String**|  | 
 **resolveCookTransferDto** | [**ResolveCookTransferDto**](ResolveCookTransferDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

