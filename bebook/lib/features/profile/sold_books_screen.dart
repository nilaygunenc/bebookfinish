import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';

class SoldBooksScreen extends StatefulWidget {
  const SoldBooksScreen({super.key});

  @override
  State<SoldBooksScreen> createState() => _SoldBooksScreenState();
}

class _SoldBooksScreenState extends State<SoldBooksScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> boughtBooks = [];  // Satın aldıklarım
  List<dynamic> mySoldBooks = [];  // Sattıklarım
  bool isLoading = true;
  int? userId;
  int _tabIndex = 0; // 0: Sattıklarım, 1: Satın Aldıklarım

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadSoldBooks();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadSoldBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_id');
    if (id == null) {
      setState(() => isLoading = false);
      return;
    }
    setState(() => userId = id);

    try {
      final responses = await Future.wait([
        http.get(Uri.parse("${ApiService.baseUrl}/my-sold-books/$id"))
            .timeout(const Duration(seconds: 15)),
        http.get(Uri.parse("${ApiService.baseUrl}/sold-books/$id"))
            .timeout(const Duration(seconds: 15)),
      ]);

      if (mounted) {
        setState(() {
          mySoldBooks = responses[0].statusCode == 200
              ? List<dynamic>.from(jsonDecode(responses[0].body))
              : [];
          boughtBooks = responses[1].statusCode == 200
              ? List<dynamic>.from(jsonDecode(responses[1].body))
              : [];
          isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      debugPrint("Satılan kitaplar hatası: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF5F0),
                    Color(0xFFF3F0FF),
                    Color(0xFFF5F5F7),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabs(),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryIndigo))
                      : _tabIndex == 0
                          ? _buildList(mySoldBooks, isSeller: true)
                          : _buildList(boughtBooks, isSeller: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.shadowSM,
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppTheme.primaryIndigo, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Kitap Geçmişim",
              style: AppTheme.textTheme.headlineMedium?.copyWith(
                color: AppTheme.primaryIndigo,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => isLoading = true);
              _loadSoldBooks();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.shadowSM,
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppTheme.primaryIndigo, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.shadowSM,
        ),
        child: Row(
          children: [
            _buildTab(0, "Sattıklarım", Icons.sell_rounded,
                mySoldBooks.length),
            _buildTab(1, "Satın Aldıklarım", Icons.shopping_bag_rounded,
                boughtBooks.length),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon, int count) {
    final isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _tabIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isActive ? Colors.white : AppTheme.neutralDark),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : AppTheme.neutralDark,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.3)
                        : AppTheme.primaryIndigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : AppTheme.primaryIndigo,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> books, {required bool isSeller}) {
    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSeller
                      ? Icons.sell_outlined
                      : Icons.shopping_bag_outlined,
                  size: 56,
                  color: AppTheme.primaryIndigo.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isSeller
                    ? "Henüz sattığın kitap yok"
                    : "Henüz satın aldığın kitap yok",
                style: AppTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: books.length,
        itemBuilder: (context, index) =>
            _buildCard(books[index], isSeller: isSeller),
      ),
    );
  }

  Widget _buildCard(dynamic book, {required bool isSeller}) {
    final orderDate = book['order_date'] != null
        ? DateTime.tryParse(book['order_date'])
        : null;
    final dateStr = orderDate != null
        ? "${orderDate.day.toString().padLeft(2, '0')}.${orderDate.month.toString().padLeft(2, '0')}.${orderDate.year}"
        : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.shadowMD,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Kitap görseli
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    book['image_path'] ?? '',
                    width: 65,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 65,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: isSeller
                            ? AppTheme.primaryGradient
                            : AppTheme.sunsetGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.book_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isSeller
                          ? AppTheme.primaryIndigo
                          : AppTheme.successGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      isSeller ? Icons.sell_rounded : Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Kitap bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    book['author'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: isSeller
                              ? AppTheme.primaryGradient
                              : AppTheme.sunsetGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${(book['paid_price'] ?? book['price'] ?? 0).toStringAsFixed(0)} ₺",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_rounded,
                            size: 10, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(dateStr,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 10)),
                      ],
                    ],
                  ),
                  // Satıcı için alıcı emaili göster
                  if (isSeller && book['buyer_email'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 11, color: Colors.grey),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            "Alıcı: ${book['buyer_email']}",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isSeller
                        ? AppTheme.primaryIndigo
                        : AppTheme.successGreen)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSeller
                    ? Icons.sell_rounded
                    : Icons.check_circle_rounded,
                color: isSeller
                    ? AppTheme.primaryIndigo
                    : AppTheme.successGreen,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
