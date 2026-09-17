//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_cooking_instance_dto.g.dart';

/// CreateCookingInstanceDto
///
/// Properties:
/// * [recipeId] 
/// * [targetServings] - Desired serving count, encoded as a positive decimal.
/// * [cookingDate] - ISO 8601 cooking date and time. Omit for Quick Cook.
/// * [shoppingTripId] 
/// * [assignmentMode] 
@BuiltValue()
abstract class CreateCookingInstanceDto implements Built<CreateCookingInstanceDto, CreateCookingInstanceDtoBuilder> {
  @BuiltValueField(wireName: r'recipeId')
  String get recipeId;

  /// Desired serving count, encoded as a positive decimal.
  @BuiltValueField(wireName: r'targetServings')
  String get targetServings;

  /// ISO 8601 cooking date and time. Omit for Quick Cook.
  @BuiltValueField(wireName: r'cookingDate')
  String? get cookingDate;

  @BuiltValueField(wireName: r'shoppingTripId')
  String? get shoppingTripId;

  @BuiltValueField(wireName: r'assignmentMode')
  CreateCookingInstanceDtoAssignmentModeEnum? get assignmentMode;
  // enum assignmentModeEnum {  AUTOMATIC,  MANUAL,  };

  CreateCookingInstanceDto._();

  factory CreateCookingInstanceDto([void updates(CreateCookingInstanceDtoBuilder b)]) = _$CreateCookingInstanceDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateCookingInstanceDtoBuilder b) => b
      ..assignmentMode = CreateCookingInstanceDtoAssignmentModeEnum.valueOf('AUTOMATIC');

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateCookingInstanceDto> get serializer => _$CreateCookingInstanceDtoSerializer();
}

class _$CreateCookingInstanceDtoSerializer implements PrimitiveSerializer<CreateCookingInstanceDto> {
  @override
  final Iterable<Type> types = const [CreateCookingInstanceDto, _$CreateCookingInstanceDto];

  @override
  final String wireName = r'CreateCookingInstanceDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateCookingInstanceDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'recipeId';
    yield serializers.serialize(
      object.recipeId,
      specifiedType: const FullType(String),
    );
    yield r'targetServings';
    yield serializers.serialize(
      object.targetServings,
      specifiedType: const FullType(String),
    );
    if (object.cookingDate != null) {
      yield r'cookingDate';
      yield serializers.serialize(
        object.cookingDate,
        specifiedType: const FullType(String),
      );
    }
    if (object.shoppingTripId != null) {
      yield r'shoppingTripId';
      yield serializers.serialize(
        object.shoppingTripId,
        specifiedType: const FullType(String),
      );
    }
    if (object.assignmentMode != null) {
      yield r'assignmentMode';
      yield serializers.serialize(
        object.assignmentMode,
        specifiedType: const FullType(CreateCookingInstanceDtoAssignmentModeEnum),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateCookingInstanceDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CreateCookingInstanceDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'recipeId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.recipeId = valueDes;
          break;
        case r'targetServings':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.targetServings = valueDes;
          break;
        case r'cookingDate':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.cookingDate = valueDes;
          break;
        case r'shoppingTripId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.shoppingTripId = valueDes;
          break;
        case r'assignmentMode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(CreateCookingInstanceDtoAssignmentModeEnum),
          ) as CreateCookingInstanceDtoAssignmentModeEnum?;
          if (valueDes == null) continue;
          result.assignmentMode = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CreateCookingInstanceDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateCookingInstanceDtoBuilder();
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

class CreateCookingInstanceDtoAssignmentModeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'AUTOMATIC')
  static const CreateCookingInstanceDtoAssignmentModeEnum AUTOMATIC = _$createCookingInstanceDtoAssignmentModeEnum_AUTOMATIC;
  @BuiltValueEnumConst(wireName: r'MANUAL')
  static const CreateCookingInstanceDtoAssignmentModeEnum MANUAL = _$createCookingInstanceDtoAssignmentModeEnum_MANUAL;

  static Serializer<CreateCookingInstanceDtoAssignmentModeEnum> get serializer => _$createCookingInstanceDtoAssignmentModeEnumSerializer;

  const CreateCookingInstanceDtoAssignmentModeEnum._(String name): super(name);

  static BuiltSet<CreateCookingInstanceDtoAssignmentModeEnum> get values => _$createCookingInstanceDtoAssignmentModeEnumValues;
  static CreateCookingInstanceDtoAssignmentModeEnum valueOf(String name) => _$createCookingInstanceDtoAssignmentModeEnumValueOf(name);
}

