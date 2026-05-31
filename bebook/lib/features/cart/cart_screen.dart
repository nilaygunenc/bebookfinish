import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import '../../widgets/book_card.dart';
import '../../models/book_model.dart'; // ✅ Book import eklendi
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback onDiscoverPressed;

  const CartScreen({super.key, required this.onDiscoverPressed});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with WidgetsBindingObserver {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isWaitingForPayment = false;
  bool _isAgreedToTerms = false;
  int? lastOrderId;
  int? _currentUserId; // ✅ Kullanıcı ID'si
  List<Book> _userCart = []; // ✅ Kullanıcıya özel sepet

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserCart();
    
    // ✅ Logout dinleyicisi ekle
    logoutNotifier.addListener(_handleLogout);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    logoutNotifier.removeListener(_handleLogout);
    super.dispose();
  }

  // ✅ YENİ: Kullanıcı sepetini yükle
  Future<void> _loadUserCart() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    setState(() {
      _currentUserId = userId;
      _userCart = CartManager.getCart(userId);
    });
  }

  // ✅ YENİ: Logout handler
  void _handleLogout() {
    if (logoutNotifier.value == true) {
      if (mounted) {
        setState(() {
          _userCart = [];
          _currentUserId = null;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && _isWaitingForPayment) {
      setState(() => _isWaitingForPayment = false);
      await _markOrderComplete();
    }
  }

  Future<void> _markOrderComplete() async {
    if (lastOrderId != null) {
      try {
        final response = await http.post(
          Uri.parse("${ApiService.baseUrl}/mark-order-complete/$lastOrderId"),
        ).timeout(const Duration(seconds: 10));
        debugPrint("mark-order-complete: ${response.statusCode} - ${response.body}");
      } catch (e) {
        debugPrint("Order complete hatası: $e");
      }
    }
    if (mounted) {
      setState(() {
        CartManager.clearCart(_currentUserId);
        _userCart = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sipariş tamamlandı! 🎉"),
          backgroundColor: Colors.green,
        ),
      );
      widget.onDiscoverPressed();
    }
  }

  double _calculateTotal() {
    double total = 0;
    for (var book in _userCart) {
      total += double.tryParse(book.price.toString()) ?? 0;
    }
    return total;
  }

  // Mesafeli Satış Sözleşmesi İçeriği
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mesafeli Satış Sözleşmesi"),
        content: const SingleChildScrollView(
          child: Text(
            "1. TARAFLAR: İşbu sözleşme BEBOOK üzerinden alışveriş yapan kullanıcı ile satıcı arasındadır.\n\n"
            "2. KONU: Alıcının satıcıya ait web sitesi üzerinden elektronik ortamda siparişini verdiği ürünün satışı ve teslimi ile ilgili hak ve yükümlülükleri kapsar.\n\n"
            "3. TESLİMAT: Ürün, alıcının belirttiği adrese güvenli bir şekilde gönderilecektir.\n\n"
            "4. CAYMA HAKKI: Dijital içeriklerde ve özel basımlarda cayma hakkı sınırlıdır.\n\n"
            "Bu metin BEBOOK projesi kapsamında test amaçlı oluşturulmuştur."
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anladım")),
        ],
      ),
    );
  }

  void _completePayment(Color primaryColor) async {
    if (_userCart.isEmpty) return;
    
    // ✅ Giriş kontrolü
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ödeme yapmak için giriş yapmalısınız"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Diyalog her açıldığında onay kutusunu sıfırlayalım
    _isAgreedToTerms = false; 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Checkbox'ın anlık güncellenmesi için gerekli
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Teslimat Bilgileri", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Ad Soyad",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "Teslimat Adresi",
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Checkbox(
                        value: _isAgreedToTerms,
                        activeColor: primaryColor,
                        onChanged: (value) {
                          setDialogState(() {
                            _isAgreedToTerms = value!;
                          });
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showTermsDialog,
                          child: const Text(
                            "Mesafeli Satış Sözleşmesi'ni okudum, onaylıyorum.",
                            style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAgreedToTerms ? primaryColor : Colors.grey,
                ),
                onPressed: _isAgreedToTerms ? () {
                  if (_nameController.text.isNotEmpty && _addressController.text.isNotEmpty) {
                    Navigator.pop(context);
                    _processPaymentRequest(primaryColor);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Lütfen tüm alanları doldurun.")),
                    );
                  }
                } : null, // Onay kutusu seçili değilse buton inaktif olur
                child: const Text("Ödemeye Geç", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _processPaymentRequest(Color primaryColor) async {
    List<int> ids = _userCart.map((b) => b.id).toList();
    double total = _calculateTotal();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await ApiService.makeBulkPayment(
        userId: _currentUserId!, // ✅ Gerçek kullanıcı ID'si
        bookIds: ids,
        totalPrice: total,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result['status'] == 'success' || result['status'] == 'None') { 
        lastOrderId = result['orderId'];
        String? paymentUrl = result['paymentPageUrl'];

        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          final Uri url = Uri.parse(paymentUrl);
          _isWaitingForPayment = true; 
          await launchUrl(url, mode: LaunchMode.externalApplication);
          // URL açıldıktan sonra (web'de hemen döner) order'ı tamamla
          if (_isWaitingForPayment && mounted) {
            setState(() => _isWaitingForPayment = false);
            await _markOrderComplete();
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: ${result['errorMessage'] ?? result['message']}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Ödeme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6C63FF);
    
    // ✅ Her build'de sepeti güncelle
    _userCart = CartManager.getCart(_currentUserId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Sepetim", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _userCart.isEmpty ? _buildEmptyState(primaryColor) : _buildCartItems(primaryColor),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 100, color: primaryColor),
            const SizedBox(height: 30),
            const Text("Sepetiniz henüz boş", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onDiscoverPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: const Text("Kitap Keşfet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItems(Color primaryColor) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: _userCart.length,
            itemBuilder: (context, index) {
              final book = _userCart[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 15),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      book.imagePath.isNotEmpty ? book.imagePath : "https://via.placeholder.com/150",
                      width: 50, height: 70, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.book, size: 40),
                    ),
                  ),
                  title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${book.price} TL", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        CartManager.removeFromCart(_currentUserId, book.id);
                        _userCart = CartManager.getCart(_currentUserId);
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),
        _buildBottomSection(primaryColor),
      ],
    );
  }

  Widget _buildBottomSection(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Toplam Tutar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Text("${_calculateTotal().toStringAsFixed(2)} TL", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => _completePayment(primaryColor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("ÖDEMEYİ TAMAMLA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}