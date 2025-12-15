# Публикация на GitHub (коротко, без магии)

## 0) Проверь, что в репо нет секретов

Перед публикацией:

```bash
git status
git grep -n "PRIVATE KEY" || true
```

Файлы с паролями/ключами держи вне репозитория (например `.env` уже в `.gitignore`).

## 1) Создай пустой репозиторий на GitHub

На GitHub: **New repository** → выбери имя → **Create repository**.

## 2) Привяжи remote и сделай push

В папке проекта:

```bash
git remote -v
git remote add origin <SSH_OR_HTTPS_REPO_URL>
git branch -M main
git push -u origin main
```

Если `origin` уже был — используй `git remote set-url origin <...>` вместо `add`.

## 3) Что говорить пользователям

Попроси их читать и делать по шагам:
- `README.md` (корень)
- `GITHUB_RELEASE/README.md` (главная инструкция для новичка)


