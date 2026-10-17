-- =====================================================================
-- 0001_init.sql — Skema awal Web Belajar SMK (TKJ & RPL)
-- Dijalankan SEKALI lewat SQL Editor Supabase. Dibungkus satu transaksi:
-- kalau ada yang gagal (atau skrip dijalankan ulang), semuanya dibatalkan.
-- Tidak memakai service_role. Tidak ada seed.
-- Rancangan: docs/database-plan.md
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Tipe enum
-- ---------------------------------------------------------------------
create type public.user_role      as enum ('siswa', 'guru');
create type public.major_type     as enum ('TKJ', 'RPL');
create type public.challenge_type as enum ('mcq', 'terminal', 'coding');

-- ---------------------------------------------------------------------
-- 2. Tabel
-- ---------------------------------------------------------------------

-- Profil pengguna, satu baris per akun login. Dihapus otomatis bila akun dihapus.
create table public.users (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null,
  role       public.user_role not null default 'siswa',
  major      public.major_type,   -- kosong dulu, diisi manual
  class_name text,                -- kosong dulu, diisi manual
  created_at timestamptz not null default now()
);

-- Soal (tanpa kunci jawaban).
create table public.challenges (
  id            uuid primary key default gen_random_uuid(),
  type          public.challenge_type not null,
  major         public.major_type not null,
  topic         text not null,
  title         text not null,
  prompt        text not null,
  options       jsonb,            -- hanya mcq: [{"id":"a","text":"..."}]
  starter_code  text,             -- hanya coding
  max_score     int not null default 100 check (max_score > 0),
  passing_score int not null,
  created_by    uuid not null references public.users (id),
  is_published  boolean not null default false,
  created_at    timestamptz not null default now(),
  constraint challenges_passing_score_range
    check (passing_score between 0 and max_score),
  constraint challenges_options_is_array
    check (options is null or jsonb_typeof(options) = 'array'),
  constraint challenges_options_only_mcq
    check ((type = 'mcq') = (options is not null)),
  constraint challenges_starter_code_only_coding
    check (starter_code is null or type = 'coding')
);

-- Kunci jawaban, terpisah dari challenges karena RLS bekerja per baris,
-- bukan per kolom. mcq: {"correct_option_id":"b"}
create table public.challenge_keys (
  challenge_id uuid primary key references public.challenges (id) on delete cascade,
  answer_spec  jsonb not null
);

