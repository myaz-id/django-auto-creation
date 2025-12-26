#!/bin/bash

# ==============================================================================
# DJANGO ENTERPRISE CLI - ULTIMATE VERSION (Fixed Logic & Auto-Graph)
# ==============================================================================

PYTHON_BIN=python3
VENV_DIR=venv
APPS_DIR="apps"
CONFIG_DIR="config"

# UI Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${BLUE}▶ $1${NC}"; }
warn() { echo -e "${RED}⚠️ $1${NC}"; }
die()  { echo -e "${RED}❌ $1${NC}"; exit 1; }
exists() { [ -e "$1" ]; }

# ---------------- UTILS ----------------

ensure_venv() {
  if ! exists "$VENV_DIR"; then
    log "Membuat virtualenv..."
    $PYTHON_BIN -m venv "$VENV_DIR"
  fi
  source "$VENV_DIR/bin/activate"
}

py_replace() {
  export SEARCH_STR="$1"
  export REPLACE_STR="$2"
  python3 -c "import sys, os; sys.stdout.write(sys.stdin.read().replace(os.getenv('SEARCH_STR'), os.getenv('REPLACE_STR')))"
}

# ---------------- HELPER FOR URLS ----------------

inject_app_urls() {
  export APP_NAME=$1
  export APP_PATH=$2
  python3 <<'PY'
import os
from pathlib import Path
urls_file = Path("config/urls.py")
if urls_file.exists():
    content = urls_file.read_text()
    app_name = os.getenv('APP_NAME')
    app_path = os.getenv('APP_PATH')
    entry = f"    path('{app_name}/', include('{app_path}.urls')),"
    if entry not in content:
        content = content.replace("urlpatterns = [", f"urlpatterns = [\n{entry}")
        urls_file.write_text(content)
PY
}

# ---------------- COMMANDS ----------------

cmd_init() {
  set -e
  PROJECT_NAME=$1
  [ -z "$PROJECT_NAME" ] && die "Nama project wajib."

  ensure_venv
  log "Menginstal Enterprise Packages..."
  pip install --upgrade pip
  pip install django djangorestframework django-cors-headers celery redis django-celery-results django-celery-beat django-redis \
              python-dotenv drf-spectacular django-extensions ipython \
              pyparsing pydot  beautifulsoup4 requests # Required for graph_models

  # 1. Scaffolding Project
  if ! exists "manage.py"; then
    log "Scaffolding Django Project..."
    django-admin startproject "$PROJECT_NAME" .
    mv "$PROJECT_NAME" "$CONFIG_DIR"
  fi

  # 2. Struktur Dasar
  mkdir -p "$APPS_DIR" "$CONFIG_DIR/settings" templates
  touch "$APPS_DIR/__init__.py" "$CONFIG_DIR/settings/__init__.py"

  # Fix manage.py / wsgi / asgi (Gunakan Python agar cross-platform safe)
  for f in manage.py "$CONFIG_DIR/wsgi.py" "$CONFIG_DIR/asgi.py"; do
    if [ -f "$f" ]; then
        python3 -c "from pathlib import Path; p=Path('$f'); p.write_text(p.read_text().replace('$PROJECT_NAME.settings', 'config.settings.dev'))"
    fi
  done

  # 3. Create .env
  if ! exists ".env"; then
    cat <<EOF > .env
DEBUG=True
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')
DJANGO_SETTINGS_MODULE=config.settings.dev
ALLOWED_HOSTS=*
REDIS_URL=redis://127.0.0.1:6379/0
CELERY_BROKER_URL=redis://127.0.0.1:6379/0
EOF
  fi

  # 5. Buat App Accounts (Custom User)
  if [ ! -d "$APPS_DIR/accounts" ]; then
    log "Membuat app accounts..."
    mkdir -p "$APPS_DIR/accounts"
    python manage.py startapp accounts "$APPS_DIR/accounts"
    
    # Fix AppConfig
    python3 -c "from pathlib import Path; p=Path('apps/accounts/apps.py'); p.write_text(p.read_text().replace(\"name = 'accounts'\", \"name = 'apps.accounts'\"))"
    
    cat <<'EOF' > apps/accounts/models.py
from django.contrib.auth.models import AbstractUser
from django.db import models
class User(AbstractUser):
    employee_id = models.CharField(max_length=30, unique=True, null=True, blank=True)
EOF
    touch apps/accounts/urls.py
    echo "from django.urls import path" > apps/accounts/urls.py
    echo "app_name = 'accounts'" >> apps/accounts/urls.py
    echo "urlpatterns = []" >> apps/accounts/urls.py
  fi

  # 6. Tulis ROOT URLS
  log "Menyusun config/urls.py..."
  cat <<'EOF' > "$CONFIG_DIR/urls.py"
from django.contrib import admin
from django.urls import path, include
from django.views.generic import TemplateView
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/schema/", SpectacularAPIView.as_view(), name='schema'),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name='schema')),
    path("", TemplateView.as_view(template_name="index.html")),
]
EOF

  # 7. Inject Accounts URL & Template
  inject_app_urls "accounts" "apps.accounts"

  # 4. Tulis SETTINGS (Base.py) - Tulis dulu agar app bisa didaftarkan
  log "Menyusun config/settings/base.py..."
  cat <<'EOF' > "$CONFIG_DIR/settings/base.py"
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()
BASE_DIR = Path(__file__).resolve().parents[2]
SECRET_KEY = os.getenv("SECRET_KEY")
DEBUG = os.getenv("DEBUG") == "True"
ALLOWED_HOSTS = os.getenv("ALLOWED_HOSTS", "*").split(",")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "corsheaders",
    "django_extensions",
    "django_celery_results",
    "django_celery_beat",
    "drf_spectacular",
    "apps.accounts",
]

