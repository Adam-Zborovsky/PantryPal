# pantrypal_api.model.AuthSessionResponseDto

## Load the model package
```dart
import 'package:pantrypal_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**accessToken** | **String** |  | 
**refreshToken** | **String** | Returned only to Android clients. | [optional] 
**account** | [**AccountResponseDto**](AccountResponseDto.md) |  | [optional] 
**household** | [**HouseholdResponseDto**](HouseholdResponseDto.md) |  | [optional] 
**householdCode** | **String** | Returned only immediately after registration. | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


