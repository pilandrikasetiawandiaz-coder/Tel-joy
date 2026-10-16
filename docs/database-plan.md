# Rencana Database MVP (Supabase) – Web Belajar SMK TKJ & RPL

## Konteks
MVP butuh penyimpanan untuk challenge (mcq / terminal / coding), percobaan siswa, dan dashboard progres. Data dilindungi RLS; kunci jawaban tidak boleh sampai ke browser; penilaian di server. Setelah disetujui, rencana ini disimpan ke `docs/database-plan.md`. Tidak ada SQL/kode di tahap ini.

## Keputusan (dari klarifikasi)
- Guru terhubung ke **satu kelas** (kolom `kelas` di `users`).
- Kunci jawaban di **tabel terpisah** `challenge_keys` (tabel ke-4, alasan di bawah).
- Siswa boleh **mengulang**; semua percobaan disimpan.
- Guru **boleh membuat challenge lewat aplikasi** → perlu `created_by` dan policy tulis. Catatan: ini hanya form input soal untuk guru, BUKAN panel admin (panel admin tetap di luar scope).

## 1. Tabel, kolom, relasi

### `users` (profil; PK = id Supabase Auth)
| Kolom | Tipe | Catatan |
|---|---|---|
| id | uuid, PK, FK → auth.users(id) on delete cascade | Menautkan ke login |
| full_name | text, not null | Nama tampil di dashboard guru |
| role | enum `siswa`/`guru`, not null | Dasar semua RLS |
| major | enum `TKJ`/`RPL`, not null | Jurusan |
| class_name | text, not null | Mis. "XI TKJ 1" |
| created_at | timestamptz, default now() | |

### `challenges` (tanpa kunci jawaban)
| Kolom | Tipe | Catatan |
|---|---|---|
| id | uuid, PK | |
| type | enum `mcq`/`terminal`/`coding`, not null | |
| major | enum `TKJ`/`RPL`, not null | |
| topic | text, not null | Mis. "Permission file" |
| title | text, not null | |
| prompt | text, not null | Isi soal (markdown) |
| options | jsonb, null | Hanya mcq: daftar pilihan (tanpa penanda benar). Divalidasi Zod |
| starter_code | text, null | Hanya coding |
| max_score | int, default 100 | |
| passing_score | int, not null | Batas lulus |
| created_by | uuid, FK → users(id) | Pemilik soal (untuk policy guru) |
| is_published | boolean, default false | Draft tidak terlihat siswa |
| created_at | timestamptz | |

### `challenge_keys` (hanya server yang boleh baca) – 1:1 dengan challenges
| Kolom | Tipe | Catatan |
|---|---|---|
| challenge_id | uuid, PK, FK → challenges(id) on delete cascade | |
| answer_spec | jsonb, not null | mcq: id opsi benar. terminal: daftar kriteria (perintah/regex/state akhir). coding: test case input→output. Bentuk per tipe divalidasi Zod |

### `attempts`
| Kolom | Tipe | Catatan |
|---|---|---|
| id | uuid, PK | |
| user_id | uuid, FK → users(id) on delete cascade | Siapa |
| challenge_id | uuid, FK → challenges(id) | Soal mana |
| submitted_answer | jsonb | Jawaban/perintah/kode siswa (untuk review guru) |
| score | int, not null | Diisi server |
| passed | boolean, not null | Diisi server |
| duration_seconds | int, not null | Waktu pengerjaan |
| started_at / submitted_at | timestamptz | |
Tidak ada unique (user, challenge) → mengulang diizinkan. Index: (user_id, challenge_id), (challenge_id).

## 2. Alasan & risiko jika dihapus
- **users.role**: dasar RLS; tanpa ini siswa bisa dianggap guru. **major/class_name**: dasar filter guru dan dashboard; tanpa class_name guru tak bisa dibatasi ke kelasnya. **id → auth.users**: tanpa FK, profil bisa yatim/dipalsukan.
- **challenges.type/options/starter_code**: satu tabel untuk tiga tipe sesuai CLAUDE.md; kolom spesifik tipe nullable. **is_published**: cegah soal setengah jadi terlihat. **created_by**: tanpa ini policy "guru hanya ubah soal miliknya" tidak mungkin.
- **challenge_keys terpisah**: RLS Postgres bekerja per baris, bukan per kolom; kolom kunci di tabel yang sama bisa bocor lewat `select *` dari browser. Tabel terpisah tanpa policy untuk siswa/guru = tertutup total; hanya server (service role) yang membaca. Risiko jika digabung: kunci jawaban terbaca langsung.
- **attempts.score/passed**: diisi server saja; jika boleh ditulis klien, siswa bisa menulis skor 100. **submitted_answer**: guru perlu melihat jawaban untuk koreksi; tanpa ini hanya ada angka. **duration_seconds**: diminta; di-hitung server dari started_at/submitted_at agar tak bisa dipalsukan.

## 3. Rancangan RLS (bahasa biasa)
Semua tabel RLS aktif; default tolak. Fungsi bantu (security definer) membaca role & class_name pengguna saat ini agar policy tidak rekursif.

**users**
- Siswa: baca profil sendiri; ubah hanya full_name sendiri (role, major, class_name tidak bisa diubah sendiri).
- Guru: baca profil sendiri dan siswa dengan class_name sama; tidak bisa mengubah profil siswa.
- Insert profil dibuat oleh server/trigger saat registrasi; role `guru` tidak boleh dipilih sendiri saat daftar.

**challenges**
- Siswa: baca hanya yang `is_published` dan major sama dengan jurusannya; tidak bisa tulis.
- Guru: baca semua milik sendiri + yang published; insert (created_by = dirinya), update/delete hanya milik sendiri.

**challenge_keys**
- Tidak ada policy untuk siswa maupun guru → tidak bisa dibaca/ditulis dari browser. Guru menyimpan kunci lewat endpoint server (service role) yang memvalidasi Zod dan memeriksa kepemilikan challenge.

**attempts**
- Siswa: baca hanya miliknya; **tidak ada policy insert/update dari klien**. Percobaan dibuat server setelah menilai (service role) dengan user_id dari sesi, bukan dari body request.
- Guru: baca attempts milik siswa di class_name yang sama; tidak bisa tulis.

## 4. Alur penilaian (server)
Klien kirim jawaban → Route Handler/Server Action memvalidasi Zod → ambil `answer_spec` dengan service role → nilai (mcq: bandingkan; terminal: cek kriteria; coding: jalankan test case hasil Pyodide/output) → tulis `attempts` → kembalikan skor & lulus/tidak (tanpa membocorkan kunci).

## 5. Risiko & hal terbuka
- **Tabel ke-4 `challenge_keys`**: melebihi "tiga tabel"; dijustifikasi untuk keamanan kunci.
- **Pembuatan soal oleh guru** menambah endpoint+UI input soal; jaga tetap sederhana agar tidak jadi panel admin. Disarankan dikerjakan setelah seed soal manual berjalan.
- **Penilaian coding**: jika kode dijalankan di Pyodide di browser, hasilnya tidak tepercaya; kunci tidak dikirim, jadi test case harus dijalankan di server atau lewat mekanisme yang bisa diverifikasi. Perlu keputusan di langkah implementasi (di luar database).
- **Penilaian terminal** (xterm.js, simulasi): kriteria berupa log perintah/state yang dikirim klien bisa dipalsukan; MVP menerima risiko ini atau memverifikasi ulang di server.
- **Guru satu kelas** tidak mencakup guru multi-kelas; bisa diperluas nanti dengan tabel relasi.
- Anti-cheat/rate limit submit belum dirancang (di luar scope).

## Verifikasi (saat implementasi nanti)
- Uji sebagai siswa: `select` dari `challenge_keys` → kosong/ditolak; insert/update ke `attempts` dari klien → ditolak; baca attempts siswa lain → kosong.
- Uji sebagai guru: lihat siswa/attempts kelas sendiri saja; tidak bisa edit challenge milik guru lain.
- Uji alur submit end-to-end: skor dihitung server, kunci tidak muncul di respons jaringan.
