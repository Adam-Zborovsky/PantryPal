# pantrypal_api.api.ImportsApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**importsControllerCancel**](ImportsApi.md#importscontrollercancel) | **POST** /v1/households/{householdId}/imports/{id}/cancel | 
[**importsControllerCreate**](ImportsApi.md#importscontrollercreate) | **POST** /v1/households/{householdId}/imports | 
[**importsControllerGet**](ImportsApi.md#importscontrollerget) | **GET** /v1/households/{householdId}/imports/{id} | 


# **importsControllerCancel**
> importsControllerCancel(householdId, id)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getImportsApi();
final String householdId = householdId_example; // String | 
final String id = id_example; // String | 

try {
    api.importsControllerCancel(householdId, id);
} on DioException catch (e) {
    print('Exception when calling ImportsApi->importsControllerCancel: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **id** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **importsControllerCreate**
> importsControllerCreate(householdId, createImportDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getImportsApi();
final String householdId = householdId_example; // String | 
final CreateImportDto createImportDto = ; // CreateImportDto | 

try {
    api.importsControllerCreate(householdId, createImportDto);
} on DioException catch (e) {
    print('Exception when calling ImportsApi->importsControllerCreate: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **createImportDto** | [**CreateImportDto**](CreateImportDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **importsControllerGet**
> importsControllerGet(householdId, id)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getImportsApi();
final String householdId = householdId_example; // String | 
final String id = id_example; // String | 

try {
    api.importsControllerGet(householdId, id);
} on DioException catch (e) {
    print('Exception when calling ImportsApi->importsControllerGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **id** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

