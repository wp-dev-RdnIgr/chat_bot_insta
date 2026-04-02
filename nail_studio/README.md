# Nail Studio Kyiv OB — Instagram Booking Bot + Google Calendar

Instagram-бот для запису клієнтів у nail-студію з автоматичним створенням подій у Google Calendar.

**Instagram:** @nail.studio.kyiv_ob
**Google Calendar:** cumasergej08@gmail.com

## Архітектура

```
Instagram DM → Meta Webhook → n8n Workflow → AI Agent (GPT-4.1-mini)
                                                  ↓
                                          Supabase (PostgreSQL)
                                                  ↓
                                          Google Calendar API
```

## Послуги (seed data)

| Категорія | Послуга | Ціна | Тривалість |
|-----------|---------|------|------------|
| Манікюр | Класичний | 400 грн | 60 хв |
| Манікюр | Апаратний | 450 грн | 60 хв |
| Манікюр | + гель-лак | 600 грн | 90 хв |
| Манікюр | Зняття гель-лаку | 150 грн | 30 хв |
| Манікюр | Зміцнення нігтів | 200 грн | 30 хв |
| Нарощування | Гелем | 1000 грн | 120 хв |
| Нарощування | Корекція | 800 грн | 90 хв |
| Нарощування | Зняття | 300 грн | 60 хв |
| Педикюр | Класичний | 500 грн | 60 хв |
| Педикюр | Апаратний | 550 грн | 75 хв |
| Педикюр | + гель-лак | 700 грн | 90 хв |
| Дизайн | 1 ніготь | 50 грн | 15 хв |
| Дизайн | French | 200 грн | 30 хв |

## Майстри

| Імʼя | Спеціалізація |
|------|---------------|
| Іванна | Манікюр, Нарощування, Дизайн |
| Вікторія | Манікюр, Педикюр, Дизайн |
| Аліна | Манікюр, Нарощування, Педикюр |

## Налаштування — покроково

### Крок 1: Supabase

1. Створити проект на [supabase.com](https://supabase.com)
2. Виконати `supabase_migration.sql` в SQL Editor
3. Зберегти:
   - Project URL: `https://xxxxx.supabase.co`
   - Service Role Key: `eyJ...`

### Крок 2: Google Calendar API

1. Перейти в [Google Cloud Console](https://console.cloud.google.com)
2. Створити проект або обрати існуючий
3. Увімкнути **Google Calendar API**
4. Створити **OAuth 2.0 credentials**:
   - Application type: Web application
   - Authorized redirect URI: `https://n8n.rnd.webpromo.tools/rest/oauth2-credential/callback`
5. В n8n: Credentials → New → Google Calendar OAuth2
   - Client ID та Client Secret з Google Cloud Console
   - Натиснути "Sign in with Google" → авторизувати `cumasergej08@gmail.com`
6. Зберегти credential ID

### Крок 3: Instagram / Meta

1. Створити Meta App на [developers.facebook.com](https://developers.facebook.com)
2. Підключити Instagram акаунт @nail.studio.kyiv_ob
3. Налаштувати Webhooks:
   - Callback URL: `https://n8n.rnd.webpromo.tools/webhook/nail-studio-webhook`
   - Verify Token: (будь-який рядок)
   - Підписка: `messages`
4. Отримати Page Access Token з довгим терміном дії
5. Зберегти токен

### Крок 4: n8n Workflow

1. Імпортувати `n8n_workflow_nail_studio.json`
2. Замінити плейсхолдери в "Prepare Context" ноді:
   - `__SUPABASE_URL__` → URL вашого Supabase проекту
   - `__SUPABASE_SERVICE_ROLE_KEY__` → Service Role Key
   - `__INSTAGRAM_ACCESS_TOKEN__` → токен з Кроку 3
3. Замінити плейсхолдери в tool-нодах (Find Available Times, Create Booking, Cancel Booking):
   - `__SUPABASE_URL__` та `__SUPABASE_SERVICE_ROLE_KEY__`
4. Налаштувати OpenAI credential в "OpenAI Chat Model" ноді
5. Налаштувати Google Calendar credential в "Google Calendar — Create Event" ноді
6. Активувати workflow

### Крок 5: Тестування

1. Надіслати DM в @nail.studio.kyiv_ob
2. Перевірити що бот відповідає
3. Пройти повний флоу: вибір послуги → майстер → час → бронювання
4. Перевірити що подія зʼявилась в Google Calendar

## Файли

| Файл | Опис |
|------|------|
| `supabase_migration.sql` | SQL: таблиці, seed data, RPC-функції |
| `n8n_workflow_nail_studio.json` | n8n workflow JSON (16 нод) |
| `README.md` | Ця документація |

## Відмінності від Bloom Beauty Studio

| Параметр | Bloom Beauty | Nail Studio |
|----------|-------------|-------------|
| Послуги | Нігті, вії, брови, волосся | Тільки нігті |
| Календар | Тільки Supabase | Supabase + Google Calendar |
| Скасування | Тільки по телефону | Автоматичне через бота |
| Функція create_booking | Повертає UUID | Повертає повні деталі для Calendar |
