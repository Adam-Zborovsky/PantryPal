//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'login_dto.g.dart';

/// LoginDto
///
/// Properties:
/// * [email] 
/// * [password] 
/// * [client] 
@BuiltValue()
abstract class LoginDto implements Built<LoginDto, LoginDtoBuilder> {
  @BuiltValueField(wireName: r'email')
  String get email;

  @BuiltValueField(wireName: r'password')
  String get password;

  @BuiltValueField(wireName: r'client')
  LoginDtoClientEnum? get client;
  // enum clientEnum {  web,  android,  };

  LoginDto._();

  factory LoginDto([void updates(LoginDtoBuilder b)]) = _$LoginDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LoginDtoBuilder b) => b
      ..client = LoginDtoClientEnum.valueOf('web');

  @BuiltValueSerializer(custom: true)
  static Serializer<LoginDto> get serializer => _$LoginDtoSerializer();
}

class _$LoginDtoSerializer implements PrimitiveSerializer<LoginDto> {
  @override
  final Iterable<Type> types = const [LoginDto, _$LoginDto];

  @override
  final String wireName = r'LoginDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LoginDto object, {
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
    if (object.client != null) {
      yield r'client';
      yield serializers.serialize(
        object.client,
        specifiedType: const FullType(LoginDtoClientEnum),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    LoginDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required LoginDtoBuilder result,
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
        case r'client':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(LoginDtoClientEnum),
          ) as LoginDtoClientEnum?;
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
  LoginDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LoginDtoBuilder();
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

class LoginDtoClientEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'web')
  static const LoginDtoClientEnum web = _$loginDtoClientEnum_web;
  @BuiltValueEnumConst(wireName: r'android')
  static const LoginDtoClientEnum android = _$loginDtoClientEnum_android;

  static Serializer<LoginDtoClientEnum> get serializer => _$loginDtoClientEnumSerializer;

  const LoginDtoClientEnum._(String name): super(name);

  static BuiltSet<LoginDtoClientEnum> get values => _$loginDtoClientEnumValues;
  static LoginDtoClientEnum valueOf(String name) => _$loginDtoClientEnumValueOf(name);
}

