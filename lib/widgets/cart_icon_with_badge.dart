import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state_management/cart_manager.dart';

class CartIconWithBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final double iconSize;

  const CartIconWithBadge({Key? key, this.onTap, this.iconSize = 28}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CartManager>(
      builder: (context, cartManager, child) {
        final totalItems = cartManager.totalItems;
        final primaryIconColor = Theme.of(context).colorScheme.onSurface;

        return InkWell(
          onTap: onTap ?? () => Scaffold.of(context).openEndDrawer(),
          borderRadius: BorderRadius.circular(100),
          child: Stack(
            alignment: Alignment.center,
            children: [
            IconButton(
                icon: Icon(Icons.shopping_bag_outlined, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
              if (totalItems > 0)
                Positioned(
                  right: 5,
                  top: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap ?? () => Scaffold.of(context).openEndDrawer(),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Center(
                          child: Text(
                            totalItems > 99 ? '99+' : totalItems.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
