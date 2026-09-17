# pantrypal_api.model.CreateCookingInstanceDto

## Load the model package
```dart
import 'package:pantrypal_api/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**recipeId** | **String** |  | 
**targetServings** | **String** | Desired serving count, encoded as a positive decimal. | 
**cookingDate** | **String** | ISO 8601 cooking date and time. Omit for Quick Cook. | [optional] 
**shoppingTripId** | **String** |  | [optional] 
**assignmentMode** | **String** |  | [optional] [default to 'AUTOMATIC']

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