AUTH_USER_MODEL = "accounts.User"

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates",
    "DIRS": [BASE_DIR / "templates"],
    "APP_DIRS": True,
    "OPTIONS": {"context_processors": [
        "django.template.context_processors.debug",
        "django.template.context_processors.request",
        "django.contrib.auth.context_processors.auth",
        "django.contrib.messages.context_processors.messages",
    ]},
}]

DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": BASE_DIR / "db.sqlite3"}}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
STATIC_URL = "/static/"

# ---------- DJANGO LOGGER ----------
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'simple'
        },
        'file_errors': {
            'level': 'ERROR',
            'class': 'logging.FileHandler',
            'filename': os.path.join(BASE_DIR, 'debug_errors.log'),
            'formatter': 'verbose'
        },
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file_errors'],
            'level': 'INFO',
            'propagate': True,
        },
        'myapp': { # A custom logger for your application's code
            'handlers': ['console', 'file_errors'],
            'level': 'DEBUG', # Log all messages in your app
            'propagate': False, # Prevent messages from going to the root logger's handlers
        },
    },
}

# ---------- DJANGO REST FRAMEWORK ----------
REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.AllowAny"],
    "DEFAULT_AUTHENTICATION_CLASSES": ["rest_framework.authentication.SessionAuthentication"],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "PAGE_SIZE": 10,
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Project Development Version 1.0",
    "DESCRIPTION": "API Backend Documentation",
    "VERSION": "1.0.0",
}

# ---------- CORS HEADERS ----------
CORS_ALLOW_ALL_ORIGINS = True # Set to False and use CORS_ALLOWED_ORIGINS in Production

# ---------- CELERY SETTINGS ----------
CELERY_BROKER_URL = os.getenv("CELERY_BROKER_URL", "redis://127.0.0.1:6379/0")
CELERY_RESULT_BACKEND = os.getenv("CELERY_RESULT_BACKEND", "redis://127.0.0.1:6379/0")
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = "Asia/Jakarta"
CELERY_BEAT_SCHEDULER = 'django_celery_beat.schedulers:DatabaseScheduler'

