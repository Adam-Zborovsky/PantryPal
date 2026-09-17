//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'cook_again_dto.g.dart';

/// CookAgainDto
///
/// Properties:
/// * [cookingDate] - ISO 8601 cooking date and time for the new instance.
/// * [targetServings] - Target serving count. Defaults to the archived instance.
@BuiltValue()
abstract class CookAgainDto implements Built<CookAgainDto, CookAgainDtoBuilder> {
  /// ISO 8601 cooking date and time for the new instance.
  @BuiltValueField(wireName: r'cookingDate')
  String? get cookingDate;

  /// Target serving count. Defaults to the archived instance.
  @BuiltValueField(wireName: r'targetServings')
  String? get targetServings;

  CookAgainDto._();

  factory CookAgainDto([void updates(CookAgainDtoBuilder b)]) = _$CookAgainDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CookAgainDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CookAgainDto> get serializer => _$CookAgainDtoSerializer();
}

class _$CookAgainDtoSerializer implements PrimitiveSerializer<CookAgainDto> {
  @override
  final Iterable<Type> types = const [CookAgainDto, _$CookAgainDto];

  @override
  final String wireName = r'CookAgainDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CookAgainDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.cookingDate != null) {
      yield r'cookingDate';
      yield serializers.serialize(
        object.cookingDate,
        specifiedType: const FullType(String),
      );
    }
    if (object.targetServings != null) {
      yield r'targetServings';
      yield serializers.serialize(
        object.targetServings,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    CookAgainDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CookAgainDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'cookingDate':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.cookingDate = valueDes;
          break;
        case r'targetServings':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.targetServings = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CookAgainDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CookAgainDtoBuilder();
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

