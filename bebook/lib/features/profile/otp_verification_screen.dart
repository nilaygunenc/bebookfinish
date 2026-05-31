import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../core/theme/app_theme.dart';
import 'new_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  // Geri sayım
  int _secondsLeft = 120; // 2 dakika
  Timer? _countdownTimer;

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
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _startCountdown();
  }

  void _startCountdown() {
    _secondsLeft = 120;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        if (mounted) setState(() {});
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  String get _timerText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    for (var n in _focusNodes) n.dispose();
    for (var c in _controllers) c.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((e) => e.text).join();

    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Lütfen 6 haneli kodu tam girin"),
          backgroundColor: AppTheme.warningAmber,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.verifyOtp(widget.email, otp);

      if (!mounted) return;

      if (result['status'] == 'success') {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text("Kod doğrulandı!"),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewPasswordScreen(email: widget.email),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Geçersiz kod!"),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Hatalı girişte kutucukları temizle
        for (var c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Sunucuya bağlanılamadı!"),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.shadowSM,
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            color: AppTheme.primaryIndigo, size: 20),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              gradient: AppTheme.accentGradient,
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.shadowAccent,
                            ),
                            child: const Icon(Icons.security_rounded,
                                size: 56, color: Colors.white),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            "Kodu Doğrula",
                            style: AppTheme.textTheme.headlineLarge
                                ?.copyWith(
                              color: AppTheme.primaryIndigo,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: AppTheme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.neutralDark,
                                height: 1.6,
                              ),
                              children: [
                                const TextSpan(
                                    text: "6 haneli kodu şu adrese gönderdik:\n"),
                                TextSpan(
                                  text: widget.email,
                                  style: const TextStyle(
                                    color: AppTheme.primaryIndigo,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),

                          // OTP kutucukları
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: AppTheme.shadowLG,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(
                                    6,
                                    (i) => SizedBox(
                                      width: 44,
                                      height: 56,
                                      child: TextField(
                                        controller: _controllers[i],
                                        focusNode: _focusNodes[i],
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        maxLength: 1,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black, // Kesin siyah
                                        ),
                                        decoration: InputDecoration(
                                          counterText: "",
                                          filled: true,
                                          fillColor: Colors.white, // Beyaz arka plan
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1.5,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: AppTheme.primaryIndigo,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onChanged: (v) {
                                          if (v.isNotEmpty && i < 5) {
                                            _focusNodes[i + 1].requestFocus();
                                          } else if (v.isEmpty && i > 0) {
                                            _focusNodes[i - 1].requestFocus();
                                          }
                                          // 6. hane dolunca otomatik doğrula
                                          if (i == 5 && v.isNotEmpty) {
                                            _verifyOtp();
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Geri sayım göstergesi
                                Center(
                                  child: _secondsLeft > 0
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.timer_outlined,
                                                size: 16,
                                                color: _secondsLeft <= 30
                                                    ? AppTheme.errorRed
                                                    : AppTheme.neutralDark),
                                            const SizedBox(width: 6),
                                            Text(
                                              "Kodun geçerlilik süresi: $_timerText",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _secondsLeft <= 30
                                                    ? AppTheme.errorRed
                                                    : AppTheme.neutralDark,
                                                fontWeight: _secondsLeft <= 30
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        )
                                      : GestureDetector(
                                          onTap: () {
                                            Navigator.pop(context);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.errorRed
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.refresh_rounded,
                                                    size: 16,
                                                    color: AppTheme.errorRed),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "Süre doldu. Yeni kod al",
                                                  style: TextStyle(
                                                    color: AppTheme.errorRed,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _verifyOtp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : const Text(
                                                "Doğrula",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
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
}
