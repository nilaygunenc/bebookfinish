import 'package:flutter/material.dart';
import '../../services/api_service.dart'; // Dosya yolunu kendine göre düzenle

class EditBookScreen extends StatefulWidget {
  final dynamic book; // Map<String, dynamic> olarak gelir

  const EditBookScreen({super.key, required this.book});

  @override
  State<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends State<EditBookScreen> {
  late TextEditingController titleController;
  late TextEditingController priceController;
  late TextEditingController descController;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Backend'den gelen verilere [] ile erişiyoruz
    titleController = TextEditingController(text: widget.book['title']?.toString() ?? "");
    priceController = TextEditingController(text: widget.book['price']?.toString() ?? "");
    descController = TextEditingController(text: widget.book['description']?.toString() ?? "");
  }

  void updateBook() async {
    if (titleController.text.isEmpty || priceController.text.isEmpty) return;

    setState(() => isLoading = true);

    try {
      // api_service.dart içindeki static metodu çağırıyoruz
      final res = await ApiService.updateBook(
        widget.book['book_id'],
        widget.book['user_id'],
        titleController.text,
        double.parse(priceController.text),
        descController.text,
      );

      if (!mounted) return;

      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("İlan başarıyla güncellendi!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Profil sayfasına 'güncellendi' bilgisi gönderir
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("İlanı Düzenle")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Kitap Adı")),
            const SizedBox(height: 10),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: "Fiyat (TL)"), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Açıklama"), maxLines: 3),
            const SizedBox(height: 30),
            isLoading 
              ? const CircularProgressIndicator() 
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: updateBook,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: const Text("GÜNCELLE"),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    priceController.dispose();
    descController.dispose();
    super.dispose();
  }
}