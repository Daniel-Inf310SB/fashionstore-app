import 'package:flutter/material.dart';

import 'catalog_fashion_style.dart';
import '../../models/catalog_models.dart';

class CatalogFilterDrawer extends StatefulWidget {
  const CatalogFilterDrawer({
    super.key,
    required this.initialFilters,
    required this.metadata,
    required this.onApply,
    required this.onClear,
  });

  final CatalogFilterState initialFilters;
  final CatalogFilterMetadata? metadata;
  final ValueChanged<CatalogFilterState> onApply;
  final VoidCallback onClear;

  @override
  State<CatalogFilterDrawer> createState() =>
      _CatalogFilterDrawerState();
}

class _CatalogFilterDrawerState
    extends State<CatalogFilterDrawer> {
  late CatalogFilterState _filters;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _minPriceController = TextEditingController(
      text: _filters.minPrice == null
          ? ''
          : _formatNumber(_filters.minPrice!),
    );
    _maxPriceController = TextEditingController(
      text: _filters.maxPrice == null
          ? ''
          : _formatNumber(_filters.maxPrice!),
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.metadata;

    return Drawer(
      backgroundColor: CatalogFashionColors.background,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(
              height: 1,
              color: CatalogFashionColors.divider,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  _Section(
                    title: 'Categoría',
                    child: _ChoiceWrap(
                      values: metadata?.categories ?? const [],
                      selected: _filters.category,
                      onSelected: (value) {
                        setState(() {
                          _filters = _filters.copyWith(
                            category: value,
                            clearCategory: value == null,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Section(
                    title: 'Audiencia',
                    child: _ChoiceWrap(
                      values: metadata?.audiences ?? const [],
                      selected: _filters.audience,
                      onSelected: (value) {
                        setState(() {
                          _filters = _filters.copyWith(
                            audience: value,
                            clearAudience: value == null,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Section(
                    title: 'Colecciones',
                    child: _MerchandisingList(
                      items: metadata?.collections ?? const [],
                      selectedId: _filters.collectionId,
                      icon: Icons.style_rounded,
                      onSelected: (id) {
                        setState(() {
                          _filters = _filters.copyWith(
                            collectionId: id,
                            clearCollectionId: id == null,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Section(
                    title: 'Temporadas',
                    child: _MerchandisingList(
                      items: metadata?.seasons ?? const [],
                      selectedId: _filters.seasonId,
                      icon: Icons.calendar_month_rounded,
                      onSelected: (id) {
                        setState(() {
                          _filters = _filters.copyWith(
                            seasonId: id,
                            clearSeasonId: id == null,
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Section(
                    title: 'Promociones',
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _filters.onlyPromotions,
                          activeThumbColor: CatalogFashionColors.primary,
                          title: const Text(
                            'Solo productos en oferta',
                            style: TextStyle(
                              color: CatalogFashionColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Muestra cualquier promoción vigente',
                            style: TextStyle(
                              color: CatalogFashionColors.textSecondary,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _filters = _filters.copyWith(
                                onlyPromotions: value,
                                clearPromotionId: value,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        _MerchandisingList(
                          items: metadata?.promotions ?? const [],
                          selectedId: _filters.promotionId,
                          icon: Icons.local_offer_rounded,
                          onSelected: (id) {
                            setState(() {
                              _filters = _filters.copyWith(
                                promotionId: id,
                                clearPromotionId: id == null,
                                onlyPromotions:
                                    id == null && _filters.onlyPromotions,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Section(
                    title: 'Precio',
                    child: Row(
                      children: [
                        Expanded(
                          child: _PriceField(
                            controller: _minPriceController,
                            label: 'Desde',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PriceField(
                            controller: _maxPriceController,
                            label: 'Hasta',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _filters.inStock,
                    activeThumbColor: CatalogFashionColors.primary,
                    title: const Text(
                      'Solo con stock',
                      style: TextStyle(
                        color: CatalogFashionColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Oculta prendas agotadas',
                      style: TextStyle(
                        color: CatalogFashionColors.textSecondary,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _filters = _filters.copyWith(
                          inStock: value,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 22),
                  _Section(
                    title: 'Ordenar',
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          '${_filters.sortBy}:${_filters.sortOrder}',
                      dropdownColor: CatalogFashionColors.surface,
                      decoration: _inputDecoration(),
                      style: const TextStyle(
                        color: CatalogFashionColors.textPrimary,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'created_at:desc',
                          child: Text('Más recientes'),
                        ),
                        DropdownMenuItem(
                          value: 'name:asc',
                          child: Text('Nombre A–Z'),
                        ),
                        DropdownMenuItem(
                          value: 'name:desc',
                          child: Text('Nombre Z–A'),
                        ),
                        DropdownMenuItem(
                          value: 'price:asc',
                          child: Text('Precio: menor a mayor'),
                        ),
                        DropdownMenuItem(
                          value: 'price:desc',
                          child: Text('Precio: mayor a menor'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        final parts = value.split(':');
                        setState(() {
                          _filters = _filters.copyWith(
                            sortBy: parts.first,
                            sortOrder: parts.last,
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REFINAR RESULTADOS',
                  style: TextStyle(
                    color: CatalogFashionColors.primaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Filtros',
                  style: TextStyle(
                    color: CatalogFashionColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.close_rounded,
              color: CatalogFashionColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: CatalogFashionColors.surface,
        border: Border(
          top: BorderSide(color: CatalogFashionColors.divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _minPriceController.clear();
                _maxPriceController.clear();
                setState(() {
                  _filters = _filters.clearAll();
                });
                widget.onClear();
                Navigator.pop(context);
              },
              child: const Text('Limpiar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () {
                final minPrice =
                    double.tryParse(_minPriceController.text.trim());
                final maxPrice =
                    double.tryParse(_maxPriceController.text.trim());

                if (
                    minPrice != null &&
                    maxPrice != null &&
                    minPrice > maxPrice) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'El precio mínimo no puede superar al máximo.',
                      ),
                    ),
                  );
                  return;
                }

                final applied = _filters.copyWith(
                  minPrice: minPrice,
                  clearMinPrice: minPrice == null,
                  maxPrice: maxPrice,
                  clearMaxPrice: maxPrice == null,
                );

                widget.onApply(applied);
                Navigator.pop(context);
              },
              child: const Text('Aplicar filtros'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    return value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: CatalogFashionColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CatalogFashionColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CatalogFashionColors.primary),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: CatalogFashionColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const _EmptyFilterText();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final isSelected = selected == value;

        return ChoiceChip(
          label: Text(value),
          selected: isSelected,
          onSelected: (_) {
            onSelected(isSelected ? null : value);
          },
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : CatalogFashionColors.textSecondary,
          ),
          selectedColor: CatalogFashionColors.primary,
          backgroundColor: CatalogFashionColors.surface,
          side: const BorderSide(color: CatalogFashionColors.divider),
        );
      }).toList(),
    );
  }
}

class _MerchandisingList extends StatelessWidget {
  const _MerchandisingList({
    required this.items,
    required this.selectedId,
    required this.icon,
    required this.onSelected,
  });

  final List<CatalogMerchandisingOption> items;
  final int? selectedId;
  final IconData icon;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyFilterText();
    }

    return Column(
      children: items.map((item) {
        final selected = selectedId == item.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Material(
            color: selected
                ? CatalogFashionColors.primary.withValues(alpha: 0.14)
                : CatalogFashionColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                onSelected(selected ? null : item.id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? CatalogFashionColors.primary
                        : CatalogFashionColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: selected
                          ? CatalogFashionColors.primaryLight
                          : CatalogFashionColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          color: selected
                              ? CatalogFashionColors.textPrimary
                              : CatalogFashionColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${item.productCount}',
                      style: const TextStyle(
                        color: CatalogFashionColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),
      style: const TextStyle(
        color: CatalogFashionColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Bs ',
        labelStyle: const TextStyle(
          color: CatalogFashionColors.textSecondary,
        ),
        prefixStyle: const TextStyle(
          color: CatalogFashionColors.textSecondary,
        ),
        filled: true,
        fillColor: CatalogFashionColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CatalogFashionColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CatalogFashionColors.primary),
        ),
      ),
    );
  }
}

class _EmptyFilterText extends StatelessWidget {
  const _EmptyFilterText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Sin opciones disponibles.',
      style: TextStyle(
        color: CatalogFashionColors.textMuted,
        fontSize: 13,
      ),
    );
  }
}
