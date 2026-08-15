//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'join_household_dto.g.dart';

/// JoinHouseholdDto
///
/// Properties:
/// * [code] - Shareable household code.
@BuiltValue()
abstract class JoinHouseholdDto implements Built<JoinHouseholdDto, JoinHouseholdDtoBuilder> {
  /// Shareable household code.
  @BuiltValueField(wireName: r'code')
  String get code;

  JoinHouseholdDto._();

  factory JoinHouseholdDto([void updates(JoinHouseholdDtoBuilder b)]) = _$JoinHouseholdDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(JoinHouseholdDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<JoinHouseholdDto> get serializer => _$JoinHouseholdDtoSerializer();
}

class _$JoinHouseholdDtoSerializer implements PrimitiveSerializer<JoinHouseholdDto> {
  @override
  final Iterable<Type> types = const [JoinHouseholdDto, _$JoinHouseholdDto];

  @override
  final String wireName = r'JoinHouseholdDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    JoinHouseholdDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'code';
    yield serializers.serialize(
      object.code,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    JoinHouseholdDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required JoinHouseholdDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'code':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.code = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  JoinHouseholdDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = JoinHouseholdDtoBuilder();
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

