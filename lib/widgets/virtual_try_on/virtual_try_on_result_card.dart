import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/virtual_try_on.dart';

class VirtualTryOnResultCard extends StatelessWidget {
  const VirtualTryOnResultCard({
    super.key,
    required this.result,
    required this.onTryAnother,
  });

  final VirtualTryOnResult result;
  final VoidCallback onTryAnother;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color:
                    AppColors.primaryLight,
              ),
              SizedBox(width: 8),
              Text(
                'Resultado generado',
                style: TextStyle(
                  color:
                      AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.network(
                result.generatedImageUrl,
                fit: BoxFit.cover,
                loadingBuilder:
                    (
                      context,
                      child,
                      progress,
                    ) {
                  if (progress == null) {
                    return child;
                  }

                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                },
                errorBuilder:
                    (_, __, ___) =>
                        const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color:
                        AppColors.textMuted,
                    size: 54,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.message,
            style: const TextStyle(
              color:
                  AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              if (result.size != null &&
                  result.size!.isNotEmpty)
                _Tag(
                  text:
                      'Talla ${result.size}',
                ),
              if (result.color != null &&
                  result.color!.isNotEmpty)
                _Tag(
                  text:
                      'Color ${result.color}',
                ),
              if (result.sku.isNotEmpty)
                _Tag(
                  text:
                      'SKU ${result.sku}',
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTryAnother,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Probar otra foto',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            AppColors.surfaceLight,
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color:
              AppColors.textSecondary,
          fontSize: 10,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }
}
