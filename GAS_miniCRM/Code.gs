// =====================================================
// GAS miniCRM — Nail Studio Kyiv OB
// Google Apps Script backend
// =====================================================

const SUPABASE_URL = 'https://saajgmcaohjqtxufffid.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhYWpnbWNhb2hqcXR4dWZmZmlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzY5NDUxOSwiZXhwIjoyMDg5MjcwNTE5fQ.MhnKsCYqeIrOEryimCgXG4nMbvs2tlhs_oF6-jMMIa0';
const GOOGLE_CALENDAR_ID = 'cumasergej08@gmail.com';

// =====================================================
// Web App Entry Point
// =====================================================

function doGet(e) {
  return HtmlService.createTemplateFromFile('index')
    .evaluate()
    .setTitle('Nail Studio CRM')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

// =====================================================
// Supabase Helper
// =====================================================

function sbFetch(path, options = {}) {
  const url = `${SUPABASE_URL}/rest/v1/${path}`;
  const params = {
    method: options.method || 'GET',
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': options.prefer || 'return=representation'
    },
    muteHttpExceptions: true
  };
  if (options.body) {
    params.payload = JSON.stringify(options.body);
  }
  const resp = UrlFetchApp.fetch(url, params);
  const code = resp.getResponseCode();
  const text = resp.getContentText();
  if (code >= 400) {
    throw new Error(`Supabase ${code}: ${text}`);
  }
  return text ? JSON.parse(text) : null;
}

// =====================================================
// BOOKINGS / SCHEDULE
// =====================================================

function getBookings(startDate, endDate) {
  const bookings = sbFetch(
    `bookings?select=id,date,start_time,end_time,status,comment,source,created_at,google_event_id,` +
    `client:clients(id,name,instagram_username,phone),` +
    `master:masters(id,name,color),` +
    `service:services(id,name,price,duration_minutes,category)` +
    `&date=gte.${startDate}&date=lte.${endDate}&status=neq.cancelled&order=date.asc,start_time.asc`
  );
  return bookings;
}

function createManualBooking(data) {
  // data: { master_id, service_id, date, start_time, end_time, client_name, client_phone, comment }

  // 1. Find or create client
  let clientId;
  if (data.client_phone) {
    const existing = sbFetch(`clients?phone=eq.${encodeURIComponent(data.client_phone)}&limit=1`);
    if (existing.length > 0) {
      clientId = existing[0].id;
      // Update name if provided
      if (data.client_name && !existing[0].name) {
        sbFetch(`clients?id=eq.${clientId}`, {
          method: 'PATCH',
          body: { name: data.client_name }
        });
      }
    }
  }

  if (!clientId) {
    const newClient = sbFetch('clients', {
      method: 'POST',
      body: {
        instagram_id: `manual_${Date.now()}`,
        name: data.client_name || null,
        phone: data.client_phone || null
      }
    });
    clientId = newClient[0].id;
  }

  // 2. Create Google Calendar event
  let googleEventId = null;
  try {
    const service = sbFetch(`services?id=eq.${data.service_id}&limit=1`)[0];
    const master = sbFetch(`masters?id=eq.${data.master_id}&limit=1`)[0];
    const calendarId = master.google_calendar_id || GOOGLE_CALENDAR_ID;

    const startDt = new Date(`${data.date}T${data.start_time}:00`);
    const endDt = new Date(`${data.date}T${data.end_time}:00`);

    const event = CalendarApp.getCalendarById(calendarId).createEvent(
      `${service.name} — ${data.client_name || 'Клієнт'}`,
      startDt,
      endDt,
      {
        description: [
          `Послуга: ${service.name}`,
          `Майстер: ${master.name}`,
          `Клієнт: ${data.client_name || '—'}`,
          `Тел: ${data.client_phone || '—'}`,
          data.comment ? `Коментар: ${data.comment}` : ''
        ].filter(Boolean).join('\n')
      }
    );
    googleEventId = event.getId();
  } catch (e) {
    Logger.log('Calendar error: ' + e.message);
  }

  // 3. Create booking in DB
  const booking = sbFetch('bookings', {
    method: 'POST',
    body: {
      client_id: clientId,
      master_id: data.master_id,
      service_id: data.service_id,
      date: data.date,
      start_time: data.start_time,
      end_time: data.end_time,
      google_event_id: googleEventId,
      status: 'confirmed',
      source: 'manual_crm',
      comment: data.comment || null
    }
  });

  return { success: true, booking_id: booking[0].id };
}

function cancelBooking(bookingId) {
  // Get booking details first
  const booking = sbFetch(`bookings?id=eq.${bookingId}&limit=1`)[0];
  if (!booking) throw new Error('Запис не знайдено');

  // Cancel Google Calendar event
  if (booking.google_event_id) {
    try {
      const master = sbFetch(`masters?id=eq.${booking.master_id}&limit=1`)[0];
      const calendarId = master.google_calendar_id || GOOGLE_CALENDAR_ID;
      CalendarApp.getCalendarById(calendarId).getEventById(booking.google_event_id).deleteEvent();
    } catch (e) {
      Logger.log('Calendar delete error: ' + e.message);
    }
  }

  // Update status
  sbFetch(`bookings?id=eq.${bookingId}`, {
    method: 'PATCH',
    body: { status: 'cancelled' }
  });

  return { success: true };
}

function updateBookingStatus(bookingId, status) {
  sbFetch(`bookings?id=eq.${bookingId}`, {
    method: 'PATCH',
    body: { status }
  });
  return { success: true };
}

// =====================================================
// SERVICES
// =====================================================

function getServices() {
  return sbFetch('services?order=category.asc,price.asc');
}

function updateService(id, data) {
  sbFetch(`services?id=eq.${id}`, {
    method: 'PATCH',
    body: data
  });
  return { success: true };
}

function createService(data) {
  const result = sbFetch('services', {
    method: 'POST',
    body: data
  });
  return result[0];
}

function deleteService(id) {
  sbFetch(`services?id=eq.${id}`, {
    method: 'PATCH',
    body: { is_active: false }
  });
  return { success: true };
}

// =====================================================
// MASTERS / SPECIALISTS
// =====================================================

function getMasters() {
  return sbFetch('masters?order=name.asc');
}

function getMasterServices(masterId) {
  const links = sbFetch(`master_services?master_id=eq.${masterId}&select=service_id`);
  return links.map(l => l.service_id);
}

function updateMaster(id, data) {
  // Separate service links from master data
  const serviceIds = data.service_ids;
  delete data.service_ids;

  sbFetch(`masters?id=eq.${id}`, {
    method: 'PATCH',
    body: data
  });

  // Update service links if provided
  if (serviceIds !== undefined) {
    // Delete old links
    sbFetch(`master_services?master_id=eq.${id}`, { method: 'DELETE', prefer: 'return=minimal' });
    // Insert new links
    if (serviceIds.length > 0) {
      const links = serviceIds.map(sid => ({ master_id: id, service_id: sid }));
      sbFetch('master_services', { method: 'POST', body: links });
    }
  }

  return { success: true };
}

function createMaster(data) {
  const serviceIds = data.service_ids || [];
  delete data.service_ids;

  const result = sbFetch('masters', {
    method: 'POST',
    body: { ...data, is_active: true }
  });
  const masterId = result[0].id;

  // Add service links
  if (serviceIds.length > 0) {
    const links = serviceIds.map(sid => ({ master_id: masterId, service_id: sid }));
    sbFetch('master_services', { method: 'POST', body: links });
  }

  return result[0];
}

function deleteMaster(id) {
  sbFetch(`masters?id=eq.${id}`, {
    method: 'PATCH',
    body: { is_active: false }
  });
  return { success: true };
}

// =====================================================
// CLIENTS
// =====================================================

function getClients() {
  return sbFetch('clients?order=created_at.desc&limit=100');
}

function updateClient(id, data) {
  sbFetch(`clients?id=eq.${id}`, {
    method: 'PATCH',
    body: data
  });
  return { success: true };
}