# ---------- REDIS CACHE ----------
CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": f"redis://127.0.0.1:6379/1",
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.DefaultClient",
        },
    }
}

EOF
  echo "from .base import *" > "$CONFIG_DIR/settings/dev.py"


  # 9. Membuat Index.html
  cat <<EOF > templates/index.html
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>{% block title %}Enterprise Django{% endblock %}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <!-- Bootstrap 5 -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">

    <!-- Bootstrap Icons -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons/font/bootstrap-icons.css" rel="stylesheet">

    <!-- Google Font -->
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <style>
        body {
            font-family: 'Inter', sans-serif;
            background-color: #f4f6f9;
        }

        /* Sidebar */
        .sidebar {
            width: 260px;
            min-height: 100vh;
            background: linear-gradient(180deg, #0d6efd, #0b5ed7);
            color: #fff;
            position: fixed;
        }

        .sidebar .brand {
            font-size: 1.25rem;
            font-weight: 700;
            padding: 1.5rem;
            text-align: center;
            background: rgba(0, 0, 0, 0.1);
        }

        .sidebar a {
            color: rgba(255, 255, 255, 0.85);
            text-decoration: none;
            padding: 12px 20px;
            display: flex;
            align-items: center;
            gap: 10px;
            font-weight: 500;
        }

        .sidebar a:hover,
        .sidebar a.active {
            background: rgba(255, 255, 255, 0.15);
            color: #fff;
        }

        .sidebar .menu-title {
            font-size: 0.7rem;
            text-transform: uppercase;
            opacity: 0.7;
            padding: 12px 20px 6px;
        }

        /* Main */
        .main {
            margin-left: 260px;
            padding: 30px;
        }

        /* Setup Card */
        .setup-card {
            border: none;
            border-radius: 20px;
            background: white;
            padding: 40px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.05);
        }

        .feature-badge {
            font-size: 0.75rem;
            padding: 5px 12px;
            border-radius: 50px;
            background: #e7f0ff;
            color: #0d6efd;
            font-weight: 600;
            margin: 2px;
            display: inline-block;
        }

        @media (max-width: 768px) {
            .sidebar {
                position: relative;
                width: 100%;
            }
            .main {
                margin-left: 0;
            }
        }
    </style>

    {% block extra_css %}{% endblock %}
</head>
<body>

<!-- Sidebar -->
<div class="sidebar">
    <div class="brand">🚀 Enterprise</div>

    <div class="menu-title">General</div>
    <a href="/" class="active">
        <i class="bi bi-speedometer2"></i>
        Dashboard
    </a>

    <a href="#">
        <i class="bi bi-box"></i>
        Applications
    </a>

    <div class="menu-title">System</div>
    <a href="/admin/">
        <i class="bi bi-shield-lock"></i>
        Admin
    </a>
</div>

<!-- Main Content -->
<div class="main">
    {% block content %}

    <!-- ===== CONTENT SEMENTARA (CEK FUNGSIONALITAS) ===== -->
    <div class="d-flex justify-content-center align-items-center" style="min-height: 80vh;">
        <div class="setup-card text-center" style="max-width: 500px;">
            <h2 class="fw-bold text-dark mb-2">🚀 Project Terinisialisasi!</h2>
            <p class="text-muted small mb-4">
                Project <strong>{{ project_name|default:"Enterprise Project" }}</strong>
                siap dikembangkan dengan stack enterprise.
            </p>

            <div class="mb-4">
                <span class="feature-badge">Django 4.2+</span>
                <span class="feature-badge">DRF</span>
                <span class="feature-badge">Celery</span>
                <span class="feature-badge">Redis</span>
                <span class="feature-badge">CORS Ready</span>
            </div>

            <div class="text-start bg-light p-3 rounded-3 mb-4">
                <code style="font-size: 0.85rem;">
                    # Jalankan Worker:<br>
                    celery -A config worker -l info
                </code>
            </div>

            <a href="/admin/" class="btn btn-primary w-100 rounded-pill py-2 fw-bold">
                Buka Django Admin
            </a>
        </div>
    </div>

    {% endblock %}
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
{% block extra_js %}{% endblock %}
</body>
</html>
EOF

  # 8. Celery Setup (Standard)
  cat <<'EOF' > "$CONFIG_DIR/celery.py"
