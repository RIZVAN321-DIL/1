const tg = window.Telegram.WebApp;
tg.expand();
tg.ready();
tg.setHeaderColor('#0d0d0d');
tg.setBackgroundColor('#0d0d0d');

const user = tg.initDataUnsafe.user;
const ADMIN_IDS = [5724746367];
const WEEKEND_DAYS = [6,7];
const isAdmin = user && ADMIN_IDS.includes(user.id);

let state = { screen: 'menu', svc: null, mst: null, date: null, time: null, services: [], masters: [], bookings: [], pastBookings: [], myReviews: [], profile: null, stats: null, todayBookings: [], allServices: [], allMasters: [], isSubmitting: false, todayFilterMaster: null, selectedPhotoFile: null, selectedPhotoPath: null, broadcastPhotoPath: null };

async function api(url, options = {}) {
    try {
        const res = await fetch(url, options);
        return res.json();
    } catch (e) {
        console.error(e);
        return { error: true };
    }
}

async function uploadPhoto(file) {
    const formData = new FormData();
    formData.append('photo', file);
    formData.append('admin_telegram_id', user.id);
    const res = await fetch('/api/admin/upload-photo', { method: 'POST', body: formData });
    return res.json();
}

async function ld() {
    try {
        state.services = await api('/api/services');
        state.masters = await api('/api/masters');
        if (user) {
            const p = await api(`/api/profile?telegram_id=${user.id}`);
            if (p.exists) {
                state.profile = p;
                state.bookings = p.bookings || [];
                state.pastBookings = p.past_bookings_for_review || [];
                state.myReviews = p.my_reviews || [];
            }
        }
        if (isAdmin) {
            state.allServices = await api(`/api/admin/services?admin_telegram_id=${user.id}`);
            state.allMasters = await api(`/api/admin/masters?admin_telegram_id=${user.id}`);
            state.stats = await api(`/api/admin/stats?admin_telegram_id=${user.id}`);
            state.todayBookings = await api(`/api/admin/today-bookings?admin_telegram_id=${user.id}`);
        }
    } catch (e) { console.error(e); }
    rn(state.screen);
}

function rn(screen) {
    state.screen = screen;
    const app = document.getElementById('app');
    app.innerHTML = '';
    if (screen === 'menu') renderMenu(app);
    else if (screen === 'booking_service') renderBookingService(app);
    else if (screen === 'booking_master') renderBookingMaster(app);
    else if (screen === 'booking_date') renderBookingDate(app);
    else if (screen === 'booking_time') renderBookingTime(app);
    else if (screen === 'booking_confirm') renderBookingConfirm(app);
    else if (screen === 'my_bookings') renderMyBookings(app);
    else if (screen === 'reviews') renderReviews(app);
    else if (screen === 'my_reviews_history') renderMyReviewsHistory(app);
    else if (screen === 'bonuses') renderBonuses(app);
    else if (screen === 'admin_stats') renderAdminStats(app);
    else if (screen === 'admin_today') renderAdminToday(app);
    else if (screen === 'admin_masters') renderAdminMasters(app);
    else if (screen === 'admin_services') renderAdminServices(app);
    else if (screen === 'admin_broadcast') renderAdminBroadcast(app);
    else if (screen === 'admin_audit') renderAdminAudit(app);
}

function renderMenu(app) {
    app.innerHTML = '<h2>Меню</h2><div class="menu-grid"></div>';
    const grid = app.querySelector('.menu-grid');
    const items = [
        { icon: '✂️', label: 'Записаться', action: () => rn('booking_service') },
        { icon: '📋', label: 'Мои записи', action: () => rn('my_bookings') },
        { icon: '⭐', label: 'Отзывы', action: () => rn('reviews') },
        { icon: '📝', label: 'Мои отзывы', action: () => rn('my_reviews_history') },
        { icon: '🎁', label: 'Бонусы', action: () => rn('bonuses') },
    ];
    if (isAdmin) {
        items.push({ icon: '📊', label: 'Статистика', action: () => rn('admin_stats') });
        items.push({ icon: '📅', label: 'Записи сегодня', action: () => rn('admin_today') });
        items.push({ icon: '👥', label: 'Мастера', action: () => rn('admin_masters') });
        items.push({ icon: '💇', label: 'Услуги', action: () => rn('admin_services') });
        items.push({ icon: '📢', label: 'Рассылка', action: () => rn('admin_broadcast') });
        items.push({ icon: '📜', label: 'Аудит', action: () => rn('admin_audit') });
    }
    items.forEach(item => {
        const div = document.createElement('div');
        div.className = 'menu-item';
        div.innerHTML = `<div class="icon">${item.icon}</div><div class="label">${item.label}</div>`;
        div.onclick = item.action;
        grid.appendChild(div);
    });
}

