class VirtualTryOnUsage {
  const VirtualTryOnUsage({
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
  });

  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;

  factory VirtualTryOnUsage.fromJson(
    Map<String, dynamic> json,
  ) {
    return VirtualTryOnUsage(
      inputTokens:
          (json['input_tokens'] as num?)?.toInt(),
      outputTokens:
          (json['output_tokens'] as num?)?.toInt(),
      totalTokens:
          (json['total_tokens'] as num?)?.toInt(),
    );
  }
}

class VirtualTryOnResult {
  const VirtualTryOnResult({
    required this.message,
    required this.productId,
    required this.variantId,
    required this.sku,
    required this.productName,
    required this.garmentImageUrl,
    required this.generatedImageUrl,
    this.color,
    this.size,
    this.generatedImagePublicId,
    this.generatedImageWidth,
    this.generatedImageHeight,
    this.outputFormat,
    this.outputContentType,
    this.usage,
  });

  final String message;
  final int productId;
  final int variantId;
  final String sku;
  final String productName;
  final String? color;
  final String? size;
  final String garmentImageUrl;
  final String generatedImageUrl;
  final String? generatedImagePublicId;
  final int? generatedImageWidth;
  final int? generatedImageHeight;
  final String? outputFormat;
  final String? outputContentType;
  final VirtualTryOnUsage? usage;

  factory VirtualTryOnResult.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawUsage = json['usage'];

    return VirtualTryOnResult(
      message: json['message']?.toString() ??
          'Prueba virtual generada.',
      productId:
          (json['product_id'] as num?)?.toInt() ?? 0,
      variantId:
          (json['variant_id'] as num?)?.toInt() ?? 0,
      sku: json['sku']?.toString() ?? '',
      productName:
          json['product_name']?.toString() ?? '',
      color: json['color']?.toString(),
      size: json['size']?.toString(),
      garmentImageUrl:
          json['garment_image_url']?.toString() ?? '',
      generatedImageUrl:
          json['generated_image_url']?.toString() ?? '',
      generatedImagePublicId:
          json['generated_image_public_id']?.toString(),
      generatedImageWidth:
          (json['generated_image_width'] as num?)?.toInt(),
      generatedImageHeight:
          (json['generated_image_height'] as num?)?.toInt(),
      outputFormat:
          json['output_format']?.toString(),
      outputContentType:
          json['output_content_type']?.toString(),
      usage: rawUsage is Map
          ? VirtualTryOnUsage.fromJson(
              Map<String, dynamic>.from(rawUsage),
            )
          : null,
    );
  }
}

class VirtualTryOnException implements Exception {
  const VirtualTryOnException(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
