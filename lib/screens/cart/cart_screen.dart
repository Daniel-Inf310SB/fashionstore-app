import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';


class CartScreen
    extends StatelessWidget {

  const CartScreen({
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
              'Carrito',
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

            Expanded(
              child: ListView(
                children:
                    const [
                  _CartItem(),
                  _CartItem(),
                ],
              ),
            ),


            // =========================
            // TOTAL
            // =========================

            Container(
              padding:
                  const EdgeInsets.all(
                18,
              ),

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

              child: Column(
                children: [

                  const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,

                    children: [
                      Text(
                        'Total',
                        style:
                            TextStyle(
                          color:
                              AppColors.textSecondary,
                          fontSize:
                              16,
                        ),
                      ),

                      Text(
                        'Bs 398',
                        style:
                            TextStyle(
                          color:
                              AppColors.textPrimary,
                          fontSize:
                              22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  SizedBox(
                    width:
                        double.infinity,

                    child:
                        ElevatedButton(
                      onPressed:
                          () {},

                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.primary,

                        padding:
                            const EdgeInsets.symmetric(
                          vertical:
                              16,
                        ),

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),

                      child:
                          const Text(
                        'Continuar compra',
                      ),
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


class _CartItem
    extends StatelessWidget {

  const _CartItem();


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),

      padding:
          const EdgeInsets.all(
        14,
      ),

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

      child: const Row(
        children: [

          SizedBox(
            width: 70,
            height: 90,

            child: Icon(
              Icons.checkroom,
              color:
                  AppColors.textSecondary,
              size: 48,
            ),
          ),

          SizedBox(
            width: 14,
          ),

          Expanded(
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
                  height: 6,
                ),

                Text(
                  'Talla M · Negro',
                  style:
                      TextStyle(
                    color:
                        AppColors.textSecondary,
                  ),
                ),

                SizedBox(
                  height: 8,
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

          Icon(
            Icons.delete_outline,
            color:
                AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}