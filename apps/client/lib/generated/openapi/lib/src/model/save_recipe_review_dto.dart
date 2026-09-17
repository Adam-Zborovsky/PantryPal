//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:pantrypal_api/src/model/review_ingredient_dto.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'save_recipe_review_dto.g.dart';

/// SaveRecipeReviewDto
///
/// Properties:
/// * [title] 
/// * [originalServings] 
/// * [yieldWording] 
/// * [ingredients] 
/// * [instructions] 
/// * [expectedRevision] 
@BuiltValue()
abstract class SaveRecipeReviewDto implements Built<SaveRecipeReviewDto, SaveRecipeReviewDtoBuilder> {
  @BuiltValueField(wireName: r'title')
  String get title;

  @BuiltValueField(wireName: r'originalServings')
  JsonObject? get originalServings;

  @BuiltValueField(wireName: r'yieldWording')
  JsonObject? get yieldWording;

  @BuiltValueField(wireName: r'ingredients')
  BuiltList<ReviewIngredientDto> get ingredients;

  @BuiltValueField(wireName: r'instructions')
  BuiltList<String> get instructions;

  @BuiltValueField(wireName: r'expectedRevision')
  String get expectedRevision;

  SaveRecipeReviewDto._();

  factory SaveRecipeReviewDto([void updates(SaveRecipeReviewDtoBuilder b)]) = _$SaveRecipeReviewDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SaveRecipeReviewDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SaveRecipeReviewDto> get serializer => _$SaveRecipeReviewDtoSerializer();
}

class _$SaveRecipeReviewDtoSerializer implements PrimitiveSerializer<SaveRecipeReviewDto> {
  @override
  final Iterable<Type> types = const [SaveRecipeReviewDto, _$SaveRecipeReviewDto];

  @override
  final String wireName = r'SaveRecipeReviewDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SaveRecipeReviewDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'title';
    yield serializers.serialize(
      object.title,
      specifiedType: const FullType(String),
    );
    if (object.originalServings != null) {
      yield r'originalServings';
      yield serializers.serialize(
        object.originalServings,
        specifiedType: const FullType(JsonObject),
      );
    }
    if (object.yieldWording != null) {
      yield r'yieldWording';
      yield serializers.serialize(
        object.yieldWording,
        specifiedType: const FullType(JsonObject),
      );
    }
    yield r'ingredients';
    yield serializers.serialize(
      object.ingredients,
      specifiedType: const FullType(BuiltList, [FullType(ReviewIngredientDto)]),
    );
    yield r'instructions';
    yield serializers.serialize(
      object.instructions,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
    yield r'expectedRevision';
    yield serializers.serialize(
      object.expectedRevision,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SaveRecipeReviewDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SaveRecipeReviewDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'title':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.title = valueDes;
          break;
        case r'originalServings':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(JsonObject),
          ) as JsonObject?;
          if (valueDes == null) continue;
          result.originalServings = valueDes;
          break;
        case r'yieldWording':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(JsonObject),
          ) as JsonObject?;
          if (valueDes == null) continue;
          result.yieldWording = valueDes;
          break;
        case r'ingredients':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ReviewIngredientDto)]),
          ) as BuiltList<ReviewIngredientDto>;
          result.ingredients.replace(valueDes);
          break;
        case r'instructions':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.instructions.replace(valueDes);
          break;
        case r'expectedRevision':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.expectedRevision = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SaveRecipeReviewDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SaveRecipeReviewDtoBuilder();
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

