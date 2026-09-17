//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_shopping_trip_dto.g.dart';

/// CreateShoppingTripDto
///
/// Properties:
/// * [scheduledFor] - ISO 8601 planned shopping date and time.
@BuiltValue()
abstract class CreateShoppingTripDto implements Built<CreateShoppingTripDto, CreateShoppingTripDtoBuilder> {
  /// ISO 8601 planned shopping date and time.
  @BuiltValueField(wireName: r'scheduledFor')
  String? get scheduledFor;

  CreateShoppingTripDto._();

  factory CreateShoppingTripDto([void updates(CreateShoppingTripDtoBuilder b)]) = _$CreateShoppingTripDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateShoppingTripDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateShoppingTripDto> get serializer => _$CreateShoppingTripDtoSerializer();
}

class _$CreateShoppingTripDtoSerializer implements PrimitiveSerializer<CreateShoppingTripDto> {
  @override
  final Iterable<Type> types = const [CreateShoppingTripDto, _$CreateShoppingTripDto];

  @override
  final String wireName = r'CreateShoppingTripDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateShoppingTripDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.scheduledFor != null) {
      yield r'scheduledFor';
      yield serializers.serialize(
        object.scheduledFor,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateShoppingTripDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CreateShoppingTripDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'scheduledFor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
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
  CreateShoppingTripDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateShoppingTripDtoBuilder();
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

