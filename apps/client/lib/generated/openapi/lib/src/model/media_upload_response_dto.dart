//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'media_upload_response_dto.g.dart';

/// MediaUploadResponseDto
///
/// Properties:
/// * [assetId] 
/// * [uploadUrl] - Short-lived signed PUT URL. Treat as a secret.
/// * [uploadExpiresAt] 
/// * [assetExpiresAt] 
@BuiltValue()
abstract class MediaUploadResponseDto implements Built<MediaUploadResponseDto, MediaUploadResponseDtoBuilder> {
  @BuiltValueField(wireName: r'assetId')
  String get assetId;

  /// Short-lived signed PUT URL. Treat as a secret.
  @BuiltValueField(wireName: r'uploadUrl')
  String get uploadUrl;

  @BuiltValueField(wireName: r'uploadExpiresAt')
  DateTime get uploadExpiresAt;

  @BuiltValueField(wireName: r'assetExpiresAt')
  DateTime get assetExpiresAt;

  MediaUploadResponseDto._();

  factory MediaUploadResponseDto([void updates(MediaUploadResponseDtoBuilder b)]) = _$MediaUploadResponseDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(MediaUploadResponseDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<MediaUploadResponseDto> get serializer => _$MediaUploadResponseDtoSerializer();
}

class _$MediaUploadResponseDtoSerializer implements PrimitiveSerializer<MediaUploadResponseDto> {
  @override
  final Iterable<Type> types = const [MediaUploadResponseDto, _$MediaUploadResponseDto];

  @override
  final String wireName = r'MediaUploadResponseDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    MediaUploadResponseDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'assetId';
    yield serializers.serialize(
      object.assetId,
      specifiedType: const FullType(String),
    );
    yield r'uploadUrl';
    yield serializers.serialize(
      object.uploadUrl,
      specifiedType: const FullType(String),
    );
    yield r'uploadExpiresAt';
    yield serializers.serialize(
      object.uploadExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'assetExpiresAt';
    yield serializers.serialize(
      object.assetExpiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    MediaUploadResponseDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required MediaUploadResponseDtoBuilder result,
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
        case r'uploadUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.uploadUrl = valueDes;
          break;
        case r'uploadExpiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.uploadExpiresAt = valueDes;
          break;
        case r'assetExpiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.assetExpiresAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  MediaUploadResponseDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MediaUploadResponseDtoBuilder();
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

