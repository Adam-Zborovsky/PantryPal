# pantrypal_api.api.ArchiveApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**archiveControllerCompleteCoverUpload**](ArchiveApi.md#archivecontrollercompletecoverupload) | **POST** /v1/households/{householdId}/archive/{cookingInstanceId}/cover/complete | 
[**archiveControllerCover**](ArchiveApi.md#archivecontrollercover) | **GET** /v1/households/{householdId}/archive/{cookingInstanceId}/cover | 
[**archiveControllerCreateCoverUploadRequest**](ArchiveApi.md#archivecontrollercreatecoveruploadrequest) | **POST** /v1/households/{householdId}/archive/{cookingInstanceId}/cover/upload-request | 
[**archiveControllerList**](ArchiveApi.md#archivecontrollerlist) | **GET** /v1/households/{householdId}/archive | 


# **archiveControllerCompleteCoverUpload**
> archiveControllerCompleteCoverUpload(householdId, cookingInstanceId, completeCoverUploadDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getArchiveApi();
final String householdId = householdId_example; // String | 
final String cookingInstanceId = cookingInstanceId_example; // String | 
final CompleteCoverUploadDto completeCoverUploadDto = ; // CompleteCoverUploadDto | 

try {
    api.archiveControllerCompleteCoverUpload(householdId, cookingInstanceId, completeCoverUploadDto);
} on DioException catch (e) {
    print('Exception when calling ArchiveApi->archiveControllerCompleteCoverUpload: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **cookingInstanceId** | **String**|  | 
 **completeCoverUploadDto** | [**CompleteCoverUploadDto**](CompleteCoverUploadDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **archiveControllerCover**
> archiveControllerCover(householdId, cookingInstanceId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getArchiveApi();
final String householdId = householdId_example; // String | 
final String cookingInstanceId = cookingInstanceId_example; // String | 

try {
    api.archiveControllerCover(householdId, cookingInstanceId);
} on DioException catch (e) {
    print('Exception when calling ArchiveApi->archiveControllerCover: $e\n');
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

# **archiveControllerCreateCoverUploadRequest**
> archiveControllerCreateCoverUploadRequest(householdId, cookingInstanceId, createCoverUploadDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getArchiveApi();
final String householdId = householdId_example; // String | 
final String cookingInstanceId = cookingInstanceId_example; // String | 
final CreateCoverUploadDto createCoverUploadDto = ; // CreateCoverUploadDto | 

try {
    api.archiveControllerCreateCoverUploadRequest(householdId, cookingInstanceId, createCoverUploadDto);
} on DioException catch (e) {
    print('Exception when calling ArchiveApi->archiveControllerCreateCoverUploadRequest: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **cookingInstanceId** | **String**|  | 
 **createCoverUploadDto** | [**CreateCoverUploadDto**](CreateCoverUploadDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **archiveControllerList**
> archiveControllerList(householdId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getArchiveApi();
final String householdId = householdId_example; // String | 

try {
    api.archiveControllerList(householdId);
} on DioException catch (e) {
    print('Exception when calling ArchiveApi->archiveControllerList: $e\n');
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

