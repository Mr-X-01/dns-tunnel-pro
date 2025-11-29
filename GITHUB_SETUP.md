# 📦 Загрузка проекта на GitHub

## Пошаговая инструкция

### 1️⃣ Инициализация Git (если еще не сделано)

```bash
cd /путь/к/проекту/Fuck-RNK
git init
```

### 2️⃣ Добавьте файлы

```bash
git add .
```

### 3️⃣ Создайте первый коммит

```bash
git commit -m "Initial commit: DNS Tunnel Pro - Full implementation"
```

### 4️⃣ Создайте репозиторий на GitHub

1. Откройте https://github.com/new
2. Название: `dns-tunnel-pro`
3. Description: `🚀 Professional DNS tunneling solution with DoH support and web management panel`
4. Public/Private - на ваш выбор
5. **НЕ** добавляйте README, .gitignore, license (они уже есть)
6. Нажмите "Create repository"

### 5️⃣ Свяжите локальный репозиторий с GitHub

```bash
git remote add origin https://github.com/Mr-X-01/dns-tunnel-pro.git
git branch -M main
git push -u origin main
```

### 6️⃣ Готово! 🎉

Ваш репозиторий доступен по адресу:
```
https://github.com/Mr-X-01/dns-tunnel-pro
```

---

## 📝 Дальнейшие коммиты

После внесения изменений:

```bash
git add .
git commit -m "Описание изменений"
git push
```

---

## 🏷️ Создание релиза

1. Перейдите в раздел "Releases" на GitHub
2. Нажмите "Create a new release"
3. Tag version: `v1.0.0`
4. Release title: `DNS Tunnel Pro v1.0.0`
5. Description:
```markdown
## 🚀 First Release

### Features
- ✅ DNS tunneling через DoH (Яндекс DNS)
- ✅ Веб-панель управления
- ✅ AES-256 шифрование
- ✅ Мультиклиент поддержка
- ✅ SOCKS5 прокси
- ✅ Автоматическая установка

### Installation

**Server:**
curl -sSL https://raw.githubusercontent.com/Mr-X-01/dns-tunnel-pro/main/install.sh | sudo bash

**Client:**
curl -sSL https://raw.githubusercontent.com/Mr-X-01/dns-tunnel-pro/main/client-install.sh | bash
```

---

## 🎨 Настройка README

На главной странице репозитория будет отображаться `README.md` с красивым оформлением, бейджами и инструкциями.

---

## 🔒 GitHub Actions (опционально)

Можно добавить автоматические тесты и сборку Docker образов.

Создайте `.github/workflows/test.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: 3.9
      - name: Install dependencies
        run: |
          pip install -r server/requirements.txt
      - name: Run tests
        run: |
          python -m pytest tests/
```

---

## 📢 Topics для репозитория

Добавьте топики на GitHub:
- `dns-tunnel`
- `proxy`
- `doh`
- `privacy`
- `security`
- `vpn`
- `python`
- `flask`
- `linux`

---

**Готово! Репозиторий настроен! 🚀**
