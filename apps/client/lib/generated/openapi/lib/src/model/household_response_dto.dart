//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'household_response_dto.g.dart';

/// HouseholdResponseDto
///
/// Properties:
/// * [id] 
/// * [name] 
/// * [timezone] 
@BuiltValue()
abstract class HouseholdResponseDto implements Built<HouseholdResponseDto, HouseholdResponseDtoBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'timezone')
  String get timezone;

  HouseholdResponseDto._();

  factory HouseholdResponseDto([void updates(HouseholdResponseDtoBuilder b)]) = _$HouseholdResponseDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(HouseholdResponseDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<HouseholdResponseDto> get serializer => _$HouseholdResponseDtoSerializer();
}

class _$HouseholdResponseDtoSerializer implements PrimitiveSerializer<HouseholdResponseDto> {
  @override
  final Iterable<Type> types = const [HouseholdResponseDto, _$HouseholdResponseDto];

  @override
  final String wireName = r'HouseholdResponseDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    HouseholdResponseDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'timezone';
    yield serializers.serialize(
      object.timezone,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    HouseholdResponseDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required HouseholdResponseDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'timezone':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.timezone = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  HouseholdResponseDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = HouseholdResponseDtoBuilder();
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