import os
from celery import Celery
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.dev")
app = Celery("config")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
EOF

  # Ini memastikan app di-load saat Django dijalankan.
  cat <<'EOF' > "$CONFIG_DIR/__init__.py"
from .celery import app as celery_app

__all__ = ("celery_app",)
EOF

  log "✅ Init Berhasil. Menjalankan migrasi awal..."
  cmd_prepare
  cmd_superuser
  cmd_graph
}

cmd_graph() {
  ensure_venv
  log "Generating Database Schema Graph..."
  if command -v dot &> /dev/null; then
    python manage.py graph_models -a -o schema.png && log "Graph saved to schema.png"
  else
    warn "Graphviz (dot) tidak ditemukan. Graph ditiadakan. (Install: sudo apt install graphviz)"
  fi
}

cmd_prepare() {
  ensure_venv
  python manage.py makemigrations
  python manage.py migrate
  cmd_graph
}

cmd_add_app() {
  APP=$1
  [ -z "$APP" ] && die "Nama app wajib"
  ensure_venv

  APP_PATH="$APPS_DIR/$APP"
  [ -d "$APP_PATH" ] && die "App '$APP' sudah ada."

  log "Membuat aplikasi '$APP'..."
  mkdir -p "$APP_PATH"
  python manage.py startapp "$APP" "$APP_PATH"

  # 1. Fix AppConfig Namespace
  OLD_CONF="name = '$APP'"
  NEW_CONF="name = '$APPS_DIR.$APP'"
  echo "$(cat "$APP_PATH/apps.py" | py_replace "$OLD_CONF" "$NEW_CONF")" > "$APP_PATH/apps.py"

  # 2. Register to INSTALLED_APPS
  export REG_ENTRY="    '$APPS_DIR.$APP',"
  python3 <<EOF
import os
p = "$CONFIG_DIR/settings/base.py"
with open(p, 'r') as f: lines = f.readlines()
with open(p, 'w') as f:
    for l in lines:
        f.write(l)
        if "INSTALLED_APPS = [" in l: f.write(os.getenv('REG_ENTRY') + "\n")
EOF

  # 3. Create App urls.py
  cat <<EOF > "$APP_PATH/urls.py"
from django.urls import path
from . import views

app_name = '$APP'
urlpatterns = [
    # path('resource/', views.ResourceList.as_view(), name='resource-list'),
]
EOF

  # 4. Create App tasks.py (Celery Sample)
  cat <<EOF > "$APP_PATH/tasks.py"
from celery import shared_task
from celery.utils.log import get_task_logger
import time

logger = get_task_logger(__name__)

@shared_task
def example_background_task(name):
    time.sleep(5)
    return f"Halo {name}, task Celery berhasil dijalankan!"
EOF

  # 5. Include App URLs to Root
  export URL_INC="    path('$APP/', include('$APPS_DIR.$APP.urls')),"
  python3 <<EOF
import os
p = "$CONFIG_DIR/urls.py"
with open(p, 'r') as f: lines = f.readlines()
with open(p, 'w') as f:
    for l in lines:
        if "urlpatterns = [" in l:
            f.write(l + os.getenv('URL_INC') + "\n")
        else:
            f.write(l)
EOF

  log "✅ App '$APP' berhasil di-setup dengan tasks.py dan auto-routing."
}

cmd_prepare() {
  ensure_venv
  log "Migrasi Database & Check System..."
  python manage.py makemigrations
  python manage.py migrate
  python manage.py check
}

