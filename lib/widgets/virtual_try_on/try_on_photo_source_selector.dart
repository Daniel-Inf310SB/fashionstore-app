import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class TryOnPhotoSourceSelector extends StatelessWidget {
  const TryOnPhotoSourceSelector({
    super.key,
    required this.disabled,
    required this.onGallery,
    required this.onCamera,
  });

  final bool disabled;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                disabled ? null : onGallery,
            icon: const Icon(
              Icons.photo_library_outlined,
            ),
            label:
                const Text('Subir foto'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                disabled ? null : onCamera,
            icon:
                const Icon(Icons.camera_alt_outlined),
            label:
                const Text('Tomar foto'),
          ),
        ),
      ],
    );
  }
}
