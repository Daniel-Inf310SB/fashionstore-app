import 'package:flutter/material.dart';

import 'catalog_fashion_style.dart';
import '../../models/branch.dart';

/// Selector compartido. Usa una superficie clara propia para no heredar el
/// tema oscuro de la pantalla que abre el modal.
class BranchSelectorSheet extends StatefulWidget {
  const BranchSelectorSheet({
    super.key,
    required this.branches,
    required this.selectedBranchId,
  });

  final List<StoreBranch> branches;
  final int? selectedBranchId;

  @override
  State<BranchSelectorSheet> createState() => _BranchSelectorSheetState();
}

class _BranchSelectorSheetState extends State<BranchSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final filtered = widget.branches.where((branch) {
      if (query.isEmpty) return true;
      return branch.name.toLowerCase().contains(query) ||
          branch.city.name.toLowerCase().contains(query) ||
          branch.address.toLowerCase().contains(query);
    }).toList();

    return Material(
      color: CatalogFashionColors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: CatalogFashionColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ELIGE TU TIENDA',
                    style: TextStyle(
                      color: CatalogFashionColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Seleccionar sucursal',
                    style: TextStyle(
                      color: CatalogFashionColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Consulta las prendas disponibles en tu sucursal.',
                    style: TextStyle(
                      color: CatalogFashionColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _search = value),
                    cursorColor: CatalogFashionColors.primary,
                    style: const TextStyle(
                      color: CatalogFashionColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar ciudad o sucursal',
                      hintStyle: const TextStyle(
                        color: CatalogFashionColors.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: CatalogFashionColors.textPrimary,
                      ),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              icon: const Icon(Icons.close_rounded),
                              color: CatalogFashionColors.textPrimary,
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            ),
                      filled: true,
                      fillColor: CatalogFashionColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 14,
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        borderSide: BorderSide(
                          color: CatalogFashionColors.divider,
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        borderSide: BorderSide(
                          color: CatalogFashionColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: CatalogFashionColors.divider,
            ),
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 40,
                            color: CatalogFashionColors.textMuted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No encontramos sucursales',
                            style: TextStyle(
                              color: CatalogFashionColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Prueba con otra ciudad o nombre.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CatalogFashionColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: CatalogFashionColors.divider,
                      ),
                      itemBuilder: (context, index) {
                        final branch = filtered[index];
                        final selected =
                            widget.selectedBranchId == branch.id;
                        final description = [
                          branch.city.name,
                          branch.address,
                        ].where((part) => part.trim().isNotEmpty).join(' · ');

                        return InkWell(
                          onTap: () => Navigator.pop(context, branch),
                          child: Container(
                            color: selected
                                ? CatalogFashionColors.background
                                : CatalogFashionColors.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? CatalogFashionColors.primary
                                        : CatalogFashionColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.storefront_outlined,
                                    color: selected
                                        ? CatalogFashionColors.surface
                                        : CatalogFashionColors.textPrimary,
                                    size: 23,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        branch.name,
                                        style: const TextStyle(
                                          color: CatalogFashionColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          description,
                                          style: const TextStyle(
                                            color: CatalogFashionColors.textSecondary,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                      if (selected) ...[
                                        const SizedBox(height: 6),
                                        const Text(
                                          'SUCURSAL SELECCIONADA',
                                          style: TextStyle(
                                            color: CatalogFashionColors.success,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.chevron_right_rounded,
                                  color: selected
                                      ? CatalogFashionColors.success
                                      : CatalogFashionColors.textMuted,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
