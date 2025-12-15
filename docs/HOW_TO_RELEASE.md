# Как создать GitHub Release

## 1. Проверь что коммитишь

```bash
cd "C:\Users\patki\Desktop\Raspberry Pi5"
git status
```

Должны быть только:
- `scripts/` (8 файлов)
- `configs/` (1 файл)
- `docs/`
- `README.md`, `.gitignore`, `compose.yaml`, `env.example`, `RELEASE_NOTES.md`

Остальное (старые скрипты) исключено через `.gitignore`.

## 2. Коммит и пуш

```powershell
cd "C:\Users\patki\Desktop\Raspberry Pi5"
git add -A
git status  # проверь что нет секретов/старых файлов
git commit -m "v1.0.0: Beginner-friendly release with simplified structure"
git push origin main
```

## 3. Создай Release на GitHub

1. Открой https://github.com/Patkins93/rpi5-v2raya-transparent
2. Нажми **Releases** → **Draft a new release**
3. Заполни:
   - **Tag version**: `v1.0.0`
   - **Target**: `main`
   - **Release title**: `v1.0.0 — Первый публичный релиз`
   - **Description**: скопируй содержимое `RELEASE_NOTES.md`
4. Нажми **Publish release**

## 4. Проверь работу

Скачай архив из релиза и проверь на чистой Raspberry Pi:

```bash
wget https://github.com/Patkins93/rpi5-v2raya-transparent/archive/refs/tags/v1.0.0.tar.gz
tar -xzf v1.0.0.tar.gz
cd rpi5-v2raya-transparent-1.0.0
sudo chmod +x ./scripts/*.sh
sudo ./scripts/install.sh
```

Готово! 🎉