function renderBookingService(app) {
    app.innerHTML = '<h2>Выберите услугу</h2><div id="svc"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('svc');
    state.services.forEach(x => {
        const e = document.createElement('div');
        e.className = 'option';
        e.innerHTML = `<div class="info"><b>${x.name}</b><span>${x.duration} мин</span></div><strong style="color:#c9a96e">${x.price}₽</strong>`;
        e.onclick = () => { state.svc = x; rn('booking_master'); };
        c.appendChild(e);
    });
}

function renderBookingMaster(app) {
    app.innerHTML = '<h2>Выберите мастера</h2><div id="mst"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_service\')">← Назад</button></div>';
    const c = document.getElementById('mst');
    state.masters.forEach(x => {
        const e = document.createElement('div');
        e.className = 'option';
        e.innerHTML = `<img src="${x.photo || ''}" onerror="this.style.display=\'none\'"><div class="info"><b>${x.name}</b><span>⭐${x.rating} | Опыт ${x.experience} лет</span></div>`;
        e.onclick = () => { state.mst = x; rn('booking_date'); };
        c.appendChild(e);
    });
}

function renderBookingDate(app) {
    app.innerHTML = '<h2>Выберите дату</h2><div class="grid" id="dt"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_master\')">← Назад</button></div>';
    const g = document.getElementById('dt');
    const t = new Date();
    for (let i = 0; i < 14; i++) {
        const d = new Date(t);
        d.setDate(t.getDate() + i);
        const ds = d.toISOString().split('T')[0];
        const dow = d.getDay();
        const b = document.createElement('div');
        b.textContent = d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short', weekday: 'short' });
        if (WEEKEND_DAYS.includes(dow)) {
            b.className = 'weekend';
            b.textContent += ' (вых)';
        } else {
            b.onclick = () => { state.date = ds; rn('booking_time'); };
        }
        g.appendChild(b);
    }
}

async function renderBookingTime(app) {
    app.innerHTML = '<h2>Выберите время</h2><div class="grid" id="tm"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_date\')">← Назад</button></div>';
    const g = document.getElementById('tm');
    const bk = await api(`/api/booked-slots?date=${state.date}&master_id=${state.mst.id}`);
    const bt = bk.map(x => x.time);
    const now = new Date();
    const today = now.toISOString().split('T')[0];
    const curH = now.getHours();
    const curM = now.getMinutes();
    for (let h = 10; h < 21; h++) {
        for (let m = 0; m < 60; m += 30) {
            const tm = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
            const b = document.createElement('div');
            if (bt.includes(tm)) { b.className = 'booked'; b.textContent = tm; }
            else if (state.date === today && (h < curH || (h === curH && m <= curM))) { b.className = 'booked'; b.textContent = tm; }
            else { b.textContent = tm; b.onclick = () => { state.time = tm; rn('booking_confirm'); }; }
            g.appendChild(b);
        }
    }
}

function renderBookingConfirm(app) {
    app.innerHTML = '<h2>Подтверждение</h2><div class="summary"><div class="summary-item"><span>Услуга</span><strong id="sm_svc"></strong></div><div class="summary-item"><span>Мастер</span><strong id="sm_mst"></strong></div><div class="summary-item"><span>Дата</span><strong id="sm_dt"></strong></div><div class="summary-item"><span>Время</span><strong id="sm_tm"></strong></div><div class="summary-item total"><span>Цена</span><strong id="sm_pr"></strong></div></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_time\')">← Назад</button><button class="btn-confirm" id="cfbtn" onclick="cf()">Подтвердить</button></div>';
    document.getElementById('sm_svc').textContent = state.svc.name;
    document.getElementById('sm_mst').textContent = state.mst.name;
    document.getElementById('sm_dt').textContent = state.date;
    document.getElementById('sm_tm').textContent = state.time;
    document.getElementById('sm_pr').textContent = state.svc.price + '₽';
}

