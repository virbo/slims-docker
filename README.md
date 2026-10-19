# SLiMS 9 Bulian — Docker deployment package

Paket ini membangun image sendiri dari source resmi **SLiMS 9 Bulian v9.8.0**, memublikasikannya ke GHCR melalui GitHub Actions, dan menjalankannya dengan Docker Compose + MariaDB.

Source/release yang dipakai: https://github.com/slims/slims9_bulian/releases/tag/v9.8.0

## Isi paket

- `Dockerfile` — build PHP 8.3-FPM + Nginx + ekstensi PHP, Composer dependencies, source SLiMS resmi.
- `docker-compose.yml` — SLiMS, MariaDB, initializer skema yang aman, named volumes.
- `.dockerignore` — mengecualikan secrets dan file lokal.
- `nginx/nginx.conf` dan `nginx/slims.conf` — konfigurasi Nginx + PHP-FPM.
- `docker/entrypoint.sh` — menunggu database dan menyiapkan konfigurasi dari environment; tidak mengubah password admin.
- `docker/db-init.sh` — hanya mengimpor skema bila database belum memiliki tabel; tidak mengimpor sample data.
- `docker/render-config.php` — membuat konfigurasi DB dari environment.
- `.github/workflows/publish.yml` — build dan push image ke GHCR.

## Compatibility checks

Repository resmi v9.8.0 mencantumkan PHP >= 8.1, MySQL 5.7 atau MariaDB >= 10.3, serta ekstensi GD, gettext, dan mbstring. Dockerfile ini menggunakan PHP 8.3 + Nginx dan ekstensi tambahan yang ada pada Dockerfile resmi (intl, xml, xmlwriter, zip, mysqli, pdo_mysql, iconv). MariaDB 11.4 digunakan sebagai target LTS modern. Build CI menjalankan Composer install; tetap lakukan smoke test aplikasi sebelum produksi.

Image menghapus direktori installer web dari image akhir, seperti pendekatan Dockerfile upstream. Skema database diambil dari `install/senayan.sql` sebelum direktori installer dihapus.

## 1. Buat repository GitHub

1. Buat repository baru, misalnya `slims-docker-deployment`.
2. Ekstrak paket ini dan commit semua file ke root repository tersebut.
3. Pastikan default branch bernama `main` atau `master`.
4. Push ke GitHub. Workflow akan membangun image dan menerbitkan tag `dev` untuk default branch `main`/`master`, serta tag SHA untuk setiap push. Tag `v*` menghasilkan tag versi.

Image GHCR akan bernama `ghcr.io/OWNER/REPOSITORY` (huruf kecil). Package pertama kali mungkin private; atur visibility/akses package di GitHub sesuai kebijakan Anda.

## 2. Buat `.env` pada server

Salin `.env.example` menjadi `.env`, lalu isi `IMAGE_NAME` dengan nama image GHCR yang benar. Gunakan password acak panjang:

```bash
cp .env.example .env
openssl rand -hex 32
```

Jalankan perintah `openssl rand -hex 32` dua kali dan gunakan hasil berbeda untuk `DB_PASSWORD` dan `DB_ROOT_PASSWORD`. Lindungi file:

```bash
chmod 600 .env
```

Jangan commit `.env` ke Git. Pastikan `IMAGE_TAG=dev` bila server mengikuti build default branch.

## 3. Login ke GHCR dari server

Untuk package private, gunakan GitHub Personal Access Token (classic) dengan `read:packages`:

```bash
echo 'TOKEN_GHCR' | docker login ghcr.io -u USERNAME_GITHUB --password-stdin
```

Jangan simpan token di repository atau file `.env`.

## 4. Jalankan deployment

```bash
docker compose config
docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f slims
```

Akses `http://IP-SERVER:8080` (atau port yang Anda isi pada `HTTP_PORT`). Database tidak dipublikasikan ke port host; hanya dapat diakses melalui jaringan internal Compose.

Initializer hanya mengimpor `install/senayan.sql` jika database target benar-benar tidak memiliki tabel. Ia tidak memuat `sampledata.sql`. Jika tabel sudah ada, ia melewati import tanpa mengubah tabel/data. Periksa log `db-init` setelah deployment.

## 5. Data persisten

Named volumes yang digunakan:

- `slims_db_data` — database MariaDB.
- `slims_files` — file/attachment.
- `slims_images` — gambar.
- `slims_repository` — repository file SLiMS.

**Jangan menjalankan `docker compose down -v`** untuk deployment rutin. Perintah itu menghapus named volumes dan dapat menghilangkan data. Jangan mengubah nama project Compose atau nama volume ketika upgrade sebelum memetakan volume lama.

### Sebelum mengganti image pada server yang sudah memiliki instalasi SLiMS

1. Buat backup database dan seluruh volume/file SLiMS.
2. Identifikasi nama volume yang sedang digunakan (`docker volume ls`, `docker inspect`).
3. Jangan langsung menjalankan Compose ini pada instalasi lama: nama volume baru dibuat secara terpisah dan database baru bisa terlihat kosong, sementara data lama tetap berada pada volume lama.
4. Rencanakan migrasi/restore secara eksplisit. Jangan mengimpor skema ke database produksi yang sudah memiliki tabel.

## 6. Operasi dan troubleshooting

```bash
docker compose logs --tail=200 db
docker compose logs --tail=200 db-init
docker compose logs --tail=200 slims
docker compose exec slims php -m
docker compose exec db mariadb-admin ping -h 127.0.0.1
```

Jika image belum muncul di GHCR, periksa tab **Actions** di GitHub. Untuk build di branch default, tag `dev` akan diterbitkan. Pull request hanya membangun image tanpa push.

## Catatan keamanan

- Ubah kredensial database contoh sebelum deployment.
- Ganti password administrator awal SLiMS sesegera mungkin dan jangan mengekspos instalasi sebelum hardening selesai.
- Gunakan HTTPS melalui reverse proxy dan batasi akses administrasi.
- Lakukan backup dan uji restore.
- Perbarui `SLIMS_REF` pada workflow/Dockerfile setelah menguji rilis resmi baru; jangan mengikuti branch `master` secara otomatis di produksi.
- Build ini mengunci source pada `v9.8.0`, tetapi base image PHP dan MariaDB masih menggunakan tag versi yang dapat menerima pembaruan patch. Untuk reproducibility lebih ketat, pin digest image setelah diuji.
