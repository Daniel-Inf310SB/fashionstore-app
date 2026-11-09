import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../models/product_detail.dart';
import '../../models/virtual_try_on.dart';
import '../../services/virtual_try_on_permission_service.dart';
import '../../services/virtual_try_on_service.dart';
import '../../widgets/virtual_try_on/selected_person_photo_card.dart';
import '../../widgets/virtual_try_on/try_on_photo_source_selector.dart';
import '../../widgets/virtual_try_on/virtual_try_on_result_card.dart';

class VirtualTryOnScreen extends StatefulWidget {
  const VirtualTryOnScreen({
    super.key,
    required this.product,
    required this.variant,
  });

  final ProductDetail product;
  final ProductDetailVariant variant;

  @override
  State<VirtualTryOnScreen> createState() =>
      _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState
    extends State<VirtualTryOnScreen> {
  final ImagePicker _picker =
      ImagePicker();

  XFile? _selectedFile;
  VirtualTryOnResult? _result;

  bool _generating = false;
  String _errorMessage = '';

  String? get _garmentImage {
    final image =
        widget.variant.imageUrl?.trim();

    if (image != null &&
        image.isNotEmpty) {
      return image;
    }

    return widget.product
        .coverImageUrl
        ?.trim();
  }

  Future<void> _pickFromGallery() async {
    if (_generating) return;

    try {
      final file =
          await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );

      if (file == null) return;

      await _acceptFile(file);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'No pudimos abrir la galería.';
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_generating) return;

    final permission =
        await VirtualTryOnPermissionService
            .requestCamera();

    if (!mounted) return;

    if (!permission.isGranted) {
      if (permission.isPermanentlyDenied) {
        await _showCameraSettingsDialog();
      } else {
        setState(() {
          _errorMessage =
              'FashionStore necesita permiso de cámara para tomar tu foto. También puedes subir una imagen.';
        });
      }

      return;
    }

    try {
      final file =
          await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice:
            CameraDevice.front,
        imageQuality: 92,
        maxWidth: 1440,
      );

      if (file == null) return;

      await _acceptFile(file);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'No pudimos abrir la cámara. Puedes subir una foto desde la galería.';
      });
    }
  }

  Future<void> _acceptFile(
    XFile file,
  ) async {
    try {
      await VirtualTryOnService
          .validatePickedFile(file);

      if (!mounted) return;

      setState(() {
        _selectedFile = file;
        _result = null;
        _errorMessage = '';
      });
    } on VirtualTryOnException catch (
        error) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            error.message;
      });
    }
  }

  Future<void> _generate() async {
    final file = _selectedFile;

    if (file == null ||
        _generating) {
      return;
    }

    if (widget.variant.imageUrl
            ?.trim()
            .isEmpty !=
        false) {
      setState(() {
        _errorMessage =
            'Esta variante no tiene una imagen disponible para el probador.';
      });

      return;
    }

    setState(() {
      _generating = true;
      _result = null;
      _errorMessage = '';
    });

    try {
      final result =
          await VirtualTryOnService.generate(
        variantId:
            widget.variant.id,
        personImage: file,
      );

      if (!mounted) return;

      setState(() {
        _result = result;
      });
    } on VirtualTryOnException catch (
        error) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            error.message;
      });

      if (error.statusCode == 401) {
        Navigator.pop(
          context,
          'session_expired',
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'No pudimos generar la prueba virtual. Inténtalo nuevamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  Future<void>
      _showCameraSettingsDialog() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              AppColors.surface,
          title: const Text(
            'Permiso de cámara',
            style: TextStyle(
              color:
                  AppColors.textPrimary,
            ),
          ),
          content: const Text(
            'El permiso fue bloqueado. Puedes habilitar la cámara desde la configuración de FashionStore.',
            style: TextStyle(
              color:
                  AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child: const Text(
                'Abrir configuración',
              ),
            ),
          ],
        );
      },
    );

    if (open == true) {
      await VirtualTryOnPermissionService
          .openSystemSettings();
    }
  }

  void _clearPhoto() {
    if (_generating) return;

    setState(() {
      _selectedFile = null;
      _result = null;
      _errorMessage = '';
    });
  }

  void _tryAnother() {
    if (_generating) return;

    setState(() {
      _selectedFile = null;
      _result = null;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final garmentImage =
        _garmentImage;

    return Scaffold(
      backgroundColor:
          AppColors.background,
      appBar: AppBar(
        backgroundColor:
            AppColors.background,
        surfaceTintColor:
            Colors.transparent,
        title:
            const Text('Probador virtual'),
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            10,
            16,
            32,
          ),
          children: [
            const Text(
              'PROBADOR VIRTUAL 2D',
              style: TextStyle(
                color:
                    AppColors.primaryLight,
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pruébate esta prenda',
              style: TextStyle(
                color:
                    AppColors.textPrimary,
                fontSize: 27,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Toma o sube una foto de cuerpo completo. FashionStore enviará la foto y la variante seleccionada al motor de IA.',
              style: TextStyle(
                color:
                    AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _GarmentCard(
              product:
                  widget.product,
              variant:
                  widget.variant,
              imageUrl:
                  garmentImage,
            ),
            const SizedBox(height: 16),
            if (_result == null) ...[
              TryOnPhotoSourceSelector(
                disabled: _generating,
                onGallery:
                    _pickFromGallery,
                onCamera:
                    _takePhoto,
              ),
              const SizedBox(height: 14),
              if (_selectedFile != null)
                SelectedPersonPhotoCard(
                  file:
                      _selectedFile!,
                  disabled:
                      _generating,
                  onClear:
                      _clearPhoto,
                )
              else
                const _PhotoHelpCard(),
              if (_errorMessage
                  .isNotEmpty) ...[
                const SizedBox(height: 12),
                _ErrorCard(
                  message:
                      _errorMessage,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _selectedFile !=
                                  null &&
                              !_generating
                          ? _generate
                          : null,
                  icon: _generating
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .auto_awesome_rounded,
                        ),
                  label: Text(
                    _generating
                        ? 'Generando prueba...'
                        : 'Generar prueba virtual',
                  ),
                ),
              ),
            ] else ...[
              VirtualTryOnResultCard(
                result: _result!,
                onTryAnother:
                    _tryAnother,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GarmentCard extends StatelessWidget {
  const _GarmentCard({
    required this.product,
    required this.variant,
    required this.imageUrl,
  });

  final ProductDetail product;
  final ProductDetailVariant variant;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 96,
            clipBehavior:
                Clip.antiAlias,
            decoration: BoxDecoration(
              color:
                  AppColors.surfaceLight,
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: imageUrl != null &&
                    imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                            const Icon(
                      Icons
                          .checkroom_rounded,
                      color:
                          AppColors.textMuted,
                    ),
                  )
                : const Icon(
                    Icons
                        .checkroom_rounded,
                    color:
                        AppColors.textMuted,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    color:
                        AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Talla ${variant.size.name} · Color ${variant.color.name}',
                  style: const TextStyle(
                    color:
                        AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU ${variant.sku}',
                  style: const TextStyle(
                    color:
                        AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoHelpCard extends StatelessWidget {
  const _PhotoHelpCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            AppColors.surfaceLight,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.divider,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons
                .add_a_photo_outlined,
            color:
                AppColors.primaryLight,
            size: 40,
          ),
          SizedBox(height: 10),
          Text(
            'Selecciona tu foto',
            style: TextStyle(
              color:
                  AppColors.textPrimary,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'JPG, PNG o WEBP · máximo 10 MB. Para un mejor resultado usa buena iluminación y evita que otras personas aparezcan en la foto.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error
            .withValues(alpha: 0.09),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.error
              .withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color:
              AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}