async function cf() {
    if (state.isSubmitting) return;
    if (!user) { tg.showAlert('Ошибка: данные пользователя недоступны'); return; }
    state.isSubmitting = true;
    const btn = document.getElementById('cfbtn');
    btn.textContent = 'Создаём...';
    btn.disabled = true;
    const payload = { telegram_id: user.id, chat_id: user.id, username: user.username || null, first_name: user.first_name || null, last_name: user.last_name || null, service_id: state.svc.id, master_id: state.mst.id, date: state.date, time: state.time };
    try {
        const res = await api('/api/book', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        if (res.ok) {
            tg.showAlert(`Запись подтверждена!\n\n${res.service}\nМастер: ${res.master}\n${res.date} в ${res.time}\nЦена: ${res.price}₽`);
            const p = await api(`/api/profile?telegram_id=${user.id}`);
            if (p.exists) { state.profile = p; state.bookings = p.bookings || []; state.pastBookings = p.past_bookings_for_review || []; state.myReviews = p.my_reviews || []; }
            if (isAdmin) {
                state.stats = await api(`/api/admin/stats?admin_telegram_id=${user.id}`);
                state.todayBookings = await api(`/api/admin/today-bookings?admin_telegram_id=${user.id}`);
            }
            rn('my_bookings');
        } else { tg.showAlert(res.detail || 'Ошибка записи'); }
    } catch (e) { tg.showAlert('Ошибка соединения'); }
    state.isSubmitting = false;
    btn.textContent = 'Подтвердить';
    btn.disabled = false;
}

function renderMyBookings(app) {
    app.innerHTML = '<h2>Мои записи</h2><div id="bklist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('bklist');
    if (state.bookings.length === 0) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    state.bookings.forEach(b => {
        const card = document.createElement('div');
        card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${b.date} в ${b.time}</span><span class="status-badge ${b.status === 'confirmed' ? 'status-active' : 'status-inactive'}">${b.status === 'confirmed' ? '✅ Активна' : '❌ Отменена'}</span></div><div class="row"><span class="label">Мастер:</span><span class="value">${b.master}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service}</span></div><div class="row"><span class="label">Цена:</span><span class="value">${b.price}₽</span></div>`;
        if (b.status === 'confirmed') {
            const btn = document.createElement('button');
            btn.className = 'btn-cancel';
            btn.textContent = '❌ Отменить';
            btn.style.marginTop = '8px';
            btn.style.width = '100%';
            btn.onclick = async () => {
                const res = await api('/api/cancel', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ telegram_id: user.id, booking_id: b.id }) });
                if (res.ok) { tg.showAlert('Запись отменена'); const p = await api(`/api/profile?telegram_id=${user.id}`); state.bookings = p.bookings || []; rn('my_bookings'); }
                else { tg.showAlert(res.detail || 'Ошибка'); }
            };
            card.appendChild(btn);
        }
        c.appendChild(card);
    });
}

function renderReviews(app) {
    app.innerHTML = '<h2>Оставить отзыв</h2><div id="rvlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('rvlist');
    if (state.pastBookings.length === 0) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет прошедших записей</p>'; return; }
    state.pastBookings.forEach(b => {
        const card = document.createElement('div');
        card.className = 'card';
        card.id = `rv_${b.id}`;
        card.innerHTML = `<div class="row"><span class="label">${b.date} в ${b.time}</span></div><div class="row"><span class="label">Мастер:</span><span class="value">${b.master}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service}</span></div><div class="stars" id="stars_${b.id}">${[1,2,3,4,5].map(n => `<span class="star" data-n="${n}">★</span>`).join('')}</div>`;
        c.appendChild(card);
        const stars = document.querySelectorAll(`#stars_${b.id} .star`);
        stars.forEach(s => {
            s.onmouseenter = () => { const n = parseInt(s.dataset.n); stars.forEach((ss, i) => ss.classList.toggle('active', i < n)); };
            s.onclick = async () => {
                const rating = parseInt(s.dataset.n);
                const res = await api('/api/reviews', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ telegram_id: user.id, booking_id: b.id, rating }) });
                if (res.ok) { tg.showAlert(res.bonus_added ? `Спасибо! +${res.bonus_amount}₽ бонус!` : 'Спасибо за отзыв!'); const p = await api(`/api/profile?telegram_id=${user.id}`); if (p.exists) { state.profile = p; state.pastBookings = p.past_bookings_for_review || []; state.myReviews = p.my_reviews || []; } rn('reviews'); }
                else { tg.showAlert(res.detail || 'Ошибка'); }
            };
        });
    });
}

