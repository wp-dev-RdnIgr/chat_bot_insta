# Instagram Chatbot — Jera Bot AI

Чат-бот для Instagram Direct на базе n8n + Meta Instagram API.

## Архитектура

```
Instagram DM → Meta Webhook → n8n Workflow → Bot Logic → Instagram API → Ответ пользователю
```

## Настройка

### 1. Meta Developer App
- Создай приложение на [developers.facebook.com](https://developers.facebook.com)
- Добавь продукт "Messenger" / "Instagram"
- Подключи Facebook-страницу и Instagram-аккаунт
- Сгенерируй Access Token

### 2. n8n
- Установи n8n: `npm install -g n8n` или через Docker
- Импортируй workflow: `n8n_workflow_instagram_chatbot.json`
- Настрой переменные окружения из `.env.example`

### 3. Webhook
- Запусти n8n и скопируй URL вебхука
- В Meta Developer App → Webhooks → добавь URL
- Verify Token: значение из `WEBHOOK_VERIFY_TOKEN` в `.env`
- Подпишись на события: `messages`

## Файлы

| Файл | Описание |
|------|----------|
| `n8n_workflow_instagram_chatbot.json` | Основной workflow для n8n |
| `.env.example` | Шаблон переменных окружения |
| `.env` | Локальные переменные (не в git) |

## Команды бота

| Команда | Ответ |
|---------|-------|
| привет / hi | Приветствие и меню |
| услуги | Список услуг |
| цены | Информация о ценах |
| контакты | Контактные данные |
