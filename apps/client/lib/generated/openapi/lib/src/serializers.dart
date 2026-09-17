//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:pantrypal_api/src/date_serializer.dart';
import 'package:pantrypal_api/src/model/date.dart';

import 'package:pantrypal_api/src/model/account_response_dto.dart';
import 'package:pantrypal_api/src/model/auth_session_response_dto.dart';
import 'package:pantrypal_api/src/model/complete_cover_upload_dto.dart';
import 'package:pantrypal_api/src/model/complete_media_upload_response_dto.dart';
import 'package:pantrypal_api/src/model/cook_again_dto.dart';
import 'package:pantrypal_api/src/model/create_cooking_instance_dto.dart';
import 'package:pantrypal_api/src/model/create_cover_upload_dto.dart';
import 'package:pantrypal_api/src/model/create_import_dto.dart';
import 'package:pantrypal_api/src/model/create_media_upload_dto.dart';
import 'package:pantrypal_api/src/model/create_shopping_trip_dto.dart';
import 'package:pantrypal_api/src/model/household_response_dto.dart';
import 'package:pantrypal_api/src/model/join_household_dto.dart';
import 'package:pantrypal_api/src/model/login_dto.dart';
import 'package:pantrypal_api/src/model/media_upload_response_dto.dart';
import 'package:pantrypal_api/src/model/refresh_dto.dart';
import 'package:pantrypal_api/src/model/register_dto.dart';
import 'package:pantrypal_api/src/model/remove_push_subscription_dto.dart';
import 'package:pantrypal_api/src/model/request_cook_transfer_dto.dart';
import 'package:pantrypal_api/src/model/resolve_cook_transfer_dto.dart';
import 'package:pantrypal_api/src/model/review_ingredient_dto.dart';
import 'package:pantrypal_api/src/model/save_recipe_review_dto.dart';
import 'package:pantrypal_api/src/model/update_cooking_trip_dto.dart';
import 'package:pantrypal_api/src/model/update_shopping_item_dto.dart';
import 'package:pantrypal_api/src/model/update_shopping_trip_dto.dart';
import 'package:pantrypal_api/src/model/upsert_push_subscription_dto.dart';

part 'serializers.g.dart';

@SerializersFor([
  AccountResponseDto,
  AuthSessionResponseDto,
  CompleteCoverUploadDto,
  CompleteMediaUploadResponseDto,
  CookAgainDto,
  CreateCookingInstanceDto,
  CreateCoverUploadDto,
  CreateImportDto,
  CreateMediaUploadDto,
  CreateShoppingTripDto,
  HouseholdResponseDto,
  JoinHouseholdDto,
  LoginDto,
  MediaUploadResponseDto,
  RefreshDto,
  RegisterDto,
  RemovePushSubscriptionDto,
  RequestCookTransferDto,
  ResolveCookTransferDto,
  ReviewIngredientDto,
  SaveRecipeReviewDto,
  UpdateCookingTripDto,
  UpdateShoppingItemDto,
  UpdateShoppingTripDto,
  UpsertPushSubscriptionDto,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(ReviewIngredientDto)]),
        () => ListBuilder<ReviewIngredientDto>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(String)]),
        () => ListBuilder<String>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer())
    ).build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
