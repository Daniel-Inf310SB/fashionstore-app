import 'package:flutter/material.dart';

// Barra de navegación monocromática, sin modificar índices ni callbacks.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const BottomNavBar({super.key, required this.currentIndex, required this.onTap});

  static const Color _ink = Color(0xFF141414);
  static const Color _muted = Color(0xFF888888);
  static const Color _line = Color(0xFFE9E9E9);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 7),
      child: Row(
        children: [
          _item(Icons.home_outlined, Icons.home_rounded, 'Inicio', 0),
          _item(Icons.checkroom_outlined, Icons.checkroom_rounded, 'Catálogo', 1),
          _item(Icons.event_note_outlined, Icons.event_note_rounded, 'Reservas', 2),
          _item(Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'Carrito', 3),
        ],
      ),
    );
  }

  Widget _item(IconData icon, IconData activeIcon, String label, int index) {
    final selected = currentIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          child: Semantics(
            selected: selected,
            label: label,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? activeIcon : icon, color: selected ? _ink : _muted, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? _ink : _muted,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(height: 2, width: 23, color: selected ? _ink : Colors.transparent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