function renderMyReviewsHistory(app) {
    app.innerHTML = '<h2>Мои отзывы</h2><div id="myrv"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('myrv');
    if (!state.myReviews || state.myReviews.length === 0) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет отзывов</p>'; return; }
    state.myReviews.forEach(r => {
        const card = document.createElement('div');
        card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">Мастер: ${r.master_name}</span><span class="value">${'★'.repeat(r.rating)}${'☆'.repeat(5-r.rating)}</span></div>${r.comment ? `<div class="row"><span class="label">Комментарий:</span><span class="value">${r.comment}</span></div>` : ''}`;
        c.appendChild(card);
    });
}

function renderBonuses(app) {
    app.innerHTML = '<h2>Бонусы</h2><div id="bn"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('bn');
    if (!state.profile) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет данных</p>'; return; }
    c.innerHTML = `<div class="card"><div class="row"><span class="label">Всего визитов:</span><span class="value">${state.profile.total_visits}</span></div><div class="row"><span class="label">Бонусный баланс:</span><span class="value green">${state.profile.bonus_balance}₽</span></div><div class="row"><span class="label">До следующего бонуса:</span><span class="value">${state.profile.visits_to_next_bonus} визитов</span></div></div>`;
}

function renderAdminStats(app) {
    app.innerHTML = '<h2>Статистика</h2><div id="st"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const s = state.stats || {};
    document.getElementById('st').innerHTML = `<div class="card"><div class="row"><span class="label">Записей сегодня:</span><span class="value">${s.today_bookings || 0}</span></div><div class="row"><span class="label">Всего клиентов:</span><span class="value">${s.total_clients || 0}</span></div><div class="row"><span class="label">Выручка сегодня:</span><span class="value green">${s.today_revenue || 0}₽</span></div></div>`;
}

async function renderAdminToday(app) {
    app.innerHTML = '<h2>Записи на сегодня</h2><div class="form-group"><label>Фильтр по мастеру</label><select id="mfilter" onchange="loadTodayFiltered()"><option value="">Все мастера</option>' + state.allMasters.map(m => `<option value="${m.id}" ${state.todayFilterMaster == m.id ? 'selected' : ''}>${m.name}</option>`).join('') + '</select></div><div id="tdlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    await loadTodayFiltered();
}

