# pantrypal_api.api.TripsApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**tripsControllerCancel**](TripsApi.md#tripscontrollercancel) | **POST** /v1/households/{householdId}/trips/{tripId}/cancel | 
[**tripsControllerComplete**](TripsApi.md#tripscontrollercomplete) | **POST** /v1/households/{householdId}/trips/{tripId}/complete | 
[**tripsControllerConfirm**](TripsApi.md#tripscontrollerconfirm) | **POST** /v1/households/{householdId}/trips/{tripId}/confirm | 
[**tripsControllerCreate**](TripsApi.md#tripscontrollercreate) | **POST** /v1/households/{householdId}/trips | 
[**tripsControllerDetail**](TripsApi.md#tripscontrollerdetail) | **GET** /v1/households/{householdId}/trips/{tripId} | 
[**tripsControllerList**](TripsApi.md#tripscontrollerlist) | **GET** /v1/households/{householdId}/trips | 
[**tripsControllerStart**](TripsApi.md#tripscontrollerstart) | **POST** /v1/households/{householdId}/trips/{tripId}/start | 
[**tripsControllerUpdate**](TripsApi.md#tripscontrollerupdate) | **PATCH** /v1/households/{householdId}/trips/{tripId} | 
[**tripsControllerUpdateItem**](TripsApi.md#tripscontrollerupdateitem) | **PATCH** /v1/households/{householdId}/trips/{tripId}/items/{itemId} | 


# **tripsControllerCancel**
> tripsControllerCancel(householdId, tripId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getTripsApi();
final String householdId = householdId_example; // String | 
final String tripId = tripId_example; // String | 

try {
    api.tripsControllerCancel(householdId, tripId);
} on DioException catch (e) {
    print('Exception when calling TripsApi->tripsControllerCancel: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **tripId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tripsControllerComplete**
> tripsControllerComplete(householdId, tripId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getTripsApi();
final String householdId = householdId_example; // String | 
final String tripId = tripId_example; // String | 

try {
    api.tripsControllerComplete(householdId, tripId);
} on DioException catch (e) {
    print('Exception when calling TripsApi->tripsControllerComplete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **tripId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tripsControllerConfirm**
> tripsControllerConfirm(householdId, tripId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getTripsApi();
final String householdId = householdId_example; // String | 
final String tripId = tripId_example; // String | 

try {
    api.tripsControllerConfirm(householdId, tripId);
} on DioException catch (e) {
    print('Exception when calling TripsApi->tripsControllerConfirm: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **tripId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tripsControllerCreate**
> tripsControllerCreate(householdId, createShoppingTripDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getTripsApi();
final String householdId = householdId_example; // String | 
final CreateShoppingTripDto createShoppingTripDto = ; // CreateShoppingTripDto | 

try {
    api.tripsControllerCreate(householdId, createShoppingTripDto);
} on DioException catch (e) {
    print('Exception when calling TripsApi->tripsControllerCreate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **createShoppingTripDto** | [**CreateShoppingTripDto**](CreateShoppingTripDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tripsControllerDetail**
> tripsControllerDetail(householdId, tripId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getTripsApi();
final String householdId = householdId_example; // String | 
final String tripId = tripId_example; // String | 

try {
    api.tripsControllerDetail(householdId, tripId);
} on DioException catch (e) {
    print('Exception when calling TripsApi->tripsControllerDetail: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **tripId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tripsControllerList**
> tripsControllerList(householdId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getTripsApi();
final String householdId = householdId_example; // String | 

try {
    api.tripsControllerList(householdId);
} on DioException catch (e) {
    print('Exception when calling TripsApi->tripsControllerList: $e\n');
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

# **tripsControllerStart**
> tripsControllerStart(householdId, tripId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getTripsApi();
final String householdId = householdId_example; // String | 
final String tripId = tripId_example; // String | 

try {
    api.tripsControllerStart(householdId, tripId);
} on DioException catch (e) {
    print('Exception when calling TripsApi->tripsControllerStart: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **tripId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tripsControllerUpdate**
> tripsControllerUpdate(householdId, tripId, updateShoppingTripDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getTripsApi();
final String householdId = householdId_example; // String | 
final String tripId = tripId_example; // String | 
final UpdateShoppingTripDto updateShoppingTripDto = ; // UpdateShoppingTripDto | 

try {
    api.tripsControllerUpdate(householdId, tripId, updateShoppingTripDto);
} on DioException catch (e) {
    print('Exception when calling TripsApi->tripsControllerUpdate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **tripId** | **String**|  | 
 **updateShoppingTripDto** | [**UpdateShoppingTripDto**](UpdateShoppingTripDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tripsControllerUpdateItem**
> tripsControllerUpdateItem(householdId, tripId, itemId, updateShoppingItemDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getTripsApi();
final String householdId = householdId_example; // String | 
final String tripId = tripId_example; // String | 
final String itemId = itemId_example; // String | 
final UpdateShoppingItemDto updateShoppingItemDto = ; // UpdateShoppingItemDto | 

try {
    api.tripsControllerUpdateItem(householdId, tripId, itemId, updateShoppingItemDto);
} on DioException catch (e) {
    print('Exception when calling TripsApi->tripsControllerUpdateItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **tripId** | **String**|  | 
 **itemId** | **String**|  | 
 **updateShoppingItemDto** | [**UpdateShoppingItemDto**](UpdateShoppingItemDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

