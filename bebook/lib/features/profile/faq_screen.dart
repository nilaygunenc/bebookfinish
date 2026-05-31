import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Senin o me┼şhur "ho┼ş mor" tonun
    const Color primaryColor = Color(0xFF6C63FF);

    return Scaffold(
      // Arka plan─▒ ├ğok hafif bir gri yaparak beyaz kartlar─▒n ├Âne ├ğ─▒kmas─▒n─▒ sa─şlad─▒k
      backgroundColor: const Color(0xFFF9FAFF),
      appBar: AppBar(
        title: const Text(
          "S─▒k├ğa Sorulan Sorular",
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5, // ├çok hafif bir derinlik ├ğizgisi
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: ListView(
        // BouncingScrollPhysics: Sayfay─▒ kayd─▒r─▒rken o yumu┼şak "yay" efektini verir (iOS stili)
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        children: [
          _buildFAQItem(
            "­şÆ│", // ─░kon ekledik
            "├ûdemeyi nas─▒l yapabilirim?",
            "BEBOOK, iyzico g├╝venli ├Âdeme altyap─▒s─▒n─▒ kullan─▒r. Kitap sat─▒n al─▒rken kart bilgilerinizle iyzico g├╝vencesinde ├Âdeme yapabilir, i┼şleminiz tamamlanana kadar paran─▒z─▒ koruma alt─▒nda tutabilirsiniz.",
            primaryColor,
          ),
          _buildFAQItem(
            "­şôû",
            "Kitap anlat─▒ld─▒─ş─▒ gibi gelmezse?",
            "E─şer teslim ald─▒─ş─▒n─▒z kitap ilan a├ğ─▒klamas─▒ndaki gibi de─şilse, 'Destek' k─▒sm─▒ndan bizimle ileti┼şime ge├ğebilirsiniz. Gerekli incelemelerden sonra iyzico ├╝zerinden iade s├╝reciniz ba┼şlat─▒lacakt─▒r.",
            primaryColor,
          ),
          _buildFAQItem(
            "Ô£¿",
            "Uygulamay─▒ kullanmak ├╝cretli mi?",
            "Hay─▒r, BEBOOK tamamen ├╝cretsiz bir platformdur. ─░lan vermek, kitaplar─▒ incelemek ve ├╝ye olmak i├ğin herhangi bir ├╝cret ├Âdemezsiniz.",
            primaryColor,
          ),
          _buildFAQItem(
            "­şöÉ",
            "┼Şifremi unuttum, ne yapmal─▒y─▒m?",
            "Giri┼ş ekran─▒ndaki '┼Şifremi Unuttum' butonuna t─▒klayarak sisteme kay─▒tl─▒ e-posta adresinizi giriniz. E-postan─▒za g├Ânderilen 6 haneli do─şrulama kodunu uygulamaya girerek yeni ┼şifrenizi g├╝venle olu┼şturabilirsiniz.",
            primaryColor,
          ),
          _buildFAQItem(
            "ÔÅ│",
            "─░lan─▒m ne kadar s├╝re yay─▒nda kal─▒r?",
            "─░lan─▒n─▒z, siz manuel olarak silene veya kitap sat─▒lana kadar yay─▒nda kalmaya devam eder.",
            primaryColor,
          ),
          _buildFAQItem(
            "­şÆ¼",
            "Mesaj ikonlar─▒ (tikler) ne anlama geliyor?",
            "ÔÇó Tek Beyaz Tik: Mesaj─▒n─▒z g├Ânderildi.\nÔÇó ├çift Beyaz Tik: Mesaj─▒n─▒z al─▒c─▒ya iletildi.\nÔÇó ├çift Ye┼şil Tik: Mesaj─▒n─▒z al─▒c─▒ taraf─▒ndan okundu.",
            primaryColor,
          ),
          const SizedBox(height: 20),
          const Text(
            "Ba┼şka bir sorun mu var? Destek ekibine ula┼ş─▒n.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(
      String icon, String question, String answer, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Daha oval, daha modern
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06), // Morun ├ğok hafif bir yans─▒mas─▒
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        // ExpansionTile'─▒n i├ğindeki o varsay─▒lan ├ğizgileri tamamen yok eder
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: color,
          collapsedIconColor: Colors.grey.shade400,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading:
              Text(icon, style: const TextStyle(fontSize: 20)), // Ba┼şta ikon
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, bottom: 20, top: 4),
              child: Text(
                answer,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.6, // Sat─▒r aral─▒─ş─▒n─▒ a├ğt─▒k, okumas─▒ kolayla┼şt─▒
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}