//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_shopping_trip_dto.g.dart';

/// UpdateShoppingTripDto
///
/// Properties:
/// * [scheduledFor] - ISO 8601 replacement shopping date and time.
@BuiltValue()
abstract class UpdateShoppingTripDto implements Built<UpdateShoppingTripDto, UpdateShoppingTripDtoBuilder> {
  /// ISO 8601 replacement shopping date and time.
  @BuiltValueField(wireName: r'scheduledFor')
  String get scheduledFor;

  UpdateShoppingTripDto._();

  factory UpdateShoppingTripDto([void updates(UpdateShoppingTripDtoBuilder b)]) = _$UpdateShoppingTripDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateShoppingTripDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateShoppingTripDto> get serializer => _$UpdateShoppingTripDtoSerializer();
}

class _$UpdateShoppingTripDtoSerializer implements PrimitiveSerializer<UpdateShoppingTripDto> {
  @override
  final Iterable<Type> types = const [UpdateShoppingTripDto, _$UpdateShoppingTripDto];

  @override
  final String wireName = r'UpdateShoppingTripDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateShoppingTripDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'scheduledFor';
    yield serializers.serialize(
      object.scheduledFor,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateShoppingTripDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UpdateShoppingTripDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'scheduledFor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.scheduledFor = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpdateShoppingTripDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateShoppingTripDtoBuilder();
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

