//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_cover_upload_dto.g.dart';

/// CreateCoverUploadDto
///
/// Properties:
/// * [mimeType] 
/// * [byteSize] - Exact client-side byte count.
@BuiltValue()
abstract class CreateCoverUploadDto implements Built<CreateCoverUploadDto, CreateCoverUploadDtoBuilder> {
  @BuiltValueField(wireName: r'mimeType')
  String get mimeType;

  /// Exact client-side byte count.
  @BuiltValueField(wireName: r'byteSize')
  num get byteSize;

  CreateCoverUploadDto._();

  factory CreateCoverUploadDto([void updates(CreateCoverUploadDtoBuilder b)]) = _$CreateCoverUploadDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateCoverUploadDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateCoverUploadDto> get serializer => _$CreateCoverUploadDtoSerializer();
}

class _$CreateCoverUploadDtoSerializer implements PrimitiveSerializer<CreateCoverUploadDto> {
  @override
  final Iterable<Type> types = const [CreateCoverUploadDto, _$CreateCoverUploadDto];

  @override
  final String wireName = r'CreateCoverUploadDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateCoverUploadDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
    CreateCoverUploadDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CreateCoverUploadDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
  CreateCoverUploadDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateCoverUploadDtoBuilder();
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

