//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'refresh_dto.g.dart';

/// RefreshDto
///
/// Properties:
/// * [refreshToken] - Android-only refresh credential.
/// * [client] 
@BuiltValue()
abstract class RefreshDto implements Built<RefreshDto, RefreshDtoBuilder> {
  /// Android-only refresh credential.
  @BuiltValueField(wireName: r'refreshToken')
  String? get refreshToken;

  @BuiltValueField(wireName: r'client')
  RefreshDtoClientEnum? get client;
  // enum clientEnum {  web,  android,  };

  RefreshDto._();

  factory RefreshDto([void updates(RefreshDtoBuilder b)]) = _$RefreshDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RefreshDtoBuilder b) => b
      ..client = RefreshDtoClientEnum.valueOf('web');

  @BuiltValueSerializer(custom: true)
  static Serializer<RefreshDto> get serializer => _$RefreshDtoSerializer();
}

class _$RefreshDtoSerializer implements PrimitiveSerializer<RefreshDto> {
  @override
  final Iterable<Type> types = const [RefreshDto, _$RefreshDto];

  @override
  final String wireName = r'RefreshDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RefreshDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.refreshToken != null) {
      yield r'refreshToken';
      yield serializers.serialize(
        object.refreshToken,
        specifiedType: const FullType(String),
      );
    }
    if (object.client != null) {
      yield r'client';
      yield serializers.serialize(
        object.client,
        specifiedType: const FullType(RefreshDtoClientEnum),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    RefreshDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RefreshDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'refreshToken':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.refreshToken = valueDes;
          break;
        case r'client':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(RefreshDtoClientEnum),
          ) as RefreshDtoClientEnum?;
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
  RefreshDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RefreshDtoBuilder();
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

class RefreshDtoClientEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'web')
  static const RefreshDtoClientEnum web = _$refreshDtoClientEnum_web;
  @BuiltValueEnumConst(wireName: r'android')
  static const RefreshDtoClientEnum android = _$refreshDtoClientEnum_android;

  static Serializer<RefreshDtoClientEnum> get serializer => _$refreshDtoClientEnumSerializer;

  const RefreshDtoClientEnum._(String name): super(name);

  static BuiltSet<RefreshDtoClientEnum> get values => _$refreshDtoClientEnumValues;
  static RefreshDtoClientEnum valueOf(String name) => _$refreshDtoClientEnumValueOf(name);
}

