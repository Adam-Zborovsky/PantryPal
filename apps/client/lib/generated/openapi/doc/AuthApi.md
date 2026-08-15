# pantrypal_api.api.AuthApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**authControllerLogin**](AuthApi.md#authcontrollerlogin) | **POST** /v1/auth/login | 
[**authControllerLogout**](AuthApi.md#authcontrollerlogout) | **POST** /v1/auth/logout | 
[**authControllerRefresh**](AuthApi.md#authcontrollerrefresh) | **POST** /v1/auth/refresh | 
[**authControllerRegister**](AuthApi.md#authcontrollerregister) | **POST** /v1/auth/register | 


# **authControllerLogin**
> AuthSessionResponseDto authControllerLogin(loginDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getAuthApi();
final LoginDto loginDto = ; // LoginDto | 

try {
    final response = api.authControllerLogin(loginDto);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->authControllerLogin: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **loginDto** | [**LoginDto**](LoginDto.md)|  | 

### Return type

[**AuthSessionResponseDto**](AuthSessionResponseDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authControllerLogout**
> authControllerLogout(refreshDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getAuthApi();
final RefreshDto refreshDto = ; // RefreshDto | 

try {
    api.authControllerLogout(refreshDto);
} on DioException catch (e) {
    print('Exception when calling AuthApi->authControllerLogout: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **refreshDto** | [**RefreshDto**](RefreshDto.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authControllerRefresh**
> AuthSessionResponseDto authControllerRefresh(refreshDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getAuthApi();
final RefreshDto refreshDto = ; // RefreshDto | 

try {
    final response = api.authControllerRefresh(refreshDto);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->authControllerRefresh: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **refreshDto** | [**RefreshDto**](RefreshDto.md)|  | 

### Return type

[**AuthSessionResponseDto**](AuthSessionResponseDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authControllerRegister**
> AuthSessionResponseDto authControllerRegister(registerDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getAuthApi();
final RegisterDto registerDto = ; // RegisterDto | 

try {
    final response = api.authControllerRegister(registerDto);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->authControllerRegister: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **registerDto** | [**RegisterDto**](RegisterDto.md)|  | 

### Return type

[**AuthSessionResponseDto**](AuthSessionResponseDto.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

