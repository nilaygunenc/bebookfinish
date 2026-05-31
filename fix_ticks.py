import re

with open(r'c:\Users\mertk\OneDrive\Desktop\bitirme-main\bebook\lib\models\chat_detail_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Tik bloğunu bul ve değiştir - satır 344-365 arası
old_block = '''                                            // E─şer mesaj benden gittiyse T─░K g├Âster
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                // ┼ŞEK─░L MANTI─ŞI: Okunduysa veya ─░letildiyse ├ç─░FT T─░K, de─şilse TEK T─░K
                                                (msg.isRead || msg.isDelivered)
                                                    ? Icons.done_all
                                                    : Icons.done,

                                                size: 15,

                                                // RENK MANTI─ŞI:
                                                // 1. Okunduysa -> Neon Ye┼şil
                                                // 2. Sadece iletildiyse -> Parlak Beyaz (├çift Tik)
                                                // 3. Daha iletilmediyse -> S├Ân├╝k Beyaz (Tek Tik)
                                                color: msg.isRead
                                                    ? const Color(0xFF00FF88)
                                                    : (msg.isDelivered
                                                        ? Colors.white
                                                        : Colors.white38),
                                              ),
                                            ],'''

new_block = '''                                            // Tik göstergesi (sadece gönderen için)
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                // TEK TİK: sadece gönderildi
                                                // ÇİFT TİK: iletildi (uygulamaya girdi) veya okundu (sohbete girildi)
                                                msg.isRead
                                                    ? Icons.done_all   // yeşil çift tik
                                                    : msg.isDelivered
                                                        ? Icons.done_all  // beyaz çift tik
                                                        : Icons.done,     // beyaz tek tik
                                                size: 15,
                                                // RENK MANTIĞI:
                                                // 1. Okundu (sohbete girildi) → Yeşil
                                                // 2. İletildi (uygulamaya girdi) → Beyaz
                                                // 3. Sadece gönderildi → Soluk beyaz
                                                color: msg.isRead
                                                    ? const Color(0xFF4CAF50)  // Yeşil çift tik
                                                    : msg.isDelivered
                                                        ? Colors.white          // Beyaz çift tik
                                                        : Colors.white54,       // Soluk beyaz tek tik
                                              ),
                                            ],'''

if old_block in content:
    content = content.replace(old_block, new_block)
    print("✓ Tik bloğu bulundu ve değiştirildi")
else:
    print("✗ Tik bloğu bulunamadı, regex ile deneniyor...")
    # Regex ile dene
    pattern = r'// E.*?gittiyse T.*?K g.*?ster\s+if \(isMe\) \.\.\[\s+const SizedBox.*?Colors\.white38\),\s+\),\s+\],'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        content = content[:match.start()] + new_block + content[match.end():]
        print("✓ Regex ile bulundu ve değiştirildi")
    else:
        print("✗ Regex de bulamadı")

with open(r'c:\Users\mertk\OneDrive\Desktop\bitirme-main\bebook\lib\models\chat_detail_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Dosya kaydedildi.")
