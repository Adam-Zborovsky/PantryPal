//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_media_upload_dto.g.dart';

/// CreateMediaUploadDto
///
/// Properties:
/// * [kind] 
/// * [mimeType] 
/// * [byteSize] - Exact client-side byte count.
@BuiltValue()
abstract class CreateMediaUploadDto implements Built<CreateMediaUploadDto, CreateMediaUploadDtoBuilder> {
  @BuiltValueField(wireName: r'kind')
  CreateMediaUploadDtoKindEnum get kind;
  // enum kindEnum {  image,  };

  @BuiltValueField(wireName: r'mimeType')
  String get mimeType;

  /// Exact client-side byte count.
  @BuiltValueField(wireName: r'byteSize')
  num get byteSize;

  CreateMediaUploadDto._();

  factory CreateMediaUploadDto([void updates(CreateMediaUploadDtoBuilder b)]) = _$CreateMediaUploadDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateMediaUploadDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateMediaUploadDto> get serializer => _$CreateMediaUploadDtoSerializer();
}

class _$CreateMediaUploadDtoSerializer implements PrimitiveSerializer<CreateMediaUploadDto> {
  @override
  final Iterable<Type> types = const [CreateMediaUploadDto, _$CreateMediaUploadDto];

  @override
  final String wireName = r'CreateMediaUploadDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateMediaUploadDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(CreateMediaUploadDtoKindEnum),
    );
    yield r'mimeType';
    yield serializers.serialize(
      object.mimeType,
      specifiedType: const FullType(String),
    );
    yield r'byteSize';
    yield serializers.serialize(
      object.byteSize,
      specifiedType: const FullType(num),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateMediaUploadDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CreateMediaUploadDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(CreateMediaUploadDtoKindEnum),
          ) as CreateMediaUploadDtoKindEnum;
          result.kind = valueDes;
          break;
        case r'mimeType':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.mimeType = valueDes;
          break;
        case r'byteSize':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(num),
          ) as num;
          result.byteSize = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CreateMediaUploadDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateMediaUploadDtoBuilder();
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

class CreateMediaUploadDtoKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'image')
  static const CreateMediaUploadDtoKindEnum image = _$createMediaUploadDtoKindEnum_image;

  static Serializer<CreateMediaUploadDtoKindEnum> get serializer => _$createMediaUploadDtoKindEnumSerializer;

  const CreateMediaUploadDtoKindEnum._(String name): super(name);

  static BuiltSet<CreateMediaUploadDtoKindEnum> get values => _$createMediaUploadDtoKindEnumValues;
  static CreateMediaUploadDtoKindEnum valueOf(String name) => _$createMediaUploadDtoKindEnumValueOf(name);
}

