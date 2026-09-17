//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'review_ingredient_dto.g.dart';

/// ReviewIngredientDto
///
/// Properties:
/// * [name] 
/// * [quantityMin] 
/// * [quantityMax] 
/// * [originalUnit] 
/// * [preparationNote] 
/// * [classification] 
/// * [includeInShopping] 
@BuiltValue()
abstract class ReviewIngredientDto implements Built<ReviewIngredientDto, ReviewIngredientDtoBuilder> {
  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'quantityMin')
  JsonObject? get quantityMin;

  @BuiltValueField(wireName: r'quantityMax')
  JsonObject? get quantityMax;

  @BuiltValueField(wireName: r'originalUnit')
  JsonObject? get originalUnit;

  @BuiltValueField(wireName: r'preparationNote')
  JsonObject? get preparationNote;

  @BuiltValueField(wireName: r'classification')
  ReviewIngredientDtoClassificationEnum get classification;
  // enum classificationEnum {  REQUIRED,  FLEXIBLE,  PANTRY_STAPLE,  GARNISH,  };

  @BuiltValueField(wireName: r'includeInShopping')
  bool get includeInShopping;

  ReviewIngredientDto._();

  factory ReviewIngredientDto([void updates(ReviewIngredientDtoBuilder b)]) = _$ReviewIngredientDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ReviewIngredientDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ReviewIngredientDto> get serializer => _$ReviewIngredientDtoSerializer();
}

class _$ReviewIngredientDtoSerializer implements PrimitiveSerializer<ReviewIngredientDto> {
  @override
  final Iterable<Type> types = const [ReviewIngredientDto, _$ReviewIngredientDto];

  @override
  final String wireName = r'ReviewIngredientDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ReviewIngredientDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    if (object.quantityMin != null) {
      yield r'quantityMin';
      yield serializers.serialize(
        object.quantityMin,
        specifiedType: const FullType(JsonObject),
      );
    }
    if (object.quantityMax != null) {
      yield r'quantityMax';
      yield serializers.serialize(
        object.quantityMax,
        specifiedType: const FullType(JsonObject),
      );
    }
    if (object.originalUnit != null) {
      yield r'originalUnit';
      yield serializers.serialize(
        object.originalUnit,
        specifiedType: const FullType(JsonObject),
      );
    }
    if (object.preparationNote != null) {
      yield r'preparationNote';
      yield serializers.serialize(
        object.preparationNote,
        specifiedType: const FullType(JsonObject),
      );
    }
    yield r'classification';
    yield serializers.serialize(
      object.classification,
      specifiedType: const FullType(ReviewIngredientDtoClassificationEnum),
    );
    yield r'includeInShopping';
    yield serializers.serialize(
      object.includeInShopping,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ReviewIngredientDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ReviewIngredientDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'quantityMin':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(JsonObject),
          ) as JsonObject?;
          if (valueDes == null) continue;
          result.quantityMin = valueDes;
          break;
        case r'quantityMax':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(JsonObject),
          ) as JsonObject?;
          if (valueDes == null) continue;
          result.quantityMax = valueDes;
          break;
        case r'originalUnit':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(JsonObject),
          ) as JsonObject?;
          if (valueDes == null) continue;
          result.originalUnit = valueDes;
          break;
        case r'preparationNote':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(JsonObject),
          ) as JsonObject?;
          if (valueDes == null) continue;
          result.preparationNote = valueDes;
          break;
        case r'classification':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ReviewIngredientDtoClassificationEnum),
          ) as ReviewIngredientDtoClassificationEnum;
          result.classification = valueDes;
          break;
        case r'includeInShopping':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.includeInShopping = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ReviewIngredientDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ReviewIngredientDtoBuilder();
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

class ReviewIngredientDtoClassificationEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'REQUIRED')
  static const ReviewIngredientDtoClassificationEnum REQUIRED = _$reviewIngredientDtoClassificationEnum_REQUIRED;
  @BuiltValueEnumConst(wireName: r'FLEXIBLE')
  static const ReviewIngredientDtoClassificationEnum FLEXIBLE = _$reviewIngredientDtoClassificationEnum_FLEXIBLE;
  @BuiltValueEnumConst(wireName: r'PANTRY_STAPLE')
  static const ReviewIngredientDtoClassificationEnum PANTRY_STAPLE = _$reviewIngredientDtoClassificationEnum_PANTRY_STAPLE;
  @BuiltValueEnumConst(wireName: r'GARNISH')
  static const ReviewIngredientDtoClassificationEnum GARNISH = _$reviewIngredientDtoClassificationEnum_GARNISH;

  static Serializer<ReviewIngredientDtoClassificationEnum> get serializer => _$reviewIngredientDtoClassificationEnumSerializer;

  const ReviewIngredientDtoClassificationEnum._(String name): super(name);

  static BuiltSet<ReviewIngredientDtoClassificationEnum> get values => _$reviewIngredientDtoClassificationEnumValues;
  static ReviewIngredientDtoClassificationEnum valueOf(String name) => _$reviewIngredientDtoClassificationEnumValueOf(name);
}

