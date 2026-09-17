//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'upsert_push_subscription_dto.g.dart';

/// UpsertPushSubscriptionDto
///
/// Properties:
/// * [platform] 
/// * [endpoint] - Firebase Cloud Messaging registration token for this device.
@BuiltValue()
abstract class UpsertPushSubscriptionDto implements Built<UpsertPushSubscriptionDto, UpsertPushSubscriptionDtoBuilder> {
  @BuiltValueField(wireName: r'platform')
  UpsertPushSubscriptionDtoPlatformEnum get platform;
  // enum platformEnum {  android,  };

  /// Firebase Cloud Messaging registration token for this device.
  @BuiltValueField(wireName: r'endpoint')
  String get endpoint;

  UpsertPushSubscriptionDto._();

  factory UpsertPushSubscriptionDto([void updates(UpsertPushSubscriptionDtoBuilder b)]) = _$UpsertPushSubscriptionDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpsertPushSubscriptionDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpsertPushSubscriptionDto> get serializer => _$UpsertPushSubscriptionDtoSerializer();
}

class _$UpsertPushSubscriptionDtoSerializer implements PrimitiveSerializer<UpsertPushSubscriptionDto> {
  @override
  final Iterable<Type> types = const [UpsertPushSubscriptionDto, _$UpsertPushSubscriptionDto];

  @override
  final String wireName = r'UpsertPushSubscriptionDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpsertPushSubscriptionDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'platform';
    yield serializers.serialize(
      object.platform,
      specifiedType: const FullType(UpsertPushSubscriptionDtoPlatformEnum),
    );
    yield r'endpoint';
    yield serializers.serialize(
      object.endpoint,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpsertPushSubscriptionDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UpsertPushSubscriptionDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'platform':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(UpsertPushSubscriptionDtoPlatformEnum),
          ) as UpsertPushSubscriptionDtoPlatformEnum;
          result.platform = valueDes;
          break;
        case r'endpoint':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.endpoint = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpsertPushSubscriptionDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpsertPushSubscriptionDtoBuilder();
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

class UpsertPushSubscriptionDtoPlatformEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'android')
  static const UpsertPushSubscriptionDtoPlatformEnum android = _$upsertPushSubscriptionDtoPlatformEnum_android;

  static Serializer<UpsertPushSubscriptionDtoPlatformEnum> get serializer => _$upsertPushSubscriptionDtoPlatformEnumSerializer;

  const UpsertPushSubscriptionDtoPlatformEnum._(String name): super(name);

  static BuiltSet<UpsertPushSubscriptionDtoPlatformEnum> get values => _$upsertPushSubscriptionDtoPlatformEnumValues;
  static UpsertPushSubscriptionDtoPlatformEnum valueOf(String name) => _$upsertPushSubscriptionDtoPlatformEnumValueOf(name);
}

