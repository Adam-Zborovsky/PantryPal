//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'remove_push_subscription_dto.g.dart';

/// RemovePushSubscriptionDto
///
/// Properties:
/// * [endpoint] - Firebase Cloud Messaging registration token for this device.
@BuiltValue()
abstract class RemovePushSubscriptionDto implements Built<RemovePushSubscriptionDto, RemovePushSubscriptionDtoBuilder> {
  /// Firebase Cloud Messaging registration token for this device.
  @BuiltValueField(wireName: r'endpoint')
  String get endpoint;

  RemovePushSubscriptionDto._();

  factory RemovePushSubscriptionDto([void updates(RemovePushSubscriptionDtoBuilder b)]) = _$RemovePushSubscriptionDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RemovePushSubscriptionDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RemovePushSubscriptionDto> get serializer => _$RemovePushSubscriptionDtoSerializer();
}

class _$RemovePushSubscriptionDtoSerializer implements PrimitiveSerializer<RemovePushSubscriptionDto> {
  @override
  final Iterable<Type> types = const [RemovePushSubscriptionDto, _$RemovePushSubscriptionDto];

  @override
  final String wireName = r'RemovePushSubscriptionDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RemovePushSubscriptionDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'endpoint';
    yield serializers.serialize(
      object.endpoint,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RemovePushSubscriptionDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RemovePushSubscriptionDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
  RemovePushSubscriptionDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RemovePushSubscriptionDtoBuilder();
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

