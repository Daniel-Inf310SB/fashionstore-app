import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/branch.dart';
import '../../../services/catalog service.dart';

/// Audiencias tal como están sembradas en el backend
/// (`Hombre`, `Mujer`, `Niño`, `Niña`, `Unisex`). No existe un
/// endpoint público de audiencias, así que se listan de forma fija;
/// si el backend agrega uno, conviene reemplazar esto por datos reales.
const List<String> kAudienceOptions = [
  'Hombre',
  'Mujer',
  'Niño',
  'Niña',
  'Unisex',
];

class CatalogFiltersSheet extends StatefulWidget {
  final StoreCatalogFilters initialFilters;
  final List<StoreBranch> branches;

  const CatalogFiltersSheet({
    super.key,
    required this.initialFilters,
    required this.branches,
  });

  @override
  State<CatalogFiltersSheet> createState() => _CatalogFiltersSheetState();
}

class _CatalogFiltersSheetState extends State<CatalogFiltersSheet> {
  late String? _audience;
  late final TextEditingController _categoryController;
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;
  late bool? _promotion;
  late bool? _inStock;
  late int? _branchId;
  late CatalogSortBy _sortBy;
  late String _sortOrder;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilters;

    _audience = f.audience;
    _categoryController = TextEditingController(text: f.category ?? '');
    _minPriceController = TextEditingController(
      text: f.minPrice != null ? '${f.minPrice}' : '',
    );
    _maxPriceController = TextEditingController(
      text: f.maxPrice != null ? '${f.maxPrice}' : '',
    );
    _promotion = f.promotion;
    _inStock = f.inStock;
    _branchId = f.branchId;
    _sortBy = f.sortBy;
    _sortOrder = f.sortOrder;
  }

  void _apply() {
    final minPrice = double.tryParse(_minPriceController.text.trim());
    final maxPrice = double.tryParse(_maxPriceController.text.trim());
    final category = _categoryController.text.trim();

    final result = StoreCatalogFilters(
      search: widget.initialFilters.search,
      audience: _audience,
      category: category.isEmpty ? null : category,
      minPrice: minPrice,
      maxPrice: maxPrice,
      promotion: _promotion,
      inStock: _inStock,
      branchId: _branchId,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
    );

    Navigator.pop(context, result);
  }

  void _clearAll() {
    Navigator.pop(context, const StoreCatalogFilters());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text('Limpiar todo'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Audiencia',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kAudienceOptions.map((option) {
                  final selected = _audience == option;
                  return ChoiceChip(
                    label: Text(option),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _audience = selected ? null : option);
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceLight,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _categoryController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Categoría (ej. Camisas)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio mín.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio máx.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                title: const Text(
                  'Solo con promoción',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                value: _promotion ?? false,
                onChanged: (v) => setState(() => _promotion = v ? true : null),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                title: const Text(
                  'Solo con stock disponible',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                value: _inStock ?? false,
                onChanged: (v) => setState(() => _inStock = v ? true : null),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sucursal',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                value: _branchId,
                dropdownColor: AppColors.surfaceLight,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Todas las sucursales',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Todas las sucursales'),
                  ),
                  ...widget.branches.map(
                        (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text('${b.name} · ${b.city.name}'),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _branchId = v),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ordenar por',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<CatalogSortBy>(
                      value: _sortBy,
                      dropdownColor: AppColors.surfaceLight,
                      style: const TextStyle(color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem(
                          value: CatalogSortBy.name,
                          child: Text('Nombre'),
                        ),
                        DropdownMenuItem(
                          value: CatalogSortBy.price,
                          child: Text('Precio'),
                        ),
                        DropdownMenuItem(
                          value: CatalogSortBy.createdAt,
                          child: Text('Más recientes'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _sortBy = v ?? _sortBy),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sortOrder,
                      dropdownColor: AppColors.surfaceLight,
                      style: const TextStyle(color: AppColors.textPrimary),
                      items: const [
                        DropdownMenuItem(
                          value: 'asc',
                          child: Text('Ascendente'),
                        ),
                        DropdownMenuItem(
                          value: 'desc',
                          child: Text('Descendente'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _sortOrder = v ?? _sortOrder),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Aplicar filtros'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}