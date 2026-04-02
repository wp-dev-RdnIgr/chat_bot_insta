# GAS miniCRM — Nail Studio Kyiv OB

Веб-інтерфейс CRM для nail-студії на Google Apps Script.
Підключається до Supabase (та ж база, що й Instagram бот).

## Функціонал

| Вкладка | Можливості |
|---------|-----------|
| **Розклад** | Тижневий календар записів усіх майстрів. Фільтр по майстрам. Клік по слоту = новий запис |
| **Послуги** | Перегляд, додавання, редагування, деактивація послуг. Ціни, тривалість, категорії |
| **Спеціалісти** | Управління майстрами: робочий час, вихідні, Google Calendar, послуги, колір |
| **Клієнти** | Список клієнтів з Instagram та ручних записів |

## Розгортання

### 1. Виконати SQL міграцію

Відкрийте Supabase → SQL Editor і виконайте `migration.sql`.
Це додає поля `comment`, `source` до `bookings` та `color` до `masters`.

### 2. Створити Google Apps Script проєкт

1. Перейдіть на https://script.google.com
2. Створіть новий проєкт
3. Створіть файли:
   - `Code.gs` — скопіюйте вміст `Code.gs`
   - `index.html` — скопіюйте вміст `index.html`
   - `styles.html` — скопіюйте вміст `styles.html`
   - `app.html` — скопіюйте вміст `app.html`

### 3. Деплой

1. Deploy → New deployment
2. Type: **Web app**
3. Execute as: **Me**
4. Who has access: **Anyone** (або тільки ваш домен)
5. Deploy → скопіюйте URL

### 4. Google Calendar доступ

Якщо використовуєте CalendarApp для створення подій:
- Переконайтеся що акаунт GAS має доступ до календаря `cumasergej08@gmail.com`
- Або змініть `GOOGLE_CALENDAR_ID` в `Code.gs`
