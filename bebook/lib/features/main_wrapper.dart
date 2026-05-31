import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bebook/features/cart/premium_cart_screen.dart';
import 'package:bebook/features/home/premium_home_screen.dart';
import 'package:bebook/features/post_ad/add_product_screen.dart';
import 'package:bebook/features/profile/profile_screen.dart';
import 'package:bebook/features/chat/chat_list_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/api_service.dart';

// Global notifier'lar
final ValueNotifier<bool> logoutNotifier = ValueNotifier(false);
final ValueNotifier<int> favoriteChangeNotifier = ValueNotifier(0);

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => MainWrapperState();
}

class MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  int? _currentUserId;
  String? _currentUserEmail;
  int _unreadCount = 0;
  Timer? _badgeTimer;

  final GlobalKey<ProfileScreenState> _profileKey =
      GlobalKey<ProfileScreenState>();
  final GlobalKey<PremiumHomeScreenState> _homeKey =
      GlobalKey<PremiumHomeScreenState>();

  @override
  void initState() {
    super.initState();
    _loadUser();
    logoutNotifier.addListener(_onLogout);

    // Her 5 saniyede okunmamış mesaj sayısını kontrol et ve kullanıcıyı güncelle
    _badgeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadUser(); // Login/logout durumunu da günceller
    });
  }

  @override
  void dispose() {
    logoutNotifier.removeListener(_onLogout);
    _badgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final newUserId = prefs.getInt('user_id');
    final newEmail = prefs.getString('user_email');
    
    if (mounted) {
      // Sadece değişiklik varsa setState çağır
      if (newUserId != _currentUserId || newEmail != _currentUserEmail) {
        setState(() {
          _currentUserId = newUserId;
          _currentUserEmail = newEmail;
        });
        // Kullanıcı değiştiyse home screen'i de yenile
        if (newUserId != null && newUserId > 0) {
          _homeKey.currentState?.refreshAfterLogin();
        }
      }
    }
    _checkUnreadMessages();
  }

  void _onLogout() {
    if (logoutNotifier.value) {
      setState(() {
        _unreadCount = 0;
      });
      _loadUser();
    }
  }

  Future<void> _checkUnreadMessages() async {
    final userId = _currentUserId;
    if (userId == null || userId == 0) return;

    try {
      final response = await http
          .get(Uri.parse("${ApiService.baseUrl}/chats/$userId"))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> chats = jsonDecode(response.body);
        int total = 0;
        for (final chat in chats) {
          total += (chat['unread_count'] as num?)?.toInt() ?? 0;
        }
        if (mounted && total != _unreadCount) {
          setState(() => _unreadCount = total);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6C63FF);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // 0 - Ana Sayfa
          PremiumHomeScreen(key: _homeKey),

          // 1 - Mesajlar
          ChatListScreen(myId: _currentUserId ?? 0),

          // 2 - Sat (placeholder)
          const SizedBox(),

          // 3 - Sepet
          PremiumCartScreen(
            onDiscoverPressed: () {
              setState(() => _selectedIndex = 0);
            },
          ),

          // 4 - Profil
          ProfileScreen(key: _profileKey),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Keşfet', primaryColor),
                _buildNavItemWithBadge(1, Icons.chat_bubble_outline_rounded, 'Mesajlar', primaryColor),
                _buildNavItem(2, Icons.add_circle_outline, 'Sat', primaryColor),
                _buildNavItem(3, Icons.shopping_cart_outlined, 'Sepetim', primaryColor),
                _buildNavItem(4, Icons.person_outline, 'Profil', primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color primaryColor) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onNavTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 22, color: isSelected ? primaryColor : Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItemWithBadge(int index, IconData icon, String label, Color primaryColor) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onNavTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 22, color: isSelected ? primaryColor : Colors.grey[600]),
                  if (_unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onNavTap(int index) async {
    if (index == 2) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final userEmail = prefs.getString('user_email');
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddProductScreen(userId: userId, userEmail: userEmail),
        ),
      );
      if (result == true) _homeKey.currentState?.refreshAfterLogin();
    } else {
      if (index == 1) {
        await _loadUser();
        setState(() => _unreadCount = 0);
      }
      setState(() => _selectedIndex = index);
    }
  }
}
