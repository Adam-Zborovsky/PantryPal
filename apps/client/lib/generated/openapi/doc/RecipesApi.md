# pantrypal_api.api.RecipesApi

## Load the API package
```dart
import 'package:pantrypal_api/api.dart';
```

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**recipesControllerList**](RecipesApi.md#recipescontrollerlist) | **GET** /v1/households/{householdId}/recipes | 
[**recipesControllerReview**](RecipesApi.md#recipescontrollerreview) | **GET** /v1/households/{householdId}/recipes/{recipeId}/review | 
[**recipesControllerSaveReview**](RecipesApi.md#recipescontrollersavereview) | **PUT** /v1/households/{householdId}/recipes/{recipeId}/review | 


# **recipesControllerList**
> recipesControllerList(householdId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getRecipesApi();
final String householdId = householdId_example; // String | 

try {
    api.recipesControllerList(householdId);
} on DioException catch (e) {
    print('Exception when calling RecipesApi->recipesControllerList: $e\n');
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

# **recipesControllerReview**
> recipesControllerReview(householdId, recipeId)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getRecipesApi();
final String householdId = householdId_example; // String | 
final String recipeId = recipeId_example; // String | 

try {
    api.recipesControllerReview(householdId, recipeId);
} on DioException catch (e) {
    print('Exception when calling RecipesApi->recipesControllerReview: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **recipeId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **recipesControllerSaveReview**
> recipesControllerSaveReview(householdId, recipeId, saveRecipeReviewDto)



### Example
```dart
import 'package:pantrypal_api/api.dart';

final api = PantrypalApi().getRecipesApi();
final String householdId = householdId_example; // String | 
final String recipeId = recipeId_example; // String | 
final SaveRecipeReviewDto saveRecipeReviewDto = ; // SaveRecipeReviewDto | 

try {
    api.recipesControllerSaveReview(householdId, recipeId, saveRecipeReviewDto);
} on DioException catch (e) {
    print('Exception when calling RecipesApi->recipesControllerSaveReview: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **householdId** | **String**|  | 
 **recipeId** | **String**|  | 
 **saveRecipeReviewDto** | [**SaveRecipeReviewDto**](SaveRecipeReviewDto.md)|  | 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

