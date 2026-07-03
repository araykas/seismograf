Tahap 1: Inisialisasi Dasar & Integrasi Sensor
Indikator Keberhasilan: * Aplikasi berhasil berjalan di HP/Emulator tanpa error layar merah.

Kalian melihat sebuah angka di tengah layar yang terus berubah dengan cepat.

Saat HP digoyangkan dengan keras, angka tersebut melonjak naik; saat HP diletakkan diam di atas meja, angkanya stabil (biasanya di kisaran 9.8 karena efek gravitasi bumi).

Indikator Kegagalan: * Aplikasi crash atau tertutup sendiri saat baru dibuka.

Angka di layar tetap 0 atau tidak bergerak sama sekali saat HP digoyangkan (biasanya karena lupa memanggil stream dari sensors_plus).

Tahap 2: Implementasi Grafik Real-Time (Throttling)
Indikator Keberhasilan:

Angka teks tadi berhasil digantikan dengan grafik garis (LineChart).

Grafik terus bergeser ke kiri seiring berjalannya waktu, dan hanya menampilkan 50 titik terakhir tanpa keluar dari batas layar.

Animasi grafik terlihat mulus dan HP tidak terasa lag atau panas.

Indikator Kegagalan:

Aplikasi patah-patah (lag parah) atau UI macet (Ini menandakan sistem throttling 200ms gagal dan aplikasi mencoba menggambar ulang grafik ratusan kali per detik).

Muncul error garis kuning-hitam (overflow) karena widget grafik tidak diberi ukuran tinggi/lebar yang pasti.

Tahap 3: Pembuatan Sistem Database SQLite
Indikator Keberhasilan:

Tombol "Mulai Rekam" dan "Hentikan" bisa diklik dan mengubah status UI (misalnya tombol berubah warna).

Saat menekan "Hentikan", tidak ada pesan error di konsol terminal, menandakan data berhasil dimasukkan (INSERT) ke tabel SQLite.

Tombol "Snap Data" (Manual) tidak membuat aplikasi crash jika ditekan berkali-kali.

Indikator Kegagalan:

Aplikasi crash saat tombol "Mulai Rekam" ditekan (Biasanya karena tabel database belum terinisiasi sempurna atau ada typo di nama tabel/kolom).

Muncul pesan error Database Lock atau Null Pointer Exception di log terminal.

Tahap 4: Riwayat Visualisasi & Filter Data
Indikator Keberhasilan:

Kalian bisa berpindah ke halaman "Riwayat" dan melihat daftar sesi getaran yang sudah direkam sebelumnya.

Saat salah satu riwayat diklik, muncul grafik statis yang menampilkan seluruh durasi getaran pada sesi tersebut dari awal sampai akhir.

Filter kalender (DateRangePicker) berhasil menyembunyikan riwayat yang tidak sesuai tanggal.

Indikator Kegagalan:

Halaman riwayat kosong melompong padahal kalian yakin sudah merekam data di Tahap 3.

Aplikasi crash saat membuka halaman detail (Biasanya karena masalah parsing format waktu ISO8601 dari string SQLite kembali menjadi format DateTime Dart).

Tahap 5: Fitur Tambahan & Polishing UI
Indikator Keberhasilan:

Fitur Zeroing berfungsi: Saat HP diam di meja, grafik menunjukkan garis lurus di angka 0 (bukan 9.8).

Tampilan aplikasi terlihat rapi, transisi antar halaman mulus, dan informasi mudah dibaca.

Indikator Kegagalan:

Perhitungan Zeroing salah sehingga saat HP digoyang ke arah tertentu, angkanya malah menjadi minus secara tidak wajar atau kacau.