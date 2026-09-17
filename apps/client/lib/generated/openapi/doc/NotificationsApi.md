# pantrypal_api.api.NotificationsApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**notificationsControllerList**](NotificationsApi.md#notificationscontrollerlist) | **GET** /v1/households/{householdId}/notifications | 
[**notificationsControllerMarkRead**](NotificationsApi.md#notificationscontrollermarkread) | **POST** /v1/households/{householdId}/notifications/{notificationId}/read | 
[**pushSubscriptionsControllerRemove**](NotificationsApi.md#pushsubscriptionscontrollerremove) | **DELETE** /v1/push-subscriptions | 
[**pushSubscriptionsControllerUpsert**](NotificationsApi.md#pushsubscriptionscontrollerupsert) | **POST** /v1/push-subscriptions | 


# **notificationsControllerList**
> notificationsControllerList(householdId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getNotificationsApi();
final String householdId = householdId_example; // String | 

try {
    api.notificationsControllerList(householdId);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->notificationsControllerList: $e\n');
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

# **notificationsControllerMarkRead**
> notificationsControllerMarkRead(householdId, notificationId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getNotificationsApi();
final String householdId = householdId_example; // String | 
final String notificationId = notificationId_example; // String | 

try {
    api.notificationsControllerMarkRead(householdId, notificationId);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->notificationsControllerMarkRead: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **notificationId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **pushSubscriptionsControllerRemove**
> pushSubscriptionsControllerRemove(removePushSubscriptionDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getNotificationsApi();
final RemovePushSubscriptionDto removePushSubscriptionDto = ; // RemovePushSubscriptionDto | 

try {
    api.pushSubscriptionsControllerRemove(removePushSubscriptionDto);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->pushSubscriptionsControllerRemove: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **removePushSubscriptionDto** | [**RemovePushSubscriptionDto**](RemovePushSubscriptionDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **pushSubscriptionsControllerUpsert**
> pushSubscriptionsControllerUpsert(upsertPushSubscriptionDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getNotificationsApi();
final UpsertPushSubscriptionDto upsertPushSubscriptionDto = ; // UpsertPushSubscriptionDto | 

try {
    api.pushSubscriptionsControllerUpsert(upsertPushSubscriptionDto);
} on DioException catch (e) {
    print('Exception when calling NotificationsApi->pushSubscriptionsControllerUpsert: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **upsertPushSubscriptionDto** | [**UpsertPushSubscriptionDto**](UpsertPushSubscriptionDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

