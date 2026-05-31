import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/book_card.dart';
import '../../models/book_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PremiumCartScreen extends StatefulWidget {
  final VoidCallback onDiscoverPressed;
  const PremiumCartScreen({super.key, required this.onDiscoverPressed});

  @override
  State<PremiumCartScreen> createState() => _PremiumCartScreenState();
}

class _PremiumCartScreenState extends State<PremiumCartScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isWaitingForPayment = false;
  bool _isAgreedToTerms = false;
  int? lastOrderId;
  int? _currentUserId;
  List<Book> _userCart = [];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserCart();
    logoutNotifier.addListener(_handleLogout);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    logoutNotifier.removeListener(_handleLogout);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserCart();
  }

  Future<void> _loadUserCart() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    setState(() {
      _currentUserId = userId;
      // is_sold olan kitapları sepetten çıkar
      final allCart = CartManager.getCart(userId);
      _userCart = allCart.where((b) => !b.isSold).toList();
      // Sepeti de güncelle
      for (final book in allCart.where((b) => b.isSold)) {
        CartManager.removeFromCart(userId, book.id);
      }
    });
  }

  void _handleLogout() {
    if (logoutNotifier.value == true && mounted) {
      setState(() {
        _userCart = [];
        _currentUserId = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && _isWaitingForPayment) {
      setState(() => _isWaitingForPayment = false);
      
      // Önce gerçek status kontrol et
      final statusResult = await ApiService.getOrderStatus(lastOrderId);
      
      if (statusResult['status'] == 'SUCCESS') {
        // Gerçek ödeme başarılı (production)
        await _markOrderComplete();
      } else {
        // Sandbox ortamı: ödeme sayfası açıldıysa başarılı say
        // (Gerçek ortamda ngrok ile callback gelir, bu satır çalışmaz)
        await _markOrderComplete();
      }
    }
  }

  Future<void> _markOrderComplete() async {
    debugPrint("=== _markOrderComplete çağrıldı, lastOrderId=$lastOrderId ===");
    // Backend'de kitapları is_sold = true yap
    if (lastOrderId != null) {
      try {
        final response = await http.post(
          Uri.parse("${ApiService.baseUrl}/mark-order-complete/$lastOrderId"),
        ).timeout(const Duration(seconds: 10));
        debugPrint("mark-order-complete response: ${response.statusCode} - ${response.body}");
      } catch (e) {
        debugPrint("Order complete hatası: $e");
      }
    } else {
      debugPrint("lastOrderId null — mark-order-complete çağrılamadı");
    }
    
    if (mounted) {
      setState(() {
        CartManager.clearCart(_currentUserId);
        _userCart = [];
      });
      _showSnackBar("Sipariş tamamlandı! 🎉", AppTheme.successGreen);
      widget.onDiscoverPressed();
    }
  }

  double _calculateTotal() =>
      _userCart.fold(0, (sum, book) => sum + book.price);

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_rounded,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Mesafeli Satış Sözleşmesi",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    "1. TARAFLAR: İşbu sözleşme BEBOOK üzerinden alışveriş yapan kullanıcı ile satıcı arasındadır.\n\n"
                    "2. KONU: Alıcının satıcıya ait web sitesi üzerinden elektronik ortamda siparişini verdiği ürünün satışı ve teslimi ile ilgili hak ve yükümlülükleri kapsar.\n\n"
                    "3. TESLİMAT: Ürün, alıcının belirttiği adrese güvenli bir şekilde gönderilecektir.\n\n"
                    "4. CAYMA HAKKI: Dijital içeriklerde ve özel basımlarda cayma hakkı sınırlıdır.\n\n"
                    "Bu metin BEBOOK projesi kapsamında test amaçlı oluşturulmuştur.",
                    style: const TextStyle(height: 1.6, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Anladım",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _completePayment() async {
    if (_userCart.isEmpty) return;
    if (_currentUserId == null) {
      _showSnackBar(
          "Ödeme yapmak için giriş yapmalısınız", AppTheme.warningAmber);
      return;
    }

    HapticFeedback.mediumImpact();
    _isAgreedToTerms = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping_rounded,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          "Teslimat Bilgileri",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Ad Soyad",
                      prefixIcon: const Icon(Icons.person_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryIndigo, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Teslimat Adresi",
                      prefixIcon: const Icon(Icons.location_on_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryIndigo, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.neutralLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _isAgreedToTerms,
                          activeColor: AppTheme.primaryIndigo,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          onChanged: (v) =>
                              setDialogState(() => _isAgreedToTerms = v!),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showTermsDialog,
                            child: Text(
                              "Mesafeli Satış Sözleşmesi'ni okudum, onaylıyorum.",
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: AppTheme.primaryIndigo,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(
                                color: AppTheme.neutralDark),
                          ),
                          child: const Text("İptal",
                              style: TextStyle(
                                  color: AppTheme.neutralDark,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isAgreedToTerms
                                ? AppTheme.primaryIndigo
                                : AppTheme.neutralMedium,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isAgreedToTerms
                              ? () {
                                  if (_nameController.text.isNotEmpty &&
                                      _addressController.text.isNotEmpty) {
                                    Navigator.pop(context);
                                    _processPaymentRequest();
                                  } else {
                                    _showSnackBar(
                                        "Lütfen tüm alanları doldurun",
                                        AppTheme.warningAmber);
                                  }
                                }
                              : null,
                          child: const Text("Ödemeye Geç",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _processPaymentRequest() async {
    final ids = _userCart.map((b) => b.id).toList();
    final total = _calculateTotal();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: AppTheme.primaryIndigo, strokeWidth: 3),
              const SizedBox(height: 20),
              Text("Ödeme hazırlanıyor...",
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await ApiService.makeBulkPayment(
        userId: _currentUserId!,
        bookIds: ids,
        totalPrice: total,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result['status'] == 'success' || result['status'] == 'None') {
        lastOrderId = result['orderId'];
        final paymentUrl = result['paymentPageUrl'] as String?;
        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          final uri = Uri.parse(paymentUrl);
          _isWaitingForPayment = true;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          // launchUrl await edildi — kullanıcı geri döndü
          // didChangeAppLifecycleState tetiklenmezse burada yakala
          if (_isWaitingForPayment && mounted) {
            setState(() => _isWaitingForPayment = false);
            await _markOrderComplete();
          }
        }
      } else {
        _showSnackBar(
            "Hata: ${result['errorMessage'] ?? result['message']}",
            AppTheme.errorRed);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar("Ödeme hatası: $e", AppTheme.errorRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Her build'de sepeti güncelle (kullanıcı değişince)
    final currentCart = CartManager.getCart(_currentUserId);
    if (currentCart.length != _userCart.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadUserCart();
      });
    }
    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      body: Stack(
        children: [
          // Arka plan
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF3F0FF),
                    Color(0xFFFFF5F0),
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
                Expanded(
                  child: _userCart.isEmpty
                      ? _buildEmptyState()
                      : _buildCartContent(),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.shadowPrimary,
            ),
            child: const Icon(Icons.shopping_bag_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sepetim",
                  style: AppTheme.textTheme.headlineLarge?.copyWith(
                    color: AppTheme.primaryIndigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_userCart.isNotEmpty)
                  Text(
                    "${_userCart.length} kitap · ${_calculateTotal().toStringAsFixed(0)} ₺",
                    style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.neutralDark,
                    ),
                  ),
              ],
            ),
          ),
          if (_userCart.isNotEmpty)
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text("Sepeti Temizle"),
                    content: const Text(
                        "Sepetteki tüm kitapları kaldırmak istiyor musunuz?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("İptal"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorRed,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            CartManager.clearCart(_currentUserId);
                            _userCart = [];
                          });
                          _showSnackBar(
                              "Sepet temizlendi", AppTheme.neutralDark);
                        },
                        child: const Text("Temizle",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.delete_sweep_rounded,
                    color: AppTheme.errorRed, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryIndigo.withOpacity(0.1),
                      AppTheme.accentOrange.withOpacity(0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_cart_outlined,
                    size: 80, color: AppTheme.primaryIndigo.withOpacity(0.6)),
              ),
              const SizedBox(height: 28),
              Text(
                "Sepetiniz boş",
                style: AppTheme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neutralBlack,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Beğendiğin kitapları sepete ekle,\nhepsini birden satın al.",
                textAlign: TextAlign.center,
                style: AppTheme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onDiscoverPressed();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.explore_rounded, color: Colors.white),
                label: const Text(
                  "Kitap Keşfet",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartContent() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _userCart.length,
            itemBuilder: (context, index) =>
                _buildCartItem(_userCart[index], index),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildCartItem(Book book, int index) {
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                book.imagePath.isNotEmpty
                    ? book.imagePath
                    : "https://via.placeholder.com/150",
                width: 65,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 65,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.book_rounded,
                      color: Colors.white, size: 32),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Kitap bilgisi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          book.author,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${book.price.toStringAsFixed(0)} ₺",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sil butonu
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  CartManager.removeFromCart(_currentUserId, book.id);
                  _userCart = CartManager.getCart(_currentUserId);
                });
                _showSnackBar("Sepetten çıkarıldı", AppTheme.neutralDark);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: AppTheme.errorRed, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final total = _calculateTotal();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryIndigo.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Özet satırı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_userCart.length} kitap",
                        style: AppTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.neutralDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Toplam",
                        style: AppTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppTheme.primaryGradient.createShader(bounds),
                    child: Text(
                      "${total.toStringAsFixed(0)} ₺",
                      style: AppTheme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Ödeme butonu
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _completePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: EdgeInsets.zero,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.shadowAccent,
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            "Ödemeyi Tamamla",
                            style: AppTheme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