cmd_superuser() {
  ensure_venv
  U=${1:-admin}
  E=${2:-admin@mail.com}
  P=${3:-admin123}
  log "Membuat Superuser: $U"
  export DJANGO_SUPERUSER_USERNAME=$U
  export DJANGO_SUPERUSER_EMAIL=$E
  export DJANGO_SUPERUSER_PASSWORD=$P
  python manage.py createsuperuser --noinput || warn "Gagal/Sudah ada."
}

cmd_reset_db() {
  warn "PERINGATAN: Ini akan menghapus semua data dan reset migrasi!"
  read -p "Apakah Anda yakin? (y/n): " confirm
  if [ "$confirm" == "y" ]; then
    ensure_venv

    # ✅ HANYA hapus migrasi app custom
    find apps -path "*/migrations/*.py" -not -name "__init__.py" -delete
    find apps -path "*/migrations/*.pyc" -delete

    rm -f db.sqlite3

    # ✅ Pastikan Django core utuh
    pip install --upgrade django >/dev/null

    log "Database dan migrasi app telah dibersihkan."

    cmd_prepare
    cmd_superuser
  fi
}

cmd_lint() {
  ensure_venv
  pip install black flake8 >/dev/null
  log "Running Black Formatter..."
  black .
  log "Running Flake8 Checker..."
  flake8 . --exclude=venv,migrations
}

cmd_shell() {
  ensure_venv
  # Pastikan django_extensions ada di INSTALLED_APPS
  python manage.py shell_plus
}

cmd_devtools() {
  ensure_venv
  echo ""
  echo "🧠 Django Dev Tools:"
  echo "--------------------"
  echo "shell_plus   → python manage.py shell_plus"
  echo "show_urls    → python manage.py show_urls"
  echo "graph_models → python manage.py graph_models -a -o schema.png"
  echo ""
}

# Fungsi untuk menampilkan panduan penggunaan
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

show_help() {
  echo -e "${BOLD}Rapid Project Management Initialization Script${NC}"
  echo "Usage: ./manage.sh [command]"
  echo ""
  echo -e "${BLUE}COMMANDS:${NC}"
  
  # Membuat tabel bantuan manual yang rapi
  printf "  %-12s %s\n" "init" "Inisialisasi environment dan virtualenv."
  printf "  %-12s %s\n" "add-app" "Tambah aplikasi Django baru (Contoh: ./manage.sh add-app blog)."
  printf "  %-12s %s\n" "migrate" "Menyiapkan dan menjalankan migrasi database."
  printf "  %-12s %s\n" "run" "Menjalankan server development Django."
  printf "  %-12s %s\n" "shell" "Masuk ke interactive Python shell."
  printf "  %-12s %s\n" "worker/beat" "Menjalankan Celery worker atau scheduler."
  printf "  %-12s %s\n" "reset-db" "Menghapus dan membuat ulang database (Hati-hati!)."
  echo ""
}

# ---------------- ROUTER ----------------
case "$1" in
  init) 
    shift; 
    if [ -z "$1" ]; then
      echo "Error: 'add-app' requires an app name."
      echo "Example: $0 add-app blog"
    else
      cmd_init "$@" 
    fi
    ;;
  add-app) 
    shift; 
    if [ -z "$1" ]; then
      echo "Error: 'add-app' requires an app name."
      echo "Example: $0 add-app blog"
    else
      cmd_add_app "$@"
    fi
    ;;
  migrate) cmd_prepare ;;
  reset-db) cmd_reset_db ;;
  shell) cmd_shell ;;
  lint) cmd_lint ;;
  graph) cmd_graph ;;
  dev-tools) cmd_devtools ;;
  run) ensure_venv; python manage.py runserver ;;
  worker) ensure_venv; celery -A config worker -l info ;;
  beat) ensure_venv; celery -A config beat -l info ;;
  -h|--help|help) show_help ;;
  *) 
    echo "Error: Unknown command '$1'"
    show_help
    exit 1 
    ;;
esac
