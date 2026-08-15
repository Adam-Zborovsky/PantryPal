//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'register_dto.g.dart';

/// RegisterDto
///
/// Properties:
/// * [email] 
/// * [password] 
/// * [displayName] 
/// * [betaInvite] - One-time operator beta invite.
/// * [householdName] 
/// * [timezone] 
/// * [client] 
@BuiltValue()
abstract class RegisterDto implements Built<RegisterDto, RegisterDtoBuilder> {
  @BuiltValueField(wireName: r'email')
  String get email;

  @BuiltValueField(wireName: r'password')
  String get password;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  /// One-time operator beta invite.
  @BuiltValueField(wireName: r'betaInvite')
  String get betaInvite;

  @BuiltValueField(wireName: r'householdName')
  String get householdName;

  @BuiltValueField(wireName: r'timezone')
  String? get timezone;

  @BuiltValueField(wireName: r'client')
  RegisterDtoClientEnum? get client;
  // enum clientEnum {  web,  android,  };

  RegisterDto._();

  factory RegisterDto([void updates(RegisterDtoBuilder b)]) = _$RegisterDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RegisterDtoBuilder b) => b
      ..timezone = 'UTC'
      ..client = RegisterDtoClientEnum.valueOf('web');

  @BuiltValueSerializer(custom: true)
  static Serializer<RegisterDto> get serializer => _$RegisterDtoSerializer();
}

class _$RegisterDtoSerializer implements PrimitiveSerializer<RegisterDto> {
  @override
  final Iterable<Type> types = const [RegisterDto, _$RegisterDto];

  @override
  final String wireName = r'RegisterDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RegisterDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'email';
    yield serializers.serialize(
      object.email,
      specifiedType: const FullType(String),
    );
    yield r'password';
    yield serializers.serialize(
      object.password,
      specifiedType: const FullType(String),
    );
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'betaInvite';
    yield serializers.serialize(
      object.betaInvite,
      specifiedType: const FullType(String),
    );
    yield r'householdName';
    yield serializers.serialize(
      object.householdName,
      specifiedType: const FullType(String),
    );
    if (object.timezone != null) {
      yield r'timezone';
      yield serializers.serialize(
        object.timezone,
        specifiedType: const FullType(String),
      );
    }
    if (object.client != null) {
      yield r'client';
      yield serializers.serialize(
        object.client,
        specifiedType: const FullType(RegisterDtoClientEnum),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    RegisterDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RegisterDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'email':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.email = valueDes;
          break;
        case r'password':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.password = valueDes;
          break;
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.displayName = valueDes;
          break;
        case r'betaInvite':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.betaInvite = valueDes;
          break;
        case r'householdName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.householdName = valueDes;
          break;
        case r'timezone':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.timezone = valueDes;
          break;
        case r'client':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(RegisterDtoClientEnum),
          ) as RegisterDtoClientEnum?;
          if (valueDes == null) continue;
          result.client = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RegisterDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RegisterDtoBuilder();
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

class RegisterDtoClientEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'web')
  static const RegisterDtoClientEnum web = _$registerDtoClientEnum_web;
  @BuiltValueEnumConst(wireName: r'android')
  static const RegisterDtoClientEnum android = _$registerDtoClientEnum_android;

  static Serializer<RegisterDtoClientEnum> get serializer => _$registerDtoClientEnumSerializer;

  const RegisterDtoClientEnum._(String name): super(name);

  static BuiltSet<RegisterDtoClientEnum> get values => _$registerDtoClientEnumValues;
  static RegisterDtoClientEnum valueOf(String name) => _$registerDtoClientEnumValueOf(name);
}

