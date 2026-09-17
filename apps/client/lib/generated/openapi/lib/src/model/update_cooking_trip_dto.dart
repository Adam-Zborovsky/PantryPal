//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_cooking_trip_dto.g.dart';

/// UpdateCookingTripDto
///
/// Properties:
/// * [shoppingTripId] 
@BuiltValue()
abstract class UpdateCookingTripDto implements Built<UpdateCookingTripDto, UpdateCookingTripDtoBuilder> {
  @BuiltValueField(wireName: r'shoppingTripId')
  String? get shoppingTripId;

  UpdateCookingTripDto._();

  factory UpdateCookingTripDto([void updates(UpdateCookingTripDtoBuilder b)]) = _$UpdateCookingTripDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateCookingTripDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateCookingTripDto> get serializer => _$UpdateCookingTripDtoSerializer();
}

class _$UpdateCookingTripDtoSerializer implements PrimitiveSerializer<UpdateCookingTripDto> {
  @override
  final Iterable<Type> types = const [UpdateCookingTripDto, _$UpdateCookingTripDto];

  @override
  final String wireName = r'UpdateCookingTripDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateCookingTripDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'shoppingTripId';
    yield object.shoppingTripId == null ? null : serializers.serialize(
      object.shoppingTripId,
      specifiedType: const FullType.nullable(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateCookingTripDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UpdateCookingTripDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'shoppingTripId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.shoppingTripId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpdateCookingTripDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateCookingTripDtoBuilder();
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