-- Riwayat percobaan. Siswa boleh mengulang, jadi tidak ada unique (user, challenge).
create table public.attempts (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.users (id) on delete cascade,
  challenge_id     uuid not null references public.challenges (id),  -- restrict: riwayat tidak hilang diam-diam
  submitted_answer jsonb not null,
  score            int not null check (score >= 0),
  passed           boolean not null,
  duration_seconds int not null check (duration_seconds >= 0),
  started_at       timestamptz not null,
  submitted_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. Indeks (Postgres tidak mengindeks kolom FK otomatis)
-- ---------------------------------------------------------------------
create index users_class_name_idx        on public.users (class_name);
create index challenges_major_topic_idx  on public.challenges (major, topic) where is_published;
create index challenges_created_by_idx   on public.challenges (created_by);
create index attempts_user_challenge_idx on public.attempts (user_id, challenge_id);
create index attempts_challenge_idx      on public.attempts (challenge_id);
create index attempts_user_recent_idx    on public.attempts (user_id, submitted_at desc);

-- ---------------------------------------------------------------------
-- 4. Aktifkan RLS di SEMUA tabel + cabut hak bawaan Supabase
--    (default Supabase memberi semua hak ke anon/authenticated;
--     kita cabut lalu beri hanya yang perlu).
-- ---------------------------------------------------------------------
alter table public.users          enable row level security;
alter table public.challenges     enable row level security;
alter table public.challenge_keys enable row level security;
alter table public.attempts       enable row level security;

revoke all on public.users          from anon, authenticated;
revoke all on public.challenges     from anon, authenticated;
revoke all on public.challenge_keys from anon, authenticated;  -- tertutup total dari browser
revoke all on public.attempts       from anon, authenticated;

grant select                         on public.users      to authenticated;
grant update (full_name)             on public.users      to authenticated;  -- hanya nama
grant select, insert, update, delete on public.challenges to authenticated;
grant select                         on public.attempts   to authenticated;  -- tulis hanya lewat fungsi

-- ---------------------------------------------------------------------
-- 5. Fungsi bantu untuk policy
--    security definer = berjalan sebagai pemilik tabel sehingga melewati RLS.
--    Inilah yang mencegah rekursi tak berujung: policy tidak pernah membaca
--    tabel users langsung, hanya memanggil fungsi ini.
--    search_path kosong + nama objek lengkap (public.) agar tidak bisa dibajak.
-- ---------------------------------------------------------------------
create function public.current_user_role()
returns public.user_role
language sql stable security definer set search_path = ''
as $$
  select role from public.users where id = (select auth.uid());
$$;

create function public.current_user_major()
returns public.major_type
language sql stable security definer set search_path = ''
as $$
  select major from public.users where id = (select auth.uid());
$$;

-- True bila pemanggil adalah guru DAN p_user_id adalah siswa di kelas yang sama.
-- class_name kosong tidak pernah cocok (null = null tidak bernilai true).
create function public.is_student_in_my_class(p_user_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.users as teacher
    join public.users as student on student.class_name = teacher.class_name
    where teacher.id   = (select auth.uid())
      and teacher.role = 'guru'
      and student.id   = p_user_id
      and student.role = 'siswa'
  );
$$;

-- ---------------------------------------------------------------------
-- 6. Trigger: buat profil otomatis saat ada pendaftar baru
--    Role SELALU 'siswa' (default kolom). Role/major/class_name TIDAK diambil
--    dari metadata pendaftaran karena bisa diisi sendiri oleh pengguna.
-- ---------------------------------------------------------------------
create function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.users (id, full_name)
  values (
    new.id,
    left(
      coalesce(
        nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
        nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
        'Siswa'
      ),
      100
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Lapisan kedua: siswa/guru dari browser tidak boleh mengubah id, role,
-- jurusan, atau kelas (walau hak kolom suatu hari tidak sengaja diperluas).
-- SQL Editor tidak punya auth.uid(), jadi Anda tetap bisa mengubahnya manual.
create function public.guard_users_update()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if (select auth.uid()) is not null
     and (new.id         is distinct from old.id
       or new.role       is distinct from old.role
       or new.major      is distinct from old.major
       or new.class_name is distinct from old.class_name) then
    raise exception 'Kolom id, role, major, dan class_name tidak boleh diubah.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger users_guard_update
  before update on public.users
  for each row execute function public.guard_users_update();

-- ---------------------------------------------------------------------
-- 7. Fungsi penilaian dan penyimpanan kunci
-- ---------------------------------------------------------------------

-- Siswa menjawab soal pilihan ganda. Skor dihitung di sini, bukan di browser.
-- Mengembalikan hanya skor dan lulus/tidak; opsi yang benar tidak dibocorkan.
create function public.submit_mcq_attempt(
  p_challenge_id       uuid,
  p_selected_option_id text,
  p_started_at         timestamptz
)
returns table (result_score int, result_passed boolean)
language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id        uuid := auth.uid();
  v_student        public.users%rowtype;
  v_challenge      public.challenges%rowtype;
  v_correct_option text;
  v_now            timestamptz := now();
  v_started_at     timestamptz;
  v_score          int;
  v_passed         boolean;
begin
  if v_user_id is null then
    raise exception 'Belum login.' using errcode = '28000';
  end if;

  select * into v_student from public.users where id = v_user_id;
  if not found or v_student.role <> 'siswa' then
    raise exception 'Hanya siswa yang boleh mengirim jawaban.' using errcode = '42501';
  end if;

  if p_selected_option_id is null or p_started_at is null then
    raise exception 'Jawaban dan waktu mulai wajib diisi.' using errcode = '22023';
  end if;

  -- Soal harus pilihan ganda, sudah terbit, dan sesuai jurusan siswa.
  select * into v_challenge
  from public.challenges
  where id = p_challenge_id
    and type = 'mcq'
    and is_published
    and major = v_student.major;
  if not found then
    raise exception 'Soal tidak tersedia.' using errcode = 'P0002';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_challenge.options) as opt
    where opt ->> 'id' = p_selected_option_id
  ) then
    raise exception 'Pilihan jawaban tidak valid.' using errcode = '22023';
  end if;

  select answer_spec ->> 'correct_option_id' into v_correct_option
  from public.challenge_keys
  where challenge_id = p_challenge_id;
  if v_correct_option is null then
    raise exception 'Kunci jawaban belum tersedia.' using errcode = 'P0002';
  end if;

  -- Waktu mulai dari browser tidak sepenuhnya tepercaya: dibatasi 0 sampai 24 jam.
  v_started_at := greatest(least(p_started_at, v_now), v_now - interval '24 hours');

  v_score  := case when p_selected_option_id = v_correct_option
                   then v_challenge.max_score else 0 end;
  v_passed := v_score >= v_challenge.passing_score;

  insert into public.attempts
    (user_id, challenge_id, submitted_answer, score, passed,
     duration_seconds, started_at, submitted_at)
  values
    (v_user_id, p_challenge_id,
     jsonb_build_object('selected_option_id', p_selected_option_id),
     v_score, v_passed,
     floor(extract(epoch from (v_now - v_started_at)))::int,
     v_started_at, v_now);

  return query select v_score, v_passed;
end;
$$;

-- Guru menyimpan/mengganti kunci jawaban untuk soal MILIKNYA.
create function public.save_challenge_key(
  p_challenge_id uuid,
  p_answer_spec  jsonb
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_challenge      public.challenges%rowtype;
  v_correct_option text;
begin
  if auth.uid() is null or public.current_user_role() is distinct from 'guru' then
    raise exception 'Hanya guru yang boleh menyimpan kunci jawaban.' using errcode = '42501';
  end if;

  select * into v_challenge
  from public.challenges
  where id = p_challenge_id and created_by = auth.uid();
  if not found then
    raise exception 'Soal tidak ditemukan atau bukan milik Anda.' using errcode = '42501';
  end if;

  if p_answer_spec is null or jsonb_typeof(p_answer_spec) <> 'object' then
    raise exception 'Bentuk kunci jawaban tidak valid.' using errcode = '22023';
  end if;

  -- Pemeriksaan minimal untuk mcq; bentuk lengkap divalidasi Zod di aplikasi.
  if v_challenge.type = 'mcq' then
    v_correct_option := p_answer_spec ->> 'correct_option_id';
    if v_correct_option is null or not exists (
      select 1 from jsonb_array_elements(v_challenge.options) as opt
      where opt ->> 'id' = v_correct_option
    ) then
      raise exception 'correct_option_id harus salah satu id pilihan.' using errcode = '22023';
    end if;
  end if;

  insert into public.challenge_keys (challenge_id, answer_spec)
  values (p_challenge_id, p_answer_spec)
  on conflict (challenge_id) do update set answer_spec = excluded.answer_spec;
end;
$$;

-- Hak eksekusi: default Supabase memberi execute ke anon; cabut, lalu beri
-- hanya ke pengguna login. Fungsi trigger tidak perlu bisa dipanggil siapa pun.
revoke all on function public.current_user_role()            from public, anon, authenticated;
revoke all on function public.current_user_major()           from public, anon, authenticated;
revoke all on function public.is_student_in_my_class(uuid)   from public, anon, authenticated;
revoke all on function public.handle_new_user()              from public, anon, authenticated;
revoke all on function public.guard_users_update()           from public, anon, authenticated;
revoke all on function public.submit_mcq_attempt(uuid, text, timestamptz) from public, anon, authenticated;
revoke all on function public.save_challenge_key(uuid, jsonb) from public, anon, authenticated;

grant execute on function public.current_user_role()          to authenticated;
grant execute on function public.current_user_major()         to authenticated;
grant execute on function public.is_student_in_my_class(uuid) to authenticated;
grant execute on function public.submit_mcq_attempt(uuid, text, timestamptz) to authenticated;
grant execute on function public.save_challenge_key(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 8. Policy RLS (tabel yang tidak punya policy = tertutup total)
-- ---------------------------------------------------------------------

-- users: siswa baca diri sendiri; guru baca diri sendiri + siswa sekelas.
create policy users_select_own on public.users
  for select to authenticated
  using (id = (select auth.uid()));

create policy users_select_class_for_teacher on public.users
  for select to authenticated
  using (public.is_student_in_my_class(id));

-- Hanya baris sendiri; kolom yang boleh diubah dibatasi hak kolom (full_name).
create policy users_update_own on public.users
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- challenges: siswa baca yang terbit & sejurusan.
create policy challenges_select_student on public.challenges
  for select to authenticated
  using (
    (select public.current_user_role()) = 'siswa'
    and is_published
    and major = (select public.current_user_major())
  );

-- challenges: guru baca miliknya + yang terbit.
create policy challenges_select_teacher on public.challenges
  for select to authenticated
  using (
    (select public.current_user_role()) = 'guru'
    and (created_by = (select auth.uid()) or is_published)
  );

create policy challenges_insert_teacher on public.challenges
  for insert to authenticated
  with check (
    (select public.current_user_role()) = 'guru'
    and created_by = (select auth.uid())
  );

create policy challenges_update_own_teacher on public.challenges
  for update to authenticated
  using (
    (select public.current_user_role()) = 'guru'
    and created_by = (select auth.uid())
  )
  with check (
    (select public.current_user_role()) = 'guru'
    and created_by = (select auth.uid())
  );

create policy challenges_delete_own_teacher on public.challenges
  for delete to authenticated
  using (
    (select public.current_user_role()) = 'guru'
    and created_by = (select auth.uid())
  );

-- challenge_keys: SENGAJA tanpa policy. Hanya fungsi security definer di atas
-- yang menyentuhnya.

-- attempts: siswa baca miliknya; guru baca milik siswa sekelas.
-- Tidak ada policy INSERT/UPDATE/DELETE: penambahan hanya lewat submit_mcq_attempt.
create policy attempts_select_own on public.attempts
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy attempts_select_class_for_teacher on public.attempts
  for select to authenticated
  using (public.is_student_in_my_class(user_id));

commit;

-- =====================================================================
-- OPSIONAL — jalankan manual (bukan bagian migrasi), satu per satu.
-- =====================================================================

-- (a) Menjadikan sebuah akun guru dan mengisi kelasnya:
--   update public.users
--   set role = 'guru', major = 'TKJ', class_name = 'XI TKJ 1'
--   where id = '<uuid-akun-guru>';

-- (b) Mengisi jurusan dan kelas siswa:
--   update public.users
--   set major = 'TKJ', class_name = 'XI TKJ 1'
--   where id = '<uuid-siswa>';

-- (c) Akun yang sudah terdaftar SEBELUM migrasi ini belum punya profil.
--     Buatkan profilnya (semua jadi siswa):
--   insert into public.users (id, full_name)
--   select id, coalesce(nullif(split_part(email, '@', 1), ''), 'Siswa')
--   from auth.users
--   where id not in (select id from public.users);
