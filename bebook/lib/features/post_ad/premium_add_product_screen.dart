import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bebook/services/api_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../profile/ultra_premium_auth_screen.dart';

/// 💎 Premium Kitap Sat Ekranı - Modern & User-Friendly
class PremiumAddProductScreen extends StatefulWidget {
  final int? userId;
  final String? userEmail;

  const PremiumAddProductScreen({super.key, this.userId, this.userEmail});

  @override
  State<PremiumAddProductScreen> createState() => _PremiumAddProductScreenState();
}

class _PremiumAddProductScreenState extends State<PremiumAddProductScreen>
    with SingleTickerProviderStateMixin {
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _publisherController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  late TextEditingController _mailController;

  bool _isLoading = false;
  bool _isScanning = false;
  bool _isLoggedIn = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _mailController = TextEditingController(text: widget.userEmail ?? "");

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('is_logged_in') ?? false;
    final email = prefs.getString('user_email') ?? widget.userEmail ?? '';
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        if (email.isNotEmpty) _mailController.text = email;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _authorController.dispose();
    _typeController.dispose();
    _publisherController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _mailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera && Platform.isWindows) {
        _showSnackBar("Windows'ta kamera pasif 🚀", AppTheme.warningAmber);
        return;
      }
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (_selectedImages.length < 5) {
            _selectedImages.add(pickedFile);
          }
        });
        HapticFeedback.lightImpact();
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
    setState(() => _isScanning = true);
    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("${ApiService.baseUrl}/scan"),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          "image",
          imageBytes,
          filename: fileName,
        ),
      );

      var response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception("Sunucu yanıt vermedi (timeout)");
        },
      );
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseData);

        if (data.containsKey("error")) {
          _showSnackBar("ISBN okunamadı: ${data['error']}", AppTheme.warningAmber);
        } else {
          setState(() {
            _nameController.text = data["title"] ?? "";
            _authorController.text = data["author"] ?? "";
            _publisherController.text = data["publisher"] ?? "";
          });
          HapticFeedback.mediumImpact();
          _showSnackBar("✅ Kitap bilgileri getirildi!", AppTheme.successGreen);
        }
      } else {
        _showSnackBar("Sunucu hatası: ${response.statusCode}", AppTheme.errorRed);
      }
    } catch (e) {
      _showSnackBar("Bağlantı hatası! ISBN backend çalışıyor mu?", AppTheme.errorRed);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _submitProduct() async {
    if (_nameController.text.isEmpty ||
        _authorController.text.isEmpty ||
        _priceController.text.isEmpty) {
      _showSnackBar("Lütfen gerekli alanları doldurun!", AppTheme.warningAmber);
      return;
    }

    // Mail alanı zorunlu ve geçerli format olmalı
    final email = _mailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar("Geçerli bir e-posta adresi girin!", AppTheme.warningAmber);
      return;
    }

    double? priceValue = double.tryParse(_priceController.text);
    if (priceValue == null) {
      _showSnackBar("Geçerli bir fiyat giriniz!", AppTheme.warningAmber);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    bool success = await ApiService.uploadBook(
      title: _nameController.text.trim(),
      author: _authorController.text.trim(),
      category: _typeController.text.trim(),
      price: priceValue,
      description: _descController.text.trim(),
      sellerEmail: _mailController.text.trim(),
      imageFile: _selectedImages.isNotEmpty ? _selectedImages[0] : null,
    );

    setState(() => _isLoading = false);

    if (success) {
      HapticFeedback.heavyImpact();
      _showSnackBar("İlan başarıyla yayınlandı! 🎉", AppTheme.successGreen);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context, true);
    } else {
      _showSnackBar("Hata: Sunucuya bağlanılamadı.", AppTheme.errorRed);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

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
              // Giriş Yap butonu
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.shadowPrimary,
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UltraPremiumAuthScreen(isLogin: true),
                      ),
                    );
                    if (result != null) await _checkLogin();
                  },
                  icon: const Icon(Icons.login_rounded, color: Colors.white, size: 22),
                  label: Text(
                    "Giriş Yap",
                    style: AppTheme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Üye Ol butonu
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accentOrange, width: 2),
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UltraPremiumAuthScreen(isLogin: false),
                      ),
                    );
                  },
                  icon: Icon(Icons.person_add_rounded,
                      color: AppTheme.accentOrange, size: 22),
                  label: Text(
                    "Üye Ol",
                    style: AppTheme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.accentOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Animated Background
          _buildAnimatedBackground(),

          // Giriş yapılmamışsa login prompt göster
          if (!_isLoggedIn)
            SafeArea(child: _buildLoginPrompt()),

          // Giriş yapılmışsa form göster
          if (_isLoggedIn)
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Premium Header
                _buildPremiumHeader(),

                // Form Content
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // AI Scanner Card
                            _buildAIScannerCard(),
                            const SizedBox(height: 32),

                            // Divider
                            _buildDivider(),
                            const SizedBox(height: 32),

                            // Form Fields
                            _buildFormFields(),
                            const SizedBox(height: 32),

                            // Image Picker
                            _buildImagePicker(),
                            const SizedBox(height: 32),

                            // Submit Button
                            _buildSubmitButton(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryIndigo.withOpacity(0.05),
              AppTheme.accentCyan.withOpacity(0.05),
              AppTheme.accentOrange.withOpacity(0.03),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.8),
                    Colors.white.withOpacity(0.6),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentOrange.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sell_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppTheme.primaryGradient.createShader(bounds),
                              child: Text(
                                "Kitap Sat",
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                            Text(
                              "Kitabını hızlıca listele",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.neutralDark,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIScannerCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryIndigo.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isScanning ? null : pickImageAndScan,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(32),
            child: _isScanning
                ? Column(
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "ISBN taranıyor...",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "ISBN Barkodunu Tara",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Kitap bilgileri otomatik doldurulacak",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.neutralMedium,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "veya manuel gir",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.neutralDark,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.neutralMedium,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField("Kitap Adı *", Icons.book_rounded, _nameController),
        const SizedBox(height: 16),
        _buildTextField("Yazar *", Icons.person_rounded, _authorController),
        const SizedBox(height: 16),
        _buildTextField("Tür", Icons.category_rounded, _typeController),
        const SizedBox(height: 16),
        _buildTextField("Bölüm", Icons.school_rounded, _departmentController),
        const SizedBox(height: 16),
        _buildTextField("Yayınevi", Icons.business_rounded, _publisherController),
        const SizedBox(height: 16),
        _buildTextField("Fiyat (TL) *", Icons.sell_rounded, _priceController,
            isNumber: true),
        const SizedBox(height: 16),
        _buildTextField("Açıklama", Icons.description_rounded, _descController,
            maxLines: 3),
        const SizedBox(height: 16),
        _buildTextField("İletişim Maili *", Icons.email_rounded, _mailController),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryIndigo),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.primaryIndigo, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Fotoğraf Ekle",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length + (_selectedImages.length < 5 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) return _buildAddPhotoButton();
              return _buildImageThumbnail(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showPickOptions();
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryIndigo,
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryIndigo.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
              color: AppTheme.primaryIndigo,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              "Fotoğraf Ekle",
              style: TextStyle(
                color: AppTheme.primaryIndigo,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
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
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: MemoryImage(snapshot.data!),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              );
            }
            return Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppTheme.neutralLight,
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
        Positioned(
          right: 20,
          top: 8,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedImages.removeAt(index));
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.errorRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.errorRed.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Colors.white,
              ),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: AppTheme.neutralMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.white),
                ),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                ),
                title: const Text('Kamerayı Aç'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentOrange.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentOrange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      "İlanı Yayınla",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
