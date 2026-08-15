//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_import_dto.g.dart';

/// CreateImportDto
///
/// Properties:
/// * [sourceKind] 
/// * [sourceInput] 
@BuiltValue()
abstract class CreateImportDto implements Built<CreateImportDto, CreateImportDtoBuilder> {
  @BuiltValueField(wireName: r'sourceKind')
  CreateImportDtoSourceKindEnum get sourceKind;
  // enum sourceKindEnum {  url,  text,  image,  audio,  video,  };

  @BuiltValueField(wireName: r'sourceInput')
  String get sourceInput;

  CreateImportDto._();

  factory CreateImportDto([void updates(CreateImportDtoBuilder b)]) = _$CreateImportDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateImportDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateImportDto> get serializer => _$CreateImportDtoSerializer();
}

class _$CreateImportDtoSerializer implements PrimitiveSerializer<CreateImportDto> {
  @override
  final Iterable<Type> types = const [CreateImportDto, _$CreateImportDto];

  @override
  final String wireName = r'CreateImportDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateImportDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'sourceKind';
    yield serializers.serialize(
      object.sourceKind,
      specifiedType: const FullType(CreateImportDtoSourceKindEnum),
    );
    yield r'sourceInput';
    yield serializers.serialize(
      object.sourceInput,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateImportDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CreateImportDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'sourceKind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(CreateImportDtoSourceKindEnum),
          ) as CreateImportDtoSourceKindEnum;
          result.sourceKind = valueDes;
          break;
        case r'sourceInput':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.sourceInput = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CreateImportDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateImportDtoBuilder();
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

class CreateImportDtoSourceKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'url')
  static const CreateImportDtoSourceKindEnum url = _$createImportDtoSourceKindEnum_url;
  @BuiltValueEnumConst(wireName: r'text')
  static const CreateImportDtoSourceKindEnum text = _$createImportDtoSourceKindEnum_text;
  @BuiltValueEnumConst(wireName: r'image')
  static const CreateImportDtoSourceKindEnum image = _$createImportDtoSourceKindEnum_image;
  @BuiltValueEnumConst(wireName: r'audio')
  static const CreateImportDtoSourceKindEnum audio = _$createImportDtoSourceKindEnum_audio;
  @BuiltValueEnumConst(wireName: r'video')
  static const CreateImportDtoSourceKindEnum video = _$createImportDtoSourceKindEnum_video;

  static Serializer<CreateImportDtoSourceKindEnum> get serializer => _$createImportDtoSourceKindEnumSerializer;

  const CreateImportDtoSourceKindEnum._(String name): super(name);

  static BuiltSet<CreateImportDtoSourceKindEnum> get values => _$createImportDtoSourceKindEnumValues;
  static CreateImportDtoSourceKindEnum valueOf(String name) => _$createImportDtoSourceKindEnumValueOf(name);
}

