//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'complete_media_upload_response_dto.g.dart';

/// CompleteMediaUploadResponseDto
///
/// Properties:
/// * [assetId] 
/// * [status] 
/// * [byteSize] 
@BuiltValue()
abstract class CompleteMediaUploadResponseDto implements Built<CompleteMediaUploadResponseDto, CompleteMediaUploadResponseDtoBuilder> {
  @BuiltValueField(wireName: r'assetId')
  String get assetId;

  @BuiltValueField(wireName: r'status')
  CompleteMediaUploadResponseDtoStatusEnum get status;
  // enum statusEnum {  READY,  };

  @BuiltValueField(wireName: r'byteSize')
  num get byteSize;

  CompleteMediaUploadResponseDto._();

  factory CompleteMediaUploadResponseDto([void updates(CompleteMediaUploadResponseDtoBuilder b)]) = _$CompleteMediaUploadResponseDto;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CompleteMediaUploadResponseDtoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CompleteMediaUploadResponseDto> get serializer => _$CompleteMediaUploadResponseDtoSerializer();
}

class _$CompleteMediaUploadResponseDtoSerializer implements PrimitiveSerializer<CompleteMediaUploadResponseDto> {
  @override
  final Iterable<Type> types = const [CompleteMediaUploadResponseDto, _$CompleteMediaUploadResponseDto];

  @override
  final String wireName = r'CompleteMediaUploadResponseDto';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CompleteMediaUploadResponseDto object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'assetId';
    yield serializers.serialize(
      object.assetId,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(CompleteMediaUploadResponseDtoStatusEnum),
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
    CompleteMediaUploadResponseDto object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CompleteMediaUploadResponseDtoBuilder result,
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
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(CompleteMediaUploadResponseDtoStatusEnum),
          ) as CompleteMediaUploadResponseDtoStatusEnum;
          result.status = valueDes;
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
  CompleteMediaUploadResponseDto deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CompleteMediaUploadResponseDtoBuilder();
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

class CompleteMediaUploadResponseDtoStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'READY')
  static const CompleteMediaUploadResponseDtoStatusEnum READY = _$completeMediaUploadResponseDtoStatusEnum_READY;

  static Serializer<CompleteMediaUploadResponseDtoStatusEnum> get serializer => _$completeMediaUploadResponseDtoStatusEnumSerializer;

  const CompleteMediaUploadResponseDtoStatusEnum._(String name): super(name);

  static BuiltSet<CompleteMediaUploadResponseDtoStatusEnum> get values => _$completeMediaUploadResponseDtoStatusEnumValues;
  static CompleteMediaUploadResponseDtoStatusEnum valueOf(String name) => _$completeMediaUploadResponseDtoStatusEnumValueOf(name);
}

