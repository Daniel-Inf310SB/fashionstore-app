import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          10,
          20,
          24,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // =========================
            // SALUDO
            // =========================

            const Text(
              'Hola 👋',
              style: TextStyle(
                color:
                    AppColors.textSecondary,
                fontSize: 16,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            const Text(
              'Descubre tu próximo estilo',
              style: TextStyle(
                color:
                    AppColors.textPrimary,
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 24,
            ),


            // =========================
            // BUSCADOR
            // =========================

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
                    Icons.search_rounded,
                    color:
                        AppColors.textSecondary,
                  ),

                  hintText:
                      'Buscar prendas...',

                  hintStyle:
                      TextStyle(
                    color:
                        AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 28,
            ),


            // =========================
            // CATEGORÍAS
            // =========================

            const Text(
              'Categorías',
              style: TextStyle(
                color:
                    AppColors.textPrimary,
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            SizedBox(
              height: 90,

              child: ListView(
                scrollDirection:
                    Axis.horizontal,

                children: const [
                  _CategoryItem(
                    icon:
                        Icons.checkroom_rounded,
                    label:
                        'Poleras',
                  ),

                  _CategoryItem(
                    icon:
                        Icons.dry_cleaning_rounded,
                    label:
                        'Camisas',
                  ),

                  _CategoryItem(
                    icon:
                        Icons.style_rounded,
                    label:
                        'Pantalones',
                  ),

                  _CategoryItem(
                    icon:
                        Icons.auto_awesome_rounded,
                    label:
                        'Nuevos',
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 28,
            ),


            // =========================
            // DESTACADOS
            // =========================

            const Text(
              'Productos destacados',
              style: TextStyle(
                color:
                    AppColors.textPrimary,
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            const _ProductPlaceholder(),

            const SizedBox(
              height: 28,
            ),


            // =========================
            // IA
            // =========================

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                20,
              ),

              decoration:
                  BoxDecoration(
                color:
                    AppColors.surface,

                borderRadius:
                    BorderRadius.circular(
                  20,
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
                  Icon(
                    Icons.auto_awesome,
                    color:
                        AppColors.primary,
                    size: 30,
                  ),

                  SizedBox(
                    height: 12,
                  ),

                  Text(
                    'Recomendaciones para ti',
                    style:
                        TextStyle(
                      color:
                          AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  SizedBox(
                    height: 6,
                  ),

                  Text(
                    'FashionStore podrá recomendarte prendas según tus preferencias.',
                    style:
                        TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CategoryItem
    extends StatelessWidget {

  final IconData icon;
  final String label;


  const _CategoryItem({
    required this.icon,
    required this.label,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 85,

      margin:
          const EdgeInsets.only(
        right: 12,
      ),

      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration:
                BoxDecoration(
              color:
                  AppColors.surface,

              shape:
                  BoxShape.circle,

              border:
                  Border.all(
                color:
                    AppColors.divider,
              ),
            ),

            child: Icon(
              icon,
              color:
                  AppColors.primary,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            label,
            style:
                const TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}


class _ProductPlaceholder
    extends StatelessWidget {

  const _ProductPlaceholder();


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 180,

      width:
          double.infinity,

      decoration:
          BoxDecoration(
        color:
            AppColors.surface,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              AppColors.divider,
        ),
      ),

      child: const Center(
        child: Text(
          'Aquí mostraremos productos',
          style:
              TextStyle(
            color:
                AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}