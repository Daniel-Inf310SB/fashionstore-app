import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';

class SelectedPersonPhotoCard extends StatelessWidget {
  const SelectedPersonPhotoCard({
    super.key,
    required this.file,
    required this.disabled,
    required this.onClear,
  });

  final XFile file;
  final bool disabled;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.file(
                File(file.path),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) =>
                        const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color:
                        AppColors.textMuted,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color:
                    AppColors.primaryLight,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    disabled ? null : onClear,
                child: const Text(
                  'Cambiar',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
