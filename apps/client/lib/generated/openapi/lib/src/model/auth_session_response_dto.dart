//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:pantrypal_api/src/model/account_response_dto.dart';
import 'package:pantrypal_api/src/model/household_response_dto.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'auth_session_response_dto.g.dart';

/// AuthSessionResponseDto
///
/// Properties:
/// * [accessToken] 
/// * [refreshToken] - Returned only to Android clients.
/// * [account] 
/// * [household] 
/// * [householdCode] - Returned only immediately after registration.
@BuiltValue()
abstract class AuthSessionResponseDto implements Built<AuthSessionResponseDto, AuthSessionResponseDtoBuilder> {
  @BuiltValueField(wireName: r'accessToken')
  String get accessToken;

  /// Returned only to Android clients.
  @BuiltValueField(wireName: r'refreshToken')
  String? get refreshToken;

  @BuiltValueField(wireName: r'account')
  AccountResponseDto? get account;

  @BuiltValueField(wireName: r'household')
  HouseholdResponseDto? get household;

  /// Returned only immediately after registration.
  @BuiltValueField(wireName: r'householdCode')
  String? get householdCode;

  AuthSessionResponseDto._();

  factory AuthSessionResponseDto([void updates(AuthSessionResponseDtoBuilder b)]) = _$AuthSessionResponseDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AuthSessionResponseDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AuthSessionResponseDto> get serializer => _$AuthSessionResponseDtoSerializer();
}

class _$AuthSessionResponseDtoSerializer implements PrimitiveSerializer<AuthSessionResponseDto> {
  @override
  final Iterable<Type> types = const [AuthSessionResponseDto, _$AuthSessionResponseDto];

  @override
  final String wireName = r'AuthSessionResponseDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AuthSessionResponseDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'accessToken';
    yield serializers.serialize(
      object.accessToken,
      specifiedType: const FullType(String),
    );
    if (object.refreshToken != null) {
      yield r'refreshToken';
      yield serializers.serialize(
        object.refreshToken,
        specifiedType: const FullType(String),
      );
    }
    if (object.account != null) {
      yield r'account';
      yield serializers.serialize(
        object.account,
        specifiedType: const FullType(AccountResponseDto),
      );
    }
    if (object.household != null) {
      yield r'household';
      yield serializers.serialize(
        object.household,
        specifiedType: const FullType(HouseholdResponseDto),
      );
    }
    if (object.householdCode != null) {
      yield r'householdCode';
      yield serializers.serialize(
        object.householdCode,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    AuthSessionResponseDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AuthSessionResponseDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'accessToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.accessToken = valueDes;
          break;
        case r'refreshToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.refreshToken = valueDes;
          break;
        case r'account':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(AccountResponseDto),
          ) as AccountResponseDto?;
          if (valueDes == null) continue;
          result.account.replace(valueDes);
          break;
        case r'household':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(HouseholdResponseDto),
          ) as HouseholdResponseDto?;
          if (valueDes == null) continue;
          result.household.replace(valueDes);
          break;
        case r'householdCode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.householdCode = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AuthSessionResponseDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AuthSessionResponseDtoBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}

