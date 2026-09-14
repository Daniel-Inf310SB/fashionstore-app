import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';


class ReservationsScreen
    extends StatelessWidget {

  const ReservationsScreen({
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
              'Mis reservas',
              style: TextStyle(
                color:
                    AppColors.textPrimary,
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Prendas reservadas para probar en sucursal.',
              style: TextStyle(
                color:
                    AppColors.textSecondary,
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            Expanded(
              child: ListView(
                children:
                    const [
                  _ReservationCard(
                    status:
                        'Pendiente',
                  ),

                  _ReservationCard(
                    status:
                        'Preparada',
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


class _ReservationCard
    extends StatelessWidget {

  final String status;


  const _ReservationCard({
    required this.status,
  });


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
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

            children: [
              const Text(
                'Reserva #001',
                style: TextStyle(
                  color:
                      AppColors.textPrimary,
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              Text(
                status,
                style:
                    const TextStyle(
                  color:
                      AppColors.primary,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            'Sucursal: Centro',
            style: TextStyle(
              color:
                  AppColors.textSecondary,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            '3 prendas reservadas',
            style: TextStyle(
              color:
                  AppColors.textSecondary,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            'Horario: 15:00',
            style: TextStyle(
              color:
                  AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}