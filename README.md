# Seismograf

Aplikasi Android berbasis Flutter untuk memantau dan merekam getaran secara real-time menggunakan sensor accelerometer perangkat.

## Informasi Mahasiswa & Mata Kuliah
- **Nama**: Aditya Bagas Prakoso
- **NIM**: 24.01.53.0003
- **Kelompok**: A1
- **Mata Kuliah**: Pemrograman Mobile

## Fitur

- **Real-time monitoring** — menampilkan grafik getaran langsung dari accelerometer
- **Rekaman sesi** — mulai/stop rekaman, data tersimpan ke database lokal (SQLite)
- **Snap Data** — tandai titik data penting secara manual saat rekaman berjalan
- **Zeroing / Kalibrasi** — kalibrasi baseline untuk mengurangi efek gravitasi statis
- **Riwayat sesi** — lihat semua sesi rekaman yang pernah dilakukan
- **Filter tanggal** — filter riwayat berdasarkan rentang tanggal
- **Detail sesi** — lihat grafik dan statistik per sesi (max, avg, durasi, jumlah data point)
- **Downsampling otomatis** — dataset besar otomatis di-downsample agar grafik tetap responsif

## Screenshots

<img width="738" height="1200" alt="WhatsApp Image 2026-07-23 at 14 58 11" src="https://github.com/user-attachments/assets/a7bbaf8a-a42f-4ab2-b44b-432a9f4b1066" />

## Tech Stack

| Package | Kegunaan |
|---|---|
| `sensors_plus ^5.0.1` | Membaca data accelerometer |
| `fl_chart ^1.2.0` | Visualisasi grafik real-time |
| `sqflite ^2.4.1` | Database lokal SQLite |
| `path ^1.9.1` | Manajemen path database |

## Cara Menjalankan

1. Pastikan Flutter SDK sudah terinstall (`flutter --version`)
2. Clone repo ini
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Jalankan di perangkat/emulator Android:
   ```bash
   flutter run
   ```

## Struktur Proyek

```
lib/
├── main.dart               # Dashboard utama & sensor stream
├── database_helper.dart    # CRUD SQLite (sessions & vibration logs)
├── history_page.dart       # Halaman riwayat sesi
├── session_detail_page.dart # Detail & grafik per sesi
└── vibration_service.dart  # Kalkulasi magnitude & kalibrasi
```

## Versi

`1.0.0+1` — Flutter SDK `^3.12.2`
