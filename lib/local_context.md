# Local Context: Pengembangan Aplikasi Seismograf (Vibration Tracker)

Dokumen ini berfungsi sebagai panduan konteks lokal (`local_context.md`) untuk memandu pembuatan aplikasi secara bertahap (step-by-step) menggunakan AI Code Assistant atau sebagai blueprint pengembangan mandiri.

---

## 1. Ringkasan Proyek (Project Overview)
* **Nama Aplikasi:** SeismoTrack / QuakeMeter
* **Deskripsi:** Aplikasi mobile berbasis Flutter untuk mendeteksi, mengukur, dan merekam getaran secara real-time menggunakan sensor Accelerometer pada perangkat. Data intensitas getaran akan direkam dan disimpan ke dalam database lokal SQLite untuk visualisasi riwayat pemantauan di kemudian hari.
* **Target Pengguna:** Individu yang membutuhkan alat praktis untuk mengukur getaran mesin, eksperimen fisika, atau deteksi gempa sederhana.
* **Spesifikasi Target:** Android OS (Kompilasi menggunakan Android SDK 36, Bahasa: Kotlin/Dart).

---

## 2. Rincian Fitur Utama (Feature Details)
Aplikasi ini difokuskan pada tiga pilar utama: Pengukuran, Penyimpanan, dan Visualisasi.

### A. Pengukuran Getaran & Dashboard Utama
* **Accelerometer Real-Time Tracking:** Mengakses data sensor accelerometer (sumbu X, Y, Z) secara terus-menerus.
* **Kalkulasi Magnitudo:** Menghitung total intensitas getaran menjadi satu nilai tunggal menggunakan rumus magnitudo vektor: $magnitude = \sqrt{x^2 + y^2 + z^2}$ (dengan mengabaikan gravitasi bumi $\approx 9.8 m/s^2$ jika diperlukan untuk mendapatkan *linear acceleration*).
* **Indikator Status:** Menampilkan nilai getaran saat ini dengan indikator visual (misal: Aman, Getaran Sedang, Getaran Kuat).

### B. Penyimpanan Data & Manajemen Sesi (SQLite)
* **Kontrol Sesi Pemantauan:** Terdapat tombol interaktif "Mulai Rekam" dan "Hentikan Rekam".
* **Perekaman Otomatis (Interval):** Saat sesi aktif, aplikasi akan mencatat nilai intensitas getaran ke dalam database SQLite secara otomatis dengan interval waktu tertentu (misalnya setiap 1 detik).
* **Perekaman Manual (Opsional):** Tombol khusus "Snap Data" untuk menyimpan rekor/lonjakan getaran secara manual ke dalam log pada detik tersebut.
* **Kalkulasi Sesi:** Saat sesi diakhiri, aplikasi menghitung durasi total, rata-rata getaran, dan getaran puncak (Peak/Max) untuk disimpan di tabel riwayat.

### C. Visualisasi Data & Riwayat
* **Grafik Live (Real-Time Chart):** Sebuah *rolling line chart* (grafik garis yang terus bergeser) di halaman utama yang menampilkan fluktuasi getaran selama 50 titik terakhir dengan frekuensi *update* yang cepat.
* **Daftar Riwayat (History List):** Halaman terpisah yang menampilkan daftar seluruh sesi pemantauan, diurutkan dari yang terbaru.
* **Detail & Grafik Statis:** Saat satu riwayat diklik, muncul halaman detail yang berisi grafik garis utuh dari titik awal hingga akhir sesi tersebut.
* **Filter Waktu:** Fitur Date Range Picker untuk menyaring daftar riwayat berdasarkan rentang tanggal tertentu.

---

## 3. Struktur Arsitektur & Teknologi (Tech Stack & Locked Versions)
Untuk menghindari konflik dependency dan error kompilasi, proyek ini wajib menggunakan versi berikut:
* **Framework Utama:** Flutter v3.44.2 (Dart SDK ^3.12.2)
* **Target SDK Android:** `compileSdk = 36`
* **Manajemen Sensor:** `sensors_plus: ^5.0.1` (Untuk membaca data accelerometer)
* **Penyimpanan Lokal:** `sqflite: ^2.4.1` & `path: ^1.9.1`
* **Visualisasi Grafik:** `fl_chart: ^1.2.0` (Mendukung performa tinggi untuk grafik real-time)
* **Desain UI:** `cupertino_icons: ^1.0.9` & Material Design 3
* **State Management:** Dimulai dengan `setState` / `StreamBuilder` untuk kesederhanaan.

---

## 4. Skema Database (SQLite Schema)

Aplikasi akan menggunakan dua tabel utama untuk efisiensi penyimpanan:

### Tabel `monitoring_sessions` (Sesi Pemantauan)
Menyimpan ringkasan setiap sesi perekaman getaran.
* `id`: INTEGER PRIMARY KEY AUTOINCREMENT
* `start_time`: TEXT (Format ISO8601 UTC)
* `end_time`: TEXT (Format ISO8601 UTC)
* `max_vibration`: REAL (Nilai puncak getaran selama sesi)
* `avg_vibration`: REAL (Rata-rata intensitas getaran)

