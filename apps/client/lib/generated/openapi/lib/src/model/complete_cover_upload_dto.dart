//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'complete_cover_upload_dto.g.dart';

/// CompleteCoverUploadDto
///
/// Properties:
/// * [assetId] 
@BuiltValue()
abstract class CompleteCoverUploadDto implements Built<CompleteCoverUploadDto, CompleteCoverUploadDtoBuilder> {
  @BuiltValueField(wireName: r'assetId')
  String get assetId;

  CompleteCoverUploadDto._();

  factory CompleteCoverUploadDto([void updates(CompleteCoverUploadDtoBuilder b)]) = _$CompleteCoverUploadDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CompleteCoverUploadDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CompleteCoverUploadDto> get serializer => _$CompleteCoverUploadDtoSerializer();
}

class _$CompleteCoverUploadDtoSerializer implements PrimitiveSerializer<CompleteCoverUploadDto> {
  @override
  final Iterable<Type> types = const [CompleteCoverUploadDto, _$CompleteCoverUploadDto];

  @override
  final String wireName = r'CompleteCoverUploadDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CompleteCoverUploadDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'assetId';
    yield serializers.serialize(
      object.assetId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CompleteCoverUploadDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CompleteCoverUploadDtoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'assetId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.assetId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CompleteCoverUploadDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CompleteCoverUploadDtoBuilder();
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

