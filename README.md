# 🚀 Django Advanced Project Starter

Repositori ini berisi struktur proyek Django yang telah dikonfigurasi untuk kebutuhan aplikasi modern berskala besar, mencakup integrasi API, pemrosesan latar belakang (*background tasks*), dan alat pengembangan tingkat lanjut.

---

## 🛠 Tech Stack & Kapabilitas

Proyek ini dibangun di atas ekosistem Python yang robust dengan kapabilitas utama sebagai berikut:

### 1. Core Framework & API
* **Django & DRF**: Framework utama untuk logika bisnis dan *RESTful API*.
* **CORS Headers**: Keamanan lintas domain (CORS) untuk integrasi dengan frontend modern (React/Vue/Next.js).
* **DRF Spectacular**: Dokumentasi API otomatis berbasis **OpenAPI 3.0** (Swagger/Redoc).

### 2. Task Queue & Real-time Processing
* **Celery & Redis**: Integrasi *Distributed Task Queue* untuk menjalankan tugas berat di latar belakang.
* **Django Celery Results & Beat**:
    * Penyimpanan hasil eksekusi task langsung di database.
    * Penjadwalan tugas rutin (*cron jobs*) melalui admin panel.

### 3. Database & Caching
* **Django Redis**: Penggunaan Redis sebagai backend cache untuk performa tinggi.
* **Django Extensions**: Fitur tambahan seperti `shell_plus` dan visualisasi model.

### 4. Developer Experience (DX)
* **Python Dotenv**: Manajemen konfigurasi lingkungan (`.env`) yang aman.
* **Visualisasi Model**: Menggunakan `pyparsing` & `pydot` untuk menghasilkan diagram skema database.
* **Scraping & Networking**: Terintegrasi dengan `BeautifulSoup4` dan `Requests`.

---

## 📥 Konfigurasi Awal (.env)

Proyek ini menggunakan `python-dotenv`. Buatlah file bernama `.env` di direktori utama proyek dan sesuaikan nilai-nilainya:

```ini
# Django Settings
DEBUG=True
SECRET_KEY=ganti-dengan-key-rahasia-anda
ALLOWED_HOSTS=localhost,127.0.0.1

# Database Settings
DB_NAME=nama_db
DB_USER=user_db
DB_PASSWORD=password_db
DB_HOST=localhost
DB_PORT=5432

# Celery & Redis Settings
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/0
```

# 🚀 Panduan Penggunaan Script

Gunakan routing script ./manage.sh (atau nama script shell Anda) untuk mempermudah alur kerja:
1. ./manage.sh init	Setup awal: venv, install library, dan persiapan environment.
2. ./manage.sh add-app <name>	Membuat Django app baru dengan boilerplate standar.
3. ./manage.sh migrate	Menyiapkan dan menjalankan migrasi database.
4. ./manage.sh run	Menjalankan Django development server.
5. ./manage.sh worker	Menjalankan Celery worker untuk background tasks.
6. ./manage.sh beat	Menjalankan Celery beat untuk task penjadwalan.
7. ./manage.sh graph	Menghasilkan diagram visual skema database (ERD).
8. ./manage.sh reset-db	Menghapus dan membuat ulang database dari nol.


# 📈 Future Works (Rencana Pengembangan)

Beberapa area yang dapat dikembangkan untuk meningkatkan kapabilitas proyek ini:
- Containerization (Docker): Penambahan Dockerfile dan docker-compose.yml untuk isolasi environment penuh.
- Authentication: Implementasi djangorestframework-simplejwt untuk sistem login berbasis token.
- Observability: Integrasi Sentry untuk error tracking dan Prometheus untuk monitoring performa.
- Security: Penambahan django-allauth untuk integrasi Social Auth (Google/GitHub).
- Quality Assurance: Penambahan suite testing menggunakan pytest-django dan integrasi CI/CD GitHub Actions.
