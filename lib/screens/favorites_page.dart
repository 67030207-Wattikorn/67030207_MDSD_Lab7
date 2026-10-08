import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../repositories/favorites_repository.dart';

class FavoritesPage extends StatefulWidget {
  final FavoritesRepository repository;

  const FavoritesPage({
    super.key,
    required this.repository,
  });

  @override
  State<FavoritesPage> createState() =>
      _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<FavoriteItem>> _favoritesFuture;

  @override
  void initState() {
    super.initState();

    _loadFavorites();
  }

  void _loadFavorites() {
    _favoritesFuture =
        widget.repository.getAllFavorites();
  }

  Future<void> _removeFavorite(int itemId) async {
    await widget.repository.removeFavorite(itemId);

    setState(() {
      _loadFavorites();
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ลบออกจากรายการโปรดแล้ว'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการโปรด'),
      ),

      body: FutureBuilder<List<FavoriteItem>>(
        future: _favoritesFuture,

        builder: (context, snapshot) {
          // กำลังโหลด
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // เกิด Error
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'เกิดข้อผิดพลาด: ${snapshot.error}',
              ),
            );
          }

          final favorites =
              snapshot.data ?? [];

          // ไม่มีรายการโปรด
          if (favorites.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'ยังไม่มีรายการโปรด',
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          // แสดงรายการโปรด
          return ListView.builder(
            itemCount: favorites.length,

            itemBuilder: (context, index) {
              final favorite =
                  favorites[index];

              return ListTile(
                leading: Image.network(
                  favorite.imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,

                  errorBuilder:
                      (context, error, stackTrace) {
                    return const Icon(
                      Icons.broken_image,
                      size: 40,
                    );
                  },
                ),

                title: Text(
                  favorite.title,
                ),

                subtitle: Text(
                  '${favorite.price} บาท',
                ),

                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                  ),

                  onPressed: () {
                    _removeFavorite(
                      favorite.itemId,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}