# Web Belajar SMK (TKJ & RPL)

## Tujuan
Web latihan untuk siswa SMK: kuis, challenge terminal Linux,
coding puzzle, dan dashboard progres. Dipakai siswa (HP/laptop) dan guru.

## Stack (jangan diganti tanpa tanya)
Next.js (App Router) + TypeScript, Tailwind + shadcn/ui,
Supabase (Postgres, Auth, RLS), Zod, Recharts,
xterm.js, CodeMirror 6, Pyodide di Web Worker. Deploy: Vercel.

## Scope MVP (hanya ini)
1. Challenge terminal Linux
2. Coding puzzle
3. Dashboard progres (siswa & guru)
Kuis pilihan ganda TKJ/RPL = tipe soal di tabel challenges yang sama.

## Di LUAR scope (jangan dikerjakan)
Simulasi jaringan, leaderboard, avatar, AI tutor, duel real-time, panel admin.

## Aturan kerja
- Kerjakan SATU langkah kecil per permintaan, lalu berhenti.
- Jelaskan rencana dulu sebelum mengubah banyak file.
- Kunci jawaban dinilai di server, jangan dikirim ke browser.
- Validasi semua input dengan Zod.
- Nama variabel deskriptif, logika dipisah dari komponen UI.
- Jangan tambah library baru tanpa menjelaskan alasannya.
