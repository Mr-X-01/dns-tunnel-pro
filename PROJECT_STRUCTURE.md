# 📁 Структура проекта DNS Tunnel Pro

```
Fuck-RNK/
│
├── 📄 README.md                      # Основная документация
├── 📄 QUICKSTART.md                  # Быстрый старт
├── 📄 ARCHITECTURE.md                # Техническая архитектура
├── 📄 CONTRIBUTING.md                # Гайд для контрибьюторов
├── 📄 GITHUB_SETUP.md                # Инструкция по загрузке на GitHub
├── 📄 PROJECT_STRUCTURE.md           # Этот файл
├── 📄 LICENSE                        # MIT License
├── 📄 .gitignore                     # Игнорируемые файлы
├── 📄 .env.example                   # Пример переменных окружения
├── 📄 docker-compose.yml             # Docker Compose конфигурация
│
├── 🚀 install.sh                     # Установка СЕРВЕРА (одна команда)
├── 🚀 client-install.sh              # Установка КЛИЕНТА (одна команда)
│
├── 📂 server/                        # Серверная часть
│   ├── 📄 main.py                    # Точка входа сервера
│   ├── 📄 requirements.txt           # Python зависимости
│   ├── 📄 Dockerfile                 # Docker образ сервера
│   │
│   ├── 📂 config/                    # Конфигурация
│   │   ├── config_loader.py         # Загрузчик конфигов
│   │   └── settings.yml             # Настройки сервера
│   │
│   ├── 📂 dns_server/                # DNS туннель сервер
│   │   └── server.py                # Основной DNS сервер
│   │
│   ├── 📂 web_panel/                 # Веб-панель управления
│   │   ├── app.py                   # Flask приложение
│   │   └── 📂 templates/            # HTML шаблоны
│   │       ├── base.html            # Базовый шаблон
│   │       ├── login.html           # Страница входа
│   │       ├── dashboard.html       # Главная панель
│   │       ├── clients.html         # Список клиентов
│   │       ├── add_client.html      # Добавление клиента
│   │       ├── client_detail.html   # Детали клиента
│   │       └── settings.html        # Настройки
│   │
│   ├── 📂 database/                  # База данных (создается автоматически)
│   │   └── tunnel.db                # SQLite БД
│   │
│   ├── 📂 logs/                      # Логи (создаются автоматически)
│   │   └── server.log               # Логи сервера
│   │
│   └── 📂 ssl/                       # SSL сертификаты (генерируются автоматически)
│       ├── cert.pem                 # Сертификат
│       └── key.pem                  # Приватный ключ
│
├── 📂 client/                        # Клиентская часть
│   └── 📄 dns_client.py             # DNS туннель клиент
│
└── 📂 client_configs/                # Конфиги клиентов (генерируются автоматически)
    └── *.json                        # JSON конфиги для каждого клиента
```

## 📊 Статистика проекта

- **Всего файлов**: 25+
- **Строк кода**: ~3000+
- **Языки**: Python, HTML, CSS, Shell, YAML
- **Технологии**: Flask, SQLAlchemy, dnslib, cryptography

## 🎯 Ключевые файлы

### Для пользователя

| Файл | Описание |
|------|----------|
| `README.md` | Полная документация проекта |
| `QUICKSTART.md` | Быстрый старт за 5 минут |
| `install.sh` | Установка сервера одной командой |
| `client-install.sh` | Установка клиента одной командой |

### Для разработчика

| Файл | Описание |
|------|----------|
| `ARCHITECTURE.md` | Техническая архитектура системы |
| `CONTRIBUTING.md` | Как внести вклад в проект |
| `GITHUB_SETUP.md` | Загрузка на GitHub |
| `server/dns_server/server.py` | Логика DNS туннеля |
| `server/web_panel/app.py` | Веб-панель управления |
| `client/dns_client.py` | Клиентская часть |

## 🔑 Основные компоненты

### 1. DNS Server
- **Файл**: `server/dns_server/server.py`
- **Функции**: 
  - Прием DNS запросов
  - Извлечение туннелированных данных
  - Проксирование через DoH
  - AES-256-GCM шифрование

### 2. Web Panel
- **Файл**: `server/web_panel/app.py`
- **Функции**:
  - Аутентификация администратора
  - Управление клиентами (CRUD)
  - Генерация конфигов
  - Мониторинг статистики
  - API endpoints

### 3. Client
- **Файл**: `client/dns_client.py`
- **Функции**:
  - SOCKS5 прокси сервер
  - Шифрование запросов
  - DoH запросы к Яндекс DNS
  - Автоматическое переподключение

## 🚀 Быстрый деплой

### Вариант 1: Автоматическая установка

```bash
# Сервер
curl -sSL https://raw.githubusercontent.com/Mr-X-01/dns-tunnel-pro/main/install.sh | sudo bash

# Клиент
curl -sSL https://raw.githubusercontent.com/Mr-X-01/dns-tunnel-pro/main/client-install.sh | bash
```

### Вариант 2: Docker Compose

```bash
git clone https://github.com/Mr-X-01/dns-tunnel-pro.git
cd dns-tunnel-pro
docker-compose up -d
```

### Вариант 3: Ручная установка

```bash
git clone https://github.com/Mr-X-01/dns-tunnel-pro.git
cd dns-tunnel-pro
./install.sh
```

## 📝 Конфигурационные файлы

### server/config/settings.yml
```yaml
dns:
  domain: tunnel.example.com
  port: 53

web_panel:
  port: 8443
  admin_user: admin
  admin_password: admin123

security:
  encryption: aes-256-gcm
```

### .env (переменные окружения)
```bash
DNS_DOMAIN=tunnel.example.com
ADMIN_PASSWORD=secure_password
```

### client config.json (генерируется в веб-панели)
```json
{
  "client_id": "unique-client-id",
  "encryption_key": "base64-encoded-key",
  "dns_domain": "tunnel.example.com",
  "doh_resolver": "https://common.dot.dns.yandex.net/dns-query",
  "socks5_port": 1080
}
```

## 🔒 Безопасность

- ✅ AES-256-GCM шифрование
- ✅ HTTPS для веб-панели
- ✅ DoH (DNS-over-HTTPS)
- ✅ Уникальные ключи для каждого клиента
- ✅ Хеширование паролей (Werkzeug)
- ✅ Rate limiting

## 📈 Метрики и мониторинг

- Активные клиенты
- Объем трафика
- Последняя активность
- История подключений
- API endpoint: `/api/stats`

## 🌐 Порты

| Порт | Сервис | Протокол |
|------|--------|----------|
| 53 | DNS Server | UDP |
| 8443 | Web Panel | TCP (HTTPS) |
| 1080 | SOCKS5 Proxy | TCP (локально) |

---

**Проект готов к использованию! 🚀**