### Tabel `vibration_logs` (Detail Titik Getaran)
Menyimpan nilai getaran berdasarkan interval waktu atau input manual.
* `id`: INTEGER PRIMARY KEY AUTOINCREMENT
* `session_id`: INTEGER (FOREIGN KEY merujuk ke `monitoring_sessions.id` ON DELETE CASCADE)
* `timestamp`: TEXT (Format ISO8601)
* `magnitude`: REAL (Nilai intensitas getaran pada detik tersebut)
* `is_manual`: INTEGER (0 untuk auto-interval, 1 untuk manual snap)

---

## 5. Panduan Pengembangan Bertahap (Step-by-Step Prompt Roadmap)

Gunakan urutan prompt berikut untuk membangun aplikasi ini secara bertahap agar meminimalkan error kompilasi dan konflik dependency.

### Tahap 1: Inisialisasi Dasar & Integrasi Sensor
* **Tujuan:** Membuat kerangka dasar aplikasi dan membaca data stream dari Accelerometer.
* **Prompt AI:**
  > "Buat struktur dasar aplikasi Flutter untuk Seismograf menggunakan package sensors_plus versi ^5.0.1. Buat UI sederhana yang membaca data dari `accelerometerEventStream()`. Hitung magnitudonya dengan rumus akar dari x kuadrat ditambah y kuadrat ditambah z kuadrat. Tampilkan nilai magnitudo tersebut di tengah layar secara real-time menggunakan StreamBuilder."

### Tahap 2: Implementasi Grafik Real-Time (Throttling)
* **Tujuan:** Mengubah angka menjadi grafik garis bergerak yang responsif namun tidak membuat UI lag.
* **Prompt AI:**
  > "Lanjutkan proyek sebelumnya. Gunakan package fl_chart versi ^1.2.0. Buat sebuah widget grafik garis (`LineChart`) di dashboard utama. Karena data accelerometer sangat cepat, buat sistem 'throttling' atau update grafik setiap 200 milidetik saja. Batasi grafik agar hanya menampilkan 50 titik terakhir (rolling window chart) agar visualisasi getaran terlihat seperti seismograf asli."

### Tahap 3: Pembuatan Sistem Database SQLite
* **Tujuan:** Membuat kelas helper database untuk menyimpan sesi getaran.
* **Prompt AI:**
  > "Lanjutkan proyek. Gunakan package sqflite versi ^2.4.1 dan path versi ^1.9.1. Buat sebuah DatabaseHelper untuk mengelola dua tabel: `monitoring_sessions` dan `vibration_logs`. Buat tombol 'Mulai Rekam', 'Hentikan', dan 'Snap Data' (Manual). Saat rekam aktif, jalankan Timer yang menyimpan nilai rata-rata getaran per detik ke tabel `vibration_logs` secara otomatis."

### Tahap 4: Riwayat Visualisasi & Filter Data
* **Tujuan:** Menampilkan riwayat sesi pemantauan dan memvisualisasikan kembali datanya.
* **Prompt AI:**
  > "Lanjutkan proyek. Buat halaman baru bernama 'Riwayat Pemantauan' (History Page). Tampilkan daftar sesi dari tabel `monitoring_sessions` dalam ListTile. Jika diklik, buka halaman detail berisi `LineChart` dari fl_chart yang mem-plot seluruh data dari `vibration_logs` milik sesi tersebut. Tambahkan fitur DateRangePicker untuk memfilter riwayat berdasarkan tanggal."

### Tahap 5: Fitur Tambahan & Polishing UI
* **Tujuan:** Menyempurnakan perhitungan sensor dan merapikan UI.
* **Prompt AI:**
  > "Lakukan penyempurnaan akhir. Tambahkan fitur kalibrasi atau 'Zeroing' untuk mengurangi nilai gravitasi (9.8) agar grafik berada di titik 0 saat HP diam di atas meja. Rapikan tampilan, pastikan transisi antar halaman mulus, dan pastikan koneksi database ditutup dengan benar saat aplikasi di-destroy."

---

## 6. Aturan Penting Koding (Coding Rules)
1. **Performa Sensor (Throttling):** Sensor Accelerometer mengeluarkan ratusan event per detik. Dilarang melakukan re-render UI (`setState`) setiap kali event masuk. Gunakan Stream Transformation atau Timer interval (misal: 200ms) untuk memperbarui State UI dan Grafik.
2. **Kepatuhan Dependency:** Selalu patuhi penguncian versi package di bagian Tech Stack.
3. **Format Waktu:** Semua penyimpanan waktu ke SQLite wajib menggunakan format standard ISO8601 string (`DateTime.now().toIso8601String()`) agar mudah difilter melalui SQL.
4. **Isolasi Logika:** Pisahkan kalkulasi matematika (perhitungan magnitudo/kalibrasi) ke dalam fungsi atau class *service* tersendiri di luar file UI.