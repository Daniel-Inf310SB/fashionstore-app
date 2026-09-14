import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';


class CatalogScreen
    extends StatelessWidget {

  const CatalogScreen({
    super.key,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          70,
          20,
          16,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            const Text(
              'Catálogo',
              style: TextStyle(
                color:
                    AppColors.textPrimary,
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 20,
            ),


            // BUSCADOR

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),

              decoration:
                  BoxDecoration(
                color:
                    AppColors.surface,

                borderRadius:
                    BorderRadius.circular(
                  16,
                ),

                border:
                    Border.all(
                  color:
                      AppColors.divider,
                ),
              ),

              child: const TextField(
                style: TextStyle(
                  color:
                      AppColors.textPrimary,
                ),

                decoration:
                    InputDecoration(
                  border:
                      InputBorder.none,

                  icon:
                      Icon(
                    Icons.search,
                    color:
                        AppColors.textSecondary,
                  ),

                  hintText:
                      'Buscar prendas',

                  hintStyle:
                      TextStyle(
                    color:
                        AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),


            // FILTROS

            Row(
              children: [
                Expanded(
                  child:
                      _FilterButton(
                    label:
                        'Categoría',
                    icon:
                        Icons.category_outlined,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      _FilterButton(
                    label:
                        'Filtros',
                    icon:
                        Icons.tune_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),


            // PRODUCTOS

            Expanded(
              child:
                  GridView.builder(
                itemCount:
                    8,

                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      2,

                  crossAxisSpacing:
                      12,

                  mainAxisSpacing:
                      12,

                  childAspectRatio:
                      0.72,
                ),

                itemBuilder:
                    (
                  context,
                  index,
                ) {
                  return const _ProductCard();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _FilterButton
    extends StatelessWidget {

  final String label;
  final IconData icon;


  const _FilterButton({
    required this.label,
    required this.icon,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 48,

      decoration:
          BoxDecoration(
        color:
            AppColors.surface,

        borderRadius:
            BorderRadius.circular(
          14,
        ),

        border:
            Border.all(
          color:
              AppColors.divider,
        ),
      ),

      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          Icon(
            icon,
            color:
                AppColors.textSecondary,
          ),

          const SizedBox(
            width: 8,
          ),

          Text(
            label,
            style:
                const TextStyle(
              color:
                  AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}


class _ProductCard
    extends StatelessWidget {

  const _ProductCard();


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      decoration:
          BoxDecoration(
        color:
            AppColors.surface,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              AppColors.divider,
        ),
      ),

      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Expanded(
            child: Center(
              child: Icon(
                Icons.checkroom,
                color:
                    AppColors.textSecondary,
                size: 64,
              ),
            ),
          ),

          Padding(
            padding:
                EdgeInsets.all(
              12,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'Prenda FashionStore',
                  style:
                      TextStyle(
                    color:
                        AppColors.textPrimary,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(
                  height: 4,
                ),

                Text(
                  'Bs 199',
                  style:
                      TextStyle(
                    color:
                        AppColors.primary,
                    fontWeight:
                        FontWeight.bold,
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