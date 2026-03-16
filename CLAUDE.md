# CLAUDE.md — Project Context & Task State

## Project: Instagram Booking Bot — Bloom Beauty Studio

Demo-кейс для портфолио агентства: бот-администратор в Instagram для салонов красоты.
Бот ведёт клиента от первого сообщения до подтверждённой записи на услугу.

## Architecture

- **n8n** (https://n8n.rnd.webpromo.tools) — workflow engine, webhook receiver
- **Supabase** (PostgreSQL) — database: услуги, мастера, расписание, записи, клиенты, диалоги
- **Meta Graph API** — Instagram Messaging (приём/отправка DM)
- **Язык бота:** украинский | **Часовой пояс:** Europe/Kyiv | **Валюта:** грн

## Key Credentials

### n8n API
- URL: https://n8n.rnd.webpromo.tools
- API Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI2Zjc3NjZjMS04ZTZkLTQ3OGYtYTY2Ny05MzYxOWJhMzVkYmUiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzcxODY0MDI1fQ.pDWUjuqs6RF51PEKQtTHOUFJPvOF4YLFFsBWaCoL5I8`
- Main workflow ID: `5iXUqYa4eX72YBbP`
- Webhook URL: `https://n8n.rnd.webpromo.tools/webhook/instagram-webhook`

### Supabase
- Project URL: `https://saajgmcaohjqtxufffid.supabase.co`
- Project ref: `saajgmcaohjqtxufffid`
- Service Role Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhYWpnbWNhb2hqcXR4dWZmZmlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzY5NDUxOSwiZXhwIjoyMDg5MjcwNTE5fQ.MhnKsCYqeIrOEryimCgXG4nMbvs2tlhs_oF6-jMMIa0`
- Anon Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhYWpnbWNhb2hqcXR4dWZmZmlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2OTQ1MTksImV4cCI6MjA4OTI3MDUxOX0.C_ECDy8TjHlkUlRoS2crDaQbrYHOMDZki0VC6OjOoB4`
- DB Password: `eXSk#9q?Q2ft&3G`
- n8n PostgreSQL credential ID: `gu0lE0XWHJLWR30R` (created, but direct DB connection from n8n fails — ENETUNREACH IPv6)
- MCP Server: `https://mcp.supabase.com/mcp?project_ref=saajgmcaohjqtxufffid`

### Instagram / Meta
- Current token (IGAA... — Instagram token, НЕ работает для Messaging API!): `IGAAVQ2FGSYClBZAFp4RHNiSEhqUWRuaTZAPbUFBTDBjTUZAmNF9oU1hHZAE92NGVOWnBJdjlCY2lHeEhTcVRDcGhxUjl2TFg5MW5kMVV3cTFlVS1hbl9xVllIOEZAXOHdFUXFjcXQwbjZAMeTNLUmdaU0ZAnOWIxZAnM0ZAG1NTEdmTks2YwZDZD`
- **ПРОБЛЕМА:** Для Instagram Messaging API нужен **Page Access Token** (начинается с `EAA...`), не Instagram User Token (`IGAA...`). Ошибка: "Invalid OAuth access token - Cannot parse access token"
- Send endpoint: `https://graph.instagram.com/v21.0/me/messages`

## Files

| File | Description |
|------|-------------|
| `n8n_workflow_instagram_chatbot.json` | n8n workflow JSON — готов, задеплоен |
| `supabase_migration.sql` | SQL: 7 таблиц + seed data + helper functions |
| `README.md` | Документация с инструкцией настройки |
| `docs/` | Privacy Policy, Terms of Service, Data Deletion (EN) |
| `.mcp.json` | Supabase MCP server config |

## n8n Workflow Structure (ID: 5iXUqYa4eX72YBbP)

Nodes:
1. **Webhook POST** — принимает входящие Instagram DM
2. **Webhook GET** — верификация Meta webhook (hub.challenge)
3. **Verify Response** — отдаёт hub.challenge
4. **Filter: Has Message** — фильтрует только сообщения
5. **Respond OK** — немедленно 200 Instagram
6. **Bot Engine** (Code node) — вся бот-логика, использует `helpers.httpRequest()` для Supabase REST API
7. **Send Reply to Instagram** — HTTP Request → graph.instagram.com

## Bot Conversation Flow (7 steps)

GREETING → SELECT_SERVICE → SELECT_MASTER → SELECT_DATE → SELECT_TIME → CONFIRM → DONE

Special commands (any step): спочатку/заново, мої записи, прайс/ціни

## Database (Supabase) — 7 tables

services, masters, master_services, schedule_slots, clients, bookings, conversations

## COMPLETED ✅

1. ✅ SQL migration file created (`supabase_migration.sql`) — 7 tables, seed data (11 services, 4 masters, schedule 7 days), helper functions
2. ✅ n8n workflow created & deployed — full conversation state machine
3. ✅ Bot Engine rewritten to use `helpers.httpRequest()` (fetch/axios/https blocked in n8n sandbox)
4. ✅ Supabase credentials hardcoded in Bot Engine
5. ✅ README.md with full setup instructions
6. ✅ MCP config added (.mcp.json)
7. ✅ Webhook receives messages from Instagram (verified — execution 405536)
8. ✅ Temp migration workflow cleaned up

## TODO — Remaining Tasks 🔲

1. 🔲 **USER ACTION: Run SQL migration** — user must open Supabase SQL Editor (https://supabase.com/dashboard/project/saajgmcaohjqtxufffid/sql/new) and paste+run `supabase_migration.sql`
2. 🔲 **Verify Supabase tables** — after migration, check that all 7 tables exist and seed data is correct via REST API
3. 🔲 **Fix Instagram token** — need Page Access Token (EAA...) instead of current IGAA... token. User needs to generate it in Meta Developer Console → Messenger/Instagram → Generate Token for Facebook Page linked to Instagram
4. 🔲 **End-to-end test** — send message in Instagram DM, verify full flow works
5. 🔲 **Commit & push final state** after everything works

## Known Issues

- **n8n Code node sandbox**: fetch(), axios, https, pg modules all blocked. Only `helpers.httpRequest()` works for HTTP calls.
- **n8n PostgreSQL connection to Supabase**: fails with ENETUNREACH (IPv6). Cannot run DDL from n8n.
- **Instagram token**: IGAA... token doesn't work for Messaging API. Need EAA... Page Access Token.
- **Egress from sandbox**: direct connections to graph.instagram.com and graph.facebook.com blocked from this dev environment (but n8n can reach them).

## Git

- Branch: `claude/instagram-chatbot-n8n-FfpWJ`
- All changes committed and pushed
