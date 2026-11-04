# UstaGo başlanğıc layihəsi

Bu ZIP Flutter + Firebase başlanğıc kodudur; Play Marketə birbaşa hazır məhsul deyil.

## Antigravity-də
1. ZIP-i aç və qovluğu Antigravity-də aç.
2. Flutter SDK quraşdırılmış olmalıdır.
3. Terminalda `flutter pub get` yaz.
4. Firebase Console-da layihə yarat; Authentication > Email/Password aktiv et; Firestore yarat.
5. Firebase CLI və FlutterFire CLI quraşdırıb `firebase login`, sonra `dart pub global activate flutterfire_cli` və `flutterfire configure` işlət.
6. `main.dart`-da Firebase initialize sətrini FlutterFire-in yaratdığı `firebase_options.dart` ilə tamamla.
7. `firebase/firestore.rules` qaydalarını Firebase Console-a yerləşdir.
8. `flutter run` ilə sına.

## Daxil olanlar
Mavi ana səhifə, kateqoriyalar, Shorts/Alış-veriş bölmə kartları, e-mail/parol qeydiyyatı, dörd rol (Usta, Fəhlə, Müştəri, Satıcı), Firestore profil yazılması və ilkin admin istifadəçi siyahısı.

## Çox vacib
Admin rolunu heç vaxt istifadəçinin özünün seçməsinə icazə vermə. İlk admini yalnız etibarlı server/Cloud Functions vasitəsilə Firebase Custom Claims ilə təyin et və qaydaları buna uyğun yenilə. Buradakı admin ekranı və qaydalar başlanğıc skeletidir; yayımdan əvvəl təhlükəsizlik auditi tələb olunur.

## Hələ yazılmalı funksiyalar
Konum xəritəsi, ustaların axtarışı/filtrləri, elan yaratma/redaktə, şəkil və video yükləmə/sıxışdırma, Shorts pleyeri, mağaza və sifarişlər, daxili mesajlaşma, şikayət sistemi, adminin silmə/redaktə alətləri, audit jurnalı, spam/hücum müdafiəsi, backup, məxfilik siyasəti və Play Market buraxılışı.
