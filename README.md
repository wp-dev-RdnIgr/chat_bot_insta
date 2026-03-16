# Instagram Booking Bot — Bloom Beauty Studio

Бот-адміністратор для Instagram Direct: повна воронка від першого повідомлення до підтвердженого запису на послугу — без участі живого адміністратора.

**Ніша:** салони краси та індивідуальні майстри (нігті, вії, брови, волосся).

## Архітектура

```
Instagram DM → Meta Webhook → n8n (Webhook POST)
                                    ↓
                              Filter + Respond 200
                                    ↓
                              Bot Engine (Code node)
                                ├── Supabase REST API (клієнти, діалоги, послуги, розклад)
                                └── Conversation state machine (7 кроків воронки)
                                    ↓
                              Send Reply → Instagram API (Quick Replies)
```

## Що вміє бот

| Крок | Опис |
|------|------|
| `GREETING` | Привітання, вибір категорії (Нігті / Вії / Брови / Волосся) |
| `SELECT_SERVICE` | Список послуг з цінами та тривалістю |
| `SELECT_MASTER` | Вибір майстра (або авто-вибір якщо один) |
| `SELECT_DATE` | Вибір дати (найближчі 5 вільних днів) |
| `SELECT_TIME` | Вибір часу (з урахуванням тривалості послуги) |
| `CONFIRM` | Підтвердження запису з підсумком |
| `DONE` | Запис створено, слоти заброньовано |

**Спеціальні команди** (працюють на будь-якому кроці):
- `спочатку` / `заново` / `відміна` — скинути діалог
- `мої записи` — показати активні записи
- `прайс` / `ціни` — повний прайс-лист

## Файли проєкту

| Файл | Опис |
|------|------|
| `n8n_workflow_instagram_chatbot.json` | n8n workflow — готовий до імпорту |
| `supabase_migration.sql` | SQL міграція + seed-дані для Supabase |
| `docs/` | Privacy Policy, Terms of Service, Data Deletion |

---

## Покрокова інструкція з налаштування

### 1. Створити Supabase-проєкт

1. Зареєструйтесь на [supabase.com](https://supabase.com)
2. Створіть новий проєкт
3. Перейдіть у **SQL Editor**
4. Скопіюйте вміст файлу `supabase_migration.sql` та виконайте
5. Збережіть:
   - **Project URL** — `https://xxx.supabase.co`
   - **Service Role Key** — з Settings → API → `service_role` (secret)

> Міграція створить 7 таблиць, заповнить послуги, майстрів, зв'язки та розклад на 7 днів.

### 2. Створити Meta App та отримати Access Token

1. Перейдіть на [developers.facebook.com](https://developers.facebook.com)
2. Створіть нове застосування (тип: **Business**)
3. Додайте продукт **Instagram** (або **Messenger**)
4. Підключіть Facebook-сторінку, яка пов'язана з Instagram Business акаунтом

**Для отримання Page Access Token:**

5. Перейдіть у **Messenger → Settings** або **Instagram → Settings**
6. Натисніть **Generate Token** для вашої сторінки
7. Скопіюйте токен — він починається з `EAA...`

> **Важливо:** Для Instagram Messaging API потрібен саме **Page Access Token** (починається з `EAA...`), а НЕ Instagram User Token (`IGAA...`). Токен `IGAA` працює тільки для Instagram Graph API (пости, stories), але не для обміну повідомленнями.

**Необхідні дозволи (permissions):**
- `instagram_manage_messages` — читання та відправка повідомлень
- `pages_messaging` — обмін повідомленнями через сторінку
- `instagram_basic` — базовий доступ до Instagram

### 3. Налаштувати n8n Environment Variables

В n8n перейдіть у **Settings → Environment Variables** та додайте:

| Змінна | Значення | Опис |
|--------|----------|------|
| `SUPABASE_URL` | `https://xxx.supabase.co` | URL вашого Supabase-проєкту |
| `SUPABASE_SERVICE_KEY` | `eyJ...` | Service Role Key з Supabase |
| `INSTAGRAM_ACCESS_TOKEN` | `EAA...` | Page Access Token |

> Якщо ви не використовуєте environment variables, можна замінити `$env.SUPABASE_URL` тощо прямо в Code-ноді.

### 4. Імпортувати workflow в n8n

1. Відкрийте n8n: `https://n8n.rnd.webpromo.tools`
2. Перейдіть у **Workflows → Import from File**
3. Завантажте `n8n_workflow_instagram_chatbot.json`
4. Переконайтесь, що всі ноди на місці:
   - `Webhook POST (Messages)` — приймає повідомлення
   - `Webhook GET (Verify)` — верифікація Meta
   - `Filter: Has Message` — фільтрує тільки повідомлення з текстом
   - `Respond OK` — швидко відповідає 200 Instagram
   - `Bot Engine` — основна логіка воронки
   - `Send Reply to Instagram` — відправка відповіді
5. **Activate** workflow

### 5. Налаштувати Webhook у Meta Developer Console

1. Скопіюйте URL вебхука з ноди `Webhook POST`:
   ```
   https://n8n.rnd.webpromo.tools/webhook/instagram-webhook
   ```
2. Перейдіть у Meta App → **Instagram → Settings → Webhooks**
3. Натисніть **Subscribe to events**
4. Вставте:
   - **Callback URL:** `https://n8n.rnd.webpromo.tools/webhook/instagram-webhook`
   - **Verify Token:** `bloom_beauty_verify_2024` (або ваш токен з n8n env)
5. Підпишіться на поле: **`messages`**

### 6. Тестування

1. Відкрийте Instagram та напишіть в Direct вашому бізнес-акаунту
2. Відправте будь-яке повідомлення (наприклад, "привіт")
3. Бот повинен відповісти привітанням з Quick Replies для вибору категорії
4. Пройдіть всю воронку: категорія → послуга → майстер → дата → час → підтвердження

**Перевірити в Supabase:**
- `clients` — з'явився ваш запис
- `conversations` — відстежується стан діалогу
- `bookings` — після підтвердження з'являється запис
- `schedule_slots` — слоти позначені як `is_booked = true`

**Перевірити в n8n:**
- Executions → перевірте статус кожного виконання
- Якщо помилка — подивіться деталі ноди `Bot Engine` або `Send Reply`

---

## Діагностика проблем

| Проблема | Рішення |
|----------|---------|
| Бот не відповідає | Перевірте що workflow активний, webhook підписаний на `messages` |
| `Invalid OAuth access token` | Потрібен **Page Access Token** (EAA...), не Instagram token (IGAA...) |
| `Cannot parse access token` | Токен прострочений або невірний — згенеруйте новий |
| Помилки Supabase | Перевірте `SUPABASE_URL` та `SUPABASE_SERVICE_KEY` в n8n env |
| Quick Replies не відображаються | Instagram показує QR тільки в мобільному додатку |
| Webhook не верифікується | Перевірте що GET endpoint активний та повертає `hub.challenge` |

---

## Технічний стек

- **n8n** — автоматизація workflow
- **Supabase (PostgreSQL)** — база даних
- **Meta Graph API** — Instagram Messaging
- **Мова бота:** українська
- **Часовий пояс:** Europe/Kyiv
- **Валюта:** UAH (грн)