async function loadTodayFiltered() {
    const mid = document.getElementById('mfilter')?.value || '';
    state.todayFilterMaster = mid || null;
    const url = mid ? `/api/admin/today-bookings?admin_telegram_id=${user.id}&master_id=${mid}` : `/api/admin/today-bookings?admin_telegram_id=${user.id}`;
    state.todayBookings = await api(url);
    const c = document.getElementById('tdlist');
    c.innerHTML = '';
    if (state.todayBookings.length === 0) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    state.todayBookings.forEach(b => {
        const card = document.createElement('div');
        card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${b.time}</span><span class="value">${b.client_name} (@${b.client_username})</span></div><div class="row"><span class="label">Мастер:</span><span class="value">${b.master}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service} (${b.price}₽)</span></div>`;
        const btn = document.createElement('button');
        btn.className = 'btn-cancel';
        btn.textContent = '❌ Отменить';
        btn.style.marginTop = '8px';
        btn.style.width = '100%';
        btn.onclick = async () => {
            const res = await api('/api/admin/cancel', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user.id, booking_id: b.id }) });
            if (res.ok) { tg.showAlert('Запись отменена'); await loadTodayFiltered(); }
            else { tg.showAlert(res.detail || 'Ошибка'); }
        };
        card.appendChild(btn);
        c.appendChild(card);
    });
}

function renderAdminMasters(app) {
    app.innerHTML = '<h2>Мастера</h2><div id="mlist"></div><button class="btn-admin" style="width:100%;margin-top:8px" onclick="showMasterForm()">➕ Добавить мастера</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    renderMastersList();
}

function renderMastersList() {
    const c = document.getElementById('mlist');
    c.innerHTML = '';
    state.allMasters.forEach(m => {
        const card = document.createElement('div');
        card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${m.name}</span><span class="status-badge ${m.is_active ? 'status-active' : 'status-inactive'}">${m.is_active ? 'Активен' : 'Неактивен'}</span></div><div class="row"><span class="label">Рейтинг: ${m.rating} | Опыт: ${m.experience} лет | Лимит: ${m.max_bookings} зап/день</span></div>${m.photo ? `<img src="${m.photo}" style="width:60px;height:60px;border-radius:12px;object-fit:cover;margin-top:8px">` : ''}<div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap"><button class="btn-admin" onclick="editMaster(${m.id},'${m.name}','${m.photo || ''}',${m.experience},${m.telegram_id || 0},${m.max_bookings || 15})">✏️</button><button class="btn-admin" onclick="toggleMaster(${m.id})">${m.is_active ? '⏸️ Отключить' : '▶️ Включить'}</button><button class="btn-dayoff" onclick="showDayOffForm(${m.id},'${m.name}')">🚫 Выходной</button></div>`;
        c.appendChild(card);
    });
}

function showMasterForm(editData = null) {
    const app = document.getElementById('app');
    state.selectedPhotoFile = null;
    state.selectedPhotoPath = editData?.photo || null;
    app.innerHTML = `<h2>${editData ? 'Изменить мастера' : 'Добавить мастера'}</h2><div class="form-group"><label>Имя</label><input id="mname" value="${editData?.name || ''}"></div><div class="form-group"><label>Фото</label>${state.selectedPhotoPath ? `<img src="${state.selectedPhotoPath}" class="preview-img" id="mphoto_preview"><br>` : ''}<input type="file" id="mphoto_input" accept="image/*" style="display:none" onchange="onPhotoSelected(this)"><button class="btn-photo" onclick="document.getElementById(\'mphoto_input\').click()">📷 Выбрать фото</button><span class="file-selected" id="mphoto_name">${state.selectedPhotoPath ? '✅ Фото загружено' : ''}</span></div><div class="form-group"><label>Опыт (лет)</label><input id="mexp" type="number" value="${editData?.exp || 0}"></div><div class="form-group"><label>Telegram ID мастера</label><input id="mtg" type="number" value="${editData?.tg || ''}"></div><div class="form-group"><label>Лимит записей в день</label><input id="mmax" type="number" value="${editData?.max || 15}"></div><button class="btn-confirm" style="width:100%" onclick="${editData ? `saveMasterEdit(${editData.id})` : 'saveMasterNew()'}">Сохранить</button><div class="btn-group"><button class="btn-back" onclick="rn(\'admin_masters\')">← Назад</button></div>`;
}

function onPhotoSelected(input) {
    if (input.files && input.files[0]) {
        state.selectedPhotoFile = input.files[0];
        document.getElementById('mphoto_name').textContent = '✅ ' + input.files[0].name;
        const preview = document.getElementById('mphoto_preview');
        if (preview) {
            preview.src = URL.createObjectURL(input.files[0]);
        }
    }
}

