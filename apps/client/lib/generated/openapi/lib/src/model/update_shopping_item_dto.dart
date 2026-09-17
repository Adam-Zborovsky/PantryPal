//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'update_shopping_item_dto.g.dart';

/// UpdateShoppingItemDto
///
/// Properties:
/// * [status] 
/// * [knownQuantity] 
/// * [unit] 
@BuiltValue()
abstract class UpdateShoppingItemDto implements Built<UpdateShoppingItemDto, UpdateShoppingItemDtoBuilder> {
  @BuiltValueField(wireName: r'status')
  UpdateShoppingItemDtoStatusEnum get status;
  // enum statusEnum {  NEED_TO_BUY,  CONFIRMED_AT_HOME,  CHECK_AGAIN,  PARTIALLY_AVAILABLE,  PURCHASED,  IGNORED,  };

  @BuiltValueField(wireName: r'knownQuantity')
  String? get knownQuantity;

  @BuiltValueField(wireName: r'unit')
  String? get unit;

  UpdateShoppingItemDto._();

  factory UpdateShoppingItemDto([void updates(UpdateShoppingItemDtoBuilder b)]) = _$UpdateShoppingItemDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UpdateShoppingItemDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UpdateShoppingItemDto> get serializer => _$UpdateShoppingItemDtoSerializer();
}

class _$UpdateShoppingItemDtoSerializer implements PrimitiveSerializer<UpdateShoppingItemDto> {
  @override
  final Iterable<Type> types = const [UpdateShoppingItemDto, _$UpdateShoppingItemDto];

  @override
  final String wireName = r'UpdateShoppingItemDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UpdateShoppingItemDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(UpdateShoppingItemDtoStatusEnum),
    );
    if (object.knownQuantity != null) {
      yield r'knownQuantity';
      yield serializers.serialize(
        object.knownQuantity,
        specifiedType: const FullType(String),
      );
    }
    if (object.unit != null) {
      yield r'unit';
      yield serializers.serialize(
        object.unit,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    UpdateShoppingItemDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UpdateShoppingItemDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(UpdateShoppingItemDtoStatusEnum),
          ) as UpdateShoppingItemDtoStatusEnum;
          result.status = valueDes;
          break;
        case r'knownQuantity':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.knownQuantity = valueDes;
          break;
        case r'unit':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.unit = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UpdateShoppingItemDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UpdateShoppingItemDtoBuilder();
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

class UpdateShoppingItemDtoStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'NEED_TO_BUY')
  static const UpdateShoppingItemDtoStatusEnum NEED_TO_BUY = _$updateShoppingItemDtoStatusEnum_NEED_TO_BUY;
  @BuiltValueEnumConst(wireName: r'CONFIRMED_AT_HOME')
  static const UpdateShoppingItemDtoStatusEnum CONFIRMED_AT_HOME = _$updateShoppingItemDtoStatusEnum_CONFIRMED_AT_HOME;
  @BuiltValueEnumConst(wireName: r'CHECK_AGAIN')
  static const UpdateShoppingItemDtoStatusEnum CHECK_AGAIN = _$updateShoppingItemDtoStatusEnum_CHECK_AGAIN;
  @BuiltValueEnumConst(wireName: r'PARTIALLY_AVAILABLE')
  static const UpdateShoppingItemDtoStatusEnum PARTIALLY_AVAILABLE = _$updateShoppingItemDtoStatusEnum_PARTIALLY_AVAILABLE;
  @BuiltValueEnumConst(wireName: r'PURCHASED')
  static const UpdateShoppingItemDtoStatusEnum PURCHASED = _$updateShoppingItemDtoStatusEnum_PURCHASED;
  @BuiltValueEnumConst(wireName: r'IGNORED')
  static const UpdateShoppingItemDtoStatusEnum IGNORED = _$updateShoppingItemDtoStatusEnum_IGNORED;

  static Serializer<UpdateShoppingItemDtoStatusEnum> get serializer => _$updateShoppingItemDtoStatusEnumSerializer;

  const UpdateShoppingItemDtoStatusEnum._(String name): super(name);

  static BuiltSet<UpdateShoppingItemDtoStatusEnum> get values => _$updateShoppingItemDtoStatusEnumValues;
  static UpdateShoppingItemDtoStatusEnum valueOf(String name) => _$updateShoppingItemDtoStatusEnumValueOf(name);
}

