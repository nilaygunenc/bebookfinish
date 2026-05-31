import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:bebook/services/api_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../profile/ultra_premium_auth_screen.dart';

class AddProductScreen extends StatefulWidget {
  final int? userId;
  final String? userEmail;

  const AddProductScreen({super.key, this.userId, this.userEmail});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with SingleTickerProviderStateMixin {
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _publisherController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  late TextEditingController _mailController;

  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _userEmail;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _mailController = TextEditingController(text: widget.userEmail ?? "");
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _checkLogin();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _authorController.dispose();
    _typeController.dispose();
    _publisherController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _mailController.dispose();
    super.dispose();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('is_logged_in') ?? false;
    final id = prefs.getInt('user_id');
    final email = prefs.getString('user_email') ?? widget.userEmail ?? '';
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn && id != null;
        _userEmail = email;
        if (email.isNotEmpty) _mailController.text = email;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera && Platform.isWindows) {
        _showSnackBar("Windows'ta kamera desteklenmiyor.", Colors.orange);
        return;
      }
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (_selectedImages.length < 5) _selectedImages.add(pickedFile);
        });
      }
    } catch (e) {
      debugPrint("Resim seçme hatası: $e");
    }
  }

  Future<void> pickImageAndScan() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 1000,
      );
      if (pickedFile != null) {
        Uint8List imageBytes = await pickedFile.readAsBytes();
        await fetchBookData(imageBytes, pickedFile.name);
      }
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  Future<void> fetchBookData(Uint8List imageBytes, String fileName) async {
    setState(() => _isLoading = true);
    try {
      // ISBN backend ayrı bir serviste çalışıyor (port 8001)
      final isbnBackendUrl = ApiService.baseUrl.replaceAll(':8002', ':8001');
      
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("$isbnBackendUrl/scan"),
      );
      
      print("ISBN Backend URL: $isbnBackendUrl/scan");
      
      request.files.add(http.MultipartFile.fromBytes("image", imageBytes, filename: fileName));
      var response = await request.send().timeout(const Duration(seconds: 30));
      var responseData = await response.stream.bytesToString();
      
      print("ISBN Response Status: ${response.statusCode}");
      print("ISBN Response Data: $responseData");
      
      if (response.statusCode == 200) {
        final data = json.decode(responseData);
        if (data.containsKey("error")) {
          _showSnackBar("ISBN okunamadı: ${data['error']}", Colors.orange);
        } else {
          setState(() {
            _nameController.text = data["title"] ?? "";
            _authorController.text = data["author"] ?? "";
            _publisherController.text = data["publisher"] ?? "";
          });
          _showSnackBar("✅ Kitap bilgileri getirildi!", AppTheme.successGreen);
        }
      } else {
        _showSnackBar("ISBN backend hatası: ${response.statusCode}", AppTheme.errorRed);
      }
    } catch (e) {
      print("ISBN Tarama Hatası: $e");
      _showSnackBar("Bağlantı hatası! ISBN backend çalışıyor mu?", AppTheme.errorRed);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      body: Stack(
        children: [
          // Hafif gradient arka plan (profil sayfasıyla aynı)
          Container(
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
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _isLoggedIn ? _buildForm() : _buildLoginPrompt(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── GİRİŞ YAPILMAMIŞSA ───────────────────────────────────────
  Widget _buildLoginPrompt() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppTheme.shadowXL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: AppTheme.shadowPrimary,
                ),
                child: const Icon(Icons.sell_rounded, size: 56, color: Colors.white),
              ),
              const SizedBox(height: 28),
              Text(
                "Kitap Sat",
                style: AppTheme.textTheme.headlineLarge?.copyWith(
                  color: AppTheme.primaryIndigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "İlan vermek için önce giriş yapman gerekiyor.",
                style: AppTheme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.neutralDark,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              _buildAuthButton(
                "Giriş Yap",
                Icons.login_rounded,
                AppTheme.primaryGradient,
                false,
                () async {
                  HapticFeedback.mediumImpact();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UltraPremiumAuthScreen(isLogin: true),
                    ),
                  );
                  if (result != null) await _checkLogin();
                },
              ),
              const SizedBox(height: 14),
              _buildAuthButton(
                "Üye Ol",
                Icons.person_add_rounded,
                AppTheme.accentGradient,
                true,
                () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UltraPremiumAuthScreen(isLogin: false),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthButton(String text, IconData icon, LinearGradient gradient,
      bool isOutlined, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isOutlined ? null : gradient,
        border: isOutlined
            ? Border.all(color: AppTheme.accentOrange, width: 2)
            : null,
        boxShadow: isOutlined ? null : AppTheme.shadowMD,
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon,
            color: isOutlined ? AppTheme.accentOrange : Colors.white, size: 22),
        label: Text(
          text,
          style: AppTheme.textTheme.titleLarge?.copyWith(
            color: isOutlined ? AppTheme.accentOrange : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ─── FORM ─────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      children: [
        // Header
        _buildHeader(),
        // İçerik
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ISBN Tarama Kartı
                _buildScanCard(),
                const SizedBox(height: 20),
                _buildDividerRow("veya manuel gir"),
                const SizedBox(height: 20),
                // Form Kartı
                _buildFormCard(),
                const SizedBox(height: 20),
                // Fotoğraf Kartı
                _buildPhotoCard(),
                const SizedBox(height: 24),
                // Yayınla Butonu
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppTheme.shadowSM,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sell_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Text(
            "Kitap Sat",
            style: AppTheme.textTheme.headlineMedium?.copyWith(
              color: AppTheme.primaryIndigo,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard() {
    return GestureDetector(
      onTap: _isLoading ? null : pickImageAndScan,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.shadowPrimary,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "ISBN Barkodunu Tara",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Kamera ile otomatik doldur",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDividerRow(String text) {
    return Row(children: [
      const Expanded(child: Divider(thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text,
            style: TextStyle(color: AppTheme.neutralDark, fontSize: 13)),
      ),
      const Expanded(child: Divider(thickness: 1)),
    ]);
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.shadowMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Kitap Bilgileri", Icons.book_rounded),
          const SizedBox(height: 16),
          _buildField("Kitap Adı *", Icons.book_outlined, _nameController),
          const SizedBox(height: 14),
          _buildField("Yazar *", Icons.person_outline_rounded, _authorController),
          const SizedBox(height: 14),
          _buildField("Tür / Kategori", Icons.category_outlined, _typeController),
          const SizedBox(height: 14),
          _buildField("Yayınevi", Icons.business_outlined, _publisherController),
          const SizedBox(height: 14),
          _buildField("Fiyat (₺) *", Icons.sell_outlined, _priceController,
              isNumber: true),
          const SizedBox(height: 14),
          _buildField("Açıklama", Icons.description_outlined, _descController,
              maxLines: 3),
          const SizedBox(height: 14),
          _buildField("İletişim E-postası *", Icons.alternate_email_rounded,
              _mailController,
              keyboardType: TextInputType.emailAddress),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryIndigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryIndigo, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppTheme.primaryIndigo,
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool isNumber = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : keyboardType,
      inputFormatters:
          isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.neutralDark, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.primaryIndigo, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8F7FF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: AppTheme.primaryIndigo.withOpacity(0.1), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.primaryIndigo, width: 2),
        ),
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.shadowMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Fotoğraf Ekle", Icons.photo_library_rounded),
          const SizedBox(height: 4),
          Text(
            "En fazla 5 fotoğraf ekleyebilirsin",
            style: TextStyle(color: AppTheme.neutralDark, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length +
                  (_selectedImages.length < 5 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _selectedImages.length) {
                  return _buildAddPhotoButton();
                }
                return _buildImageThumbnail(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _showPickOptions,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryIndigo.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryIndigo.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                color: AppTheme.primaryIndigo, size: 28),
            const SizedBox(height: 6),
            Text(
              "Ekle",
              style: TextStyle(
                  color: AppTheme.primaryIndigo,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(int index) {
    return Stack(
      children: [
        FutureBuilder<Uint8List>(
          future: _selectedImages[index].readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  image: DecorationImage(
                    image: MemoryImage(snapshot.data!),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: AppTheme.shadowSM,
                ),
              );
            }
            return Container(
              width: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey[200],
              ),
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        ),
        Positioned(
          right: 14,
          top: 4,
          child: GestureDetector(
            onTap: () => setState(() => _selectedImages.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.errorRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Fotoğraf Seç",
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryIndigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library_rounded,
                      color: AppTheme.primaryIndigo),
                ),
                title: const Text("Galeriden Seç"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt_rounded,
                      color: AppTheme.accentOrange),
                ),
                title: const Text("Kamerayı Aç"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.shadowPrimary,
      ),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitForm,
        icon: const Icon(Icons.rocket_launch_rounded,
            color: Colors.white, size: 22),
        label: const Text(
          "İlanı Yayınla",
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_nameController.text.trim().isEmpty ||
        _authorController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      _showSnackBar("Lütfen zorunlu alanları doldurun! (*)", Colors.orange);
      return;
    }

    final double? priceValue = double.tryParse(_priceController.text.trim());
    if (priceValue == null) {
      _showSnackBar("Geçerli bir fiyat giriniz!", Colors.orange);
      return;
    }

    final email = _mailController.text.trim().isNotEmpty
        ? _mailController.text.trim()
        : _userEmail ?? '';

    if (email.isEmpty) {
      _showSnackBar("İletişim e-postası gereklidir!", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    final bool success = await ApiService.uploadBook(
      title: _nameController.text.trim(),
      author: _authorController.text.trim(),
      category: _typeController.text.trim().isEmpty ? "Diğer" : _typeController.text.trim(),
      price: priceValue,
      description: _descController.text.trim().isEmpty ? "-" : _descController.text.trim(),
      sellerEmail: email,
      publisher: _publisherController.text.trim(),
      imageFile: _selectedImages.isNotEmpty ? _selectedImages[0] : null,
    );

    setState(() => _isLoading = false);

    if (success) {
      HapticFeedback.heavyImpact();
      _showSnackBar("İlan başarıyla yayınlandı! 🎉", AppTheme.successGreen);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context, true);
    } else {
      _showSnackBar("Hata: Sunucuya bağlanılamadı.", AppTheme.errorRed);
    }
  }
}