async function saveMasterNew() {
    const name = document.getElementById('mname').value;
    const exp = parseInt(document.getElementById('mexp').value) || 0;
    const tgid = parseInt(document.getElementById('mtg').value) || null;
    const max = parseInt(document.getElementById('mmax').value) || 15;
    let photoPath = null;
    if (state.selectedPhotoFile) {
        const upRes = await uploadPhoto(state.selectedPhotoFile);
        if (upRes.ok) photoPath = upRes.path;
    }
    await api('/api/admin/masters', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user.id, name, photo_url: photoPath, experience_years: exp, telegram_id: tgid, max_bookings_per_day: max }) });
    state.allMasters = await api(`/api/admin/masters?admin_telegram_id=${user.id}`);
    rn('admin_masters');
}

function editMaster(id, name, photo, exp, tg, max) { showMasterForm({ id, name, photo, exp, tg, max }); }

async function saveMasterEdit(id) {
    const name = document.getElementById('mname').value;
    const exp = parseInt(document.getElementById('mexp').value) || 0;
    const tgid = parseInt(document.getElementById('mtg').value) || null;
    const max = parseInt(document.getElementById('mmax').value) || 15;
    let photoPath = state.selectedPhotoPath;
    if (state.selectedPhotoFile) {
        const upRes = await uploadPhoto(state.selectedPhotoFile);
        if (upRes.ok) photoPath = upRes.path;
    }
    await api(`/api/admin/masters/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user.id, name, photo_url: photoPath, experience_years: exp, telegram_id: tgid, max_bookings_per_day: max }) });
    state.allMasters = await api(`/api/admin/masters?admin_telegram_id=${user.id}`);
    rn('admin_masters');
}

async function toggleMaster(id) {
    await api(`/api/admin/masters/${id}/toggle`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user.id, master_id: id }) });
    state.allMasters = await api(`/api/admin/masters?admin_telegram_id=${user.id}`);
    rn('admin_masters');
}

function showDayOffForm(masterId, masterName) {
    const app = document.getElementById('app');
    app.innerHTML = `<h2>Выходной мастера</h2><p style="color:#888;margin-bottom:12px">Мастер: <b>${masterName}</b></p><div class="form-group"><label>Дата</label><input id="ddate" type="date"></div><div class="form-group"><label>Причина</label><textarea id="dreason" placeholder="Например: семейные обстоятельства"></textarea></div><button class="btn-confirm" style="width:100%" onclick="saveDayOff(${masterId})">Установить выходной</button><div class="btn-group"><button class="btn-back" onclick="rn(\'admin_masters\')">← Назад</button></div>`;
}

async function saveDayOff(masterId) {
    const date = document.getElementById('ddate').value;
    const reason = document.getElementById('dreason').value;
    if (!date) { tg.showAlert('Выберите дату'); return; }
    const res = await api('/api/admin/master-day-off', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user.id, master_id: masterId, date, reason }) });
    if (res.ok) { tg.showAlert(`Выходной установлен. Отменено записей: ${res.cancelled_bookings}`); rn('admin_masters'); }
    else { tg.showAlert(res.detail || 'Ошибка'); }
}

function renderAdminServices(app) {
    app.innerHTML = '<h2>Услуги</h2><div id="slist"></div><button class="btn-admin" style="width:100%;margin-top:8px" onclick="showServiceForm()">➕ Добавить услугу</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    renderServicesList();
}

function renderServicesList() {
    const c = document.getElementById('slist');
    c.innerHTML = '';
    state.allServices.forEach(s => {
        const card = document.createElement('div');
        card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${s.name}</span><span class="status-badge ${s.is_active ? 'status-active' : 'status-inactive'}">${s.is_active ? 'Активна' : 'Неактивна'}</span></div><div class="row"><span class="label">Цена: ${s.price}₽ | Длит: ${s.duration} мин | Кат: ${s.category || '—'}</span></div><div style="display:flex;gap:8px;margin-top:8px"><button class="btn-admin" onclick="editService(${s.id},'${s.name}',${s.price},${s.duration},'${s.category || ''}')">✏️</button><button class="btn-admin" onclick="toggleService(${s.id})">${s.is_active ? '⏸️ Отключить' : '▶️ Включить'}</button></div>`;
        c.appendChild(card);
    });
}

function showServiceForm(editData = null) {
    const app = document.getElementById('app');
    app.innerHTML = `<h2>${editData ? 'Изменить услугу' : 'Добавить услугу'}</h2><div class="form-group"><label>Название</label><input id="sname" value="${editData?.name || ''}"></div><div class="form-group"><label>Цена</label><input id="sprice" type="number" value="${editData?.price || ''}"></div><div class="form-group"><label>Длительность (мин)</label><input id="sdur" type="number" value="${editData?.dur || ''}"></div><div class="form-group"><label>Категория</label><input id="scat" value="${editData?.cat || ''}"></div><button class="btn-confirm" style="width:100%" onclick="${editData ? `saveServiceEdit(${editData.id})` : 'saveServiceNew()'}">Сохранить</button><div class="btn-group"><button class="btn-back" onclick="rn(\'admin_services\')">← Назад</button></div>`;
}

async function saveServiceNew() {
    const name = document.getElementById('sname').value;
    const price = parseInt(document.getElementById('sprice').value) || 0;
    const dur = parseInt(document.getElementById('sdur').value) || 0;
    const cat = document.getElementById('scat').value;
    await api('/api/admin/services', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user.id, name, price, duration_minutes: dur, category: cat }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user.id}`);
    rn('admin_services');
}

function editService(id, name, price, dur, cat) { showServiceForm({ id, name, price, dur, cat }); }

async function saveServiceEdit(id) {
    const name = document.getElementById('sname').value;
    const price = parseInt(document.getElementById('sprice').value) || 0;
    const dur = parseInt(document.getElementById('sdur').value) || 0;
    const cat = document.getElementById('scat').value;
    await api(`/api/admin/services/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user.id, name, price, duration_minutes: dur, category: cat }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user.id}`);
    rn('admin_services');
}

async function toggleService(id) {
    await api(`/api/admin/services/${id}/toggle`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user.id, service_id: id }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user.id}`);
    rn('admin_services');
}

function renderAdminBroadcast(app) {
    state.broadcastPhotoPath = null;
    app.innerHTML = '<h2>Рассылка</h2><div class="form-group"><label>Текст сообщения</label><textarea id="btext" placeholder="Введите текст рассылки..."></textarea></div><div class="form-group"><label>Фото (необязательно)</label><input type="file" id="bphoto_input" accept="image/*" style="display:none" onchange="onBroadcastPhotoSelected(this)"><button class="btn-photo" onclick="document.getElementById(\'bphoto_input\').click()">📷 Прикрепить фото</button><span class="file-selected" id="bphoto_name"></span></div><button class="btn-send" style="width:100%" onclick="sendBroadcast()">📢 Отправить всем</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
}

function onBroadcastPhotoSelected(input) {
    if (input.files && input.files[0]) {
        state.broadcastPhotoFile = input.files[0];
        document.getElementById('bphoto_name').textContent = '✅ ' + input.files[0].name;
    }
}

async function sendBroadcast() {
    const text = document.getElementById('btext').value;
    if (!text) { tg.showAlert('Введите текст'); return; }
    let photoPath = null;
    if (state.broadcastPhotoFile) {
        const upRes = await uploadPhoto(state.broadcastPhotoFile);
        if (upRes.ok) photoPath = upRes.path;
    }
    const res = await api('/api/admin/broadcast', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user.id, text, photo_path: photoPath }) });
    if (res.ok) { tg.showAlert(`Отправлено: ${res.sent}, ошибок: ${res.failed}`); rn('menu'); }
    else { tg.showAlert('Ошибка'); }
}

async function renderAdminAudit(app) {
    app.innerHTML = '<h2>Аудит (история изменений)</h2><div id="alist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const logs = await api(`/api/admin/audit-log?admin_telegram_id=${user.id}`);
    const c = document.getElementById('alist');
    if (!logs || logs.length === 0) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    logs.forEach(l => {
        const card = document.createElement('div');
        card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${l.created_at ? new Date(l.created_at).toLocaleString('ru-RU') : '—'}</span></div><div class="row"><span class="label">Админ ID: ${l.admin_id}</span><span class="value">${l.action}</span></div>${l.details ? `<div class="row"><span class="label">Детали:</span><span class="value">${l.details}</span></div>` : ''}`;
        c.appendChild(card);
    });
}

ld();
