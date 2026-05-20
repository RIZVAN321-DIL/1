const tg=window.Telegram.WebApp;tg.expand();tg.ready();tg.setHeaderColor('#0d0d0d');tg.setBackgroundColor('#0d0d0d');
let svc,mst,date,time,services,masters,isSubmitting=false;
let currentTab='book';

// Определяем админа
const userId = tg.initDataUnsafe?.user?.id;
const adminIds = [5724746367];
const isAdmin = adminIds.includes(userId);

// Инициализация
async function init(){
    if(isAdmin) document.getElementById('adminNav').style.display='flex';
    await loadServices();
    await loadMasters();
    switchTab('book');
}

// Переключение вкладок
function switchTab(tab){
    currentTab=tab;
    document.querySelectorAll('.tab-content').forEach(el=>el.classList.remove('active'));
    document.getElementById('tab-'+tab).classList.add('active');
    if(isAdmin){
        document.querySelectorAll('.tab-btn').forEach(el=>el.classList.remove('active'));
        document.querySelector(`.tab-btn[data-tab="${tab}"]`).classList.add('active');
    }
    if(tab==='book') ld();
    if(tab==='profile') document.getElementById('profileContent').innerHTML='';
    if(tab==='admin') document.getElementById('adminContent').innerHTML='';
}

if(isAdmin){
    document.querySelectorAll('.tab-btn').forEach(btn=>{
        btn.addEventListener('click',()=>switchTab(btn.dataset.tab));
    });
}

// === ЗАПИСЬ ===
async function loadServices(){
    const sr=await fetch('/api/services');services=await sr.json();
    const s=document.getElementById('svc');
    s.innerHTML='';
    services.forEach(x=>{const e=document.createElement('div');e.className='option';e.innerHTML=`<div class="info"><b>${x.name}</b><span>${x.duration} мин</span></div><strong style="color:#c9a96e">${x.price}₽</strong>`;e.onclick=()=>{document.querySelectorAll('#svc .option').forEach(el=>el.classList.remove('selected'));e.classList.add('selected');svc=x;};s.appendChild(e)});
}

async function loadMasters(){
    const mr=await fetch('/api/masters');masters=await mr.json();
    const m=document.getElementById('mst');
    m.innerHTML='';
    masters.forEach(x=>{const e=document.createElement('div');e.className='option';e.innerHTML=`<img src="${x.photo}" onerror="this.style.display='none'"><div class="info"><b>${x.name}</b><span>⭐${x.rating} | Опыт ${x.experience} лет</span></div>`;e.onclick=()=>{document.querySelectorAll('#mst .option').forEach(el=>el.classList.remove('selected'));e.classList.add('selected');mst=x;};m.appendChild(e)});
}

function gd(){const g=document.getElementById('dt');g.innerHTML='';const t=new Date();for(let i=0;i<7;i++){const d=new Date(t);d.setDate(t.getDate()+i);const ds=d.toISOString().split('T')[0];const b=document.createElement('div');b.textContent=d.toLocaleDateString('ru-RU',{day:'numeric',month:'short',weekday:'short'});b.onclick=()=>{document.querySelectorAll('#dt div').forEach(e=>e.classList.remove('selected'));b.classList.add('selected');date=ds;};g.appendChild(b)}}

async function gt(){const g=document.getElementById('tm');g.innerHTML='';try{const r=await fetch(`/api/booked-slots?date=${date}&master_id=${mst.id}`);if(!r.ok)throw new Error('Error');const bk=(await r.json()).map(x=>x.time);for(let h=10;h<21;h++)for(let m=0;m<60;m+=30){const t=`${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`;const b=document.createElement('div');if(bk.includes(t)){b.className='booked';b.textContent=t}else{b.textContent=t;b.onclick=()=>{document.querySelectorAll('#tm div').forEach(e=>e.classList.remove('selected'));b.classList.add('selected');time=t}};g.appendChild(b)}}catch(e){tg.showAlert('Ошибка загрузки времени')}}

function sh(n){document.querySelectorAll('.step').forEach(e=>e.classList.remove('active'));document.getElementById('s'+n).classList.add('active');if(n===3)gd();if(n===4)gt();if(n===5){document.getElementById('sm_svc').textContent=svc.name;document.getElementById('sm_mst').textContent=mst.name;document.getElementById('sm_dt').textContent=date;document.getElementById('sm_tm').textContent=time;document.getElementById('sm_pr').textContent=svc.price+'₽'}}

function nx(n){if(n===2&&!svc){tg.showAlert('Выберите услугу');return}if(n===3&&!mst){tg.showAlert('Выберите мастера');return}if(n===4&&!date){tg.showAlert('Выберите дату');return}if(n===5&&!time){tg.showAlert('Выберите время');return}sh(n)}

function pv(n){sh(n)}

async function cf(){
    if(isSubmitting)return;
    const user=tg.initDataUnsafe.user;
    if(!user){tg.showAlert('Ошибка: данные пользователя недоступны');return}
    isSubmitting=true;
    const btn=document.querySelector('.btn-confirm');
    btn.textContent='Создаём...';btn.disabled=true;
    const payload={telegram_id:user.id,chat_id:user.id,username:user.username||null,first_name:user.first_name||null,last_name:user.last_name||null,service_id:svc.id,master_id:mst.id,date:date,time:time};
    try{
        const res=await fetch('/api/book',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
        const result=await res.json();
        if(result.ok){tg.showAlert(`Запись подтверждена!\n\n${result.service}\nМастер: ${result.master}\n${result.date} в ${result.time}\nЦена: ${result.price}₽`);tg.close()}else{tg.showAlert(`${result.detail||'Ошибка записи'}`)}
    }catch(e){tg.showAlert('Ошибка соединения')}
    isSubmitting=false;btn.textContent='Подтвердить';btn.disabled=false;
}

// === ПРОФИЛЬ ===
async function showMyBookings(){
    const div=document.getElementById('profileContent');
    div.innerHTML='Загрузка...';
    try{
        const r=await fetch('/api/my-bookings?telegram_id='+userId);
        const bookings=await r.json();
        if(!bookings.length){div.innerHTML='<p>У вас пока нет записей.</p>';return}
        let html='<h3>📋 Мои записи</h3>';
        bookings.forEach(b=>{
            html+=`<div class="booking-item"><span>${b.date} в ${b.time}</span>`;
            if(b.status==='confirmed') html+=`<button class="cancel-btn" onclick="cancelBooking(${b.id})">❌ Отменить</button>`;
            html+=`</div>`;
        });
        div.innerHTML=html;
    }catch(e){div.innerHTML='<p>Ошибка загрузки</p>'}
}

async function cancelBooking(id){
    try{
        const r=await fetch('/api/cancel-booking',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({booking_id:id,telegram_id:userId})});
        const result=await r.json();
        if(result.ok){tg.showAlert('Запись отменена');showMyBookings()}else{tg.showAlert(result.detail||'Ошибка')}
    }catch(e){tg.showAlert('Ошибка соединения')}
}

async function showLeaveReview(){
    const div=document.getElementById('profileContent');
    div.innerHTML='Загрузка...';
    try{
        const r=await fetch('/api/my-confirmed-bookings?telegram_id='+userId);
        const bookings=await r.json();
        if(!bookings.length){div.innerHTML='<p>Нет завершённых записей для отзыва.</p>';return}
        let html='<h3>⭐ Выберите запись для отзыва</h3>';
        bookings.forEach(b=>{
            html+=`<div class="option" onclick="showStars(${b.id},'${b.date}','${b.time}')"><b>📅 ${b.date} в ${b.time}</b></div>`;
        });
        div.innerHTML=html;
    }catch(e){div.innerHTML='<p>Ошибка загрузки</p>'}
}

function showStars(bookingId,date,time){
    const div=document.getElementById('profileContent');
    let starsHtml='<h3>⭐ Оцените визит</h3><p>'+date+' в '+time+'</p><div class="stars-container">';
    for(let i=1;i<=5;i++){
        starsHtml+=`<span class="star" data-rating="${i}" onclick="submitReview(${bookingId},${i})" style="font-size:40px;cursor:pointer;">☆</span>`;
    }
    starsHtml+='</div><div id="reviewMsg"></div>';
    div.innerHTML=starsHtml;
    document.querySelectorAll('.star').forEach(s=>{
        s.addEventListener('mouseenter',()=>{const r=parseInt(s.dataset.rating);document.querySelectorAll('.star').forEach((ss,idx)=>{ss.textContent=idx<r?'★':'☆'});});
        s.addEventListener('mouseleave',()=>{document.querySelectorAll('.star').forEach(ss=>{ss.textContent='☆'});});
    });
}

async function submitReview(bookingId,rating){
    try{
        const r=await fetch('/api/submit-review',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({booking_id:bookingId,rating:rating,telegram_id:userId})});
        const result=await r.json();
        if(result.ok){document.getElementById('reviewMsg').innerHTML='<p style="color:#4CAF50;">✅ Спасибо за оценку! ' + '⭐'.repeat(rating) + '</p>'}else{document.getElementById('reviewMsg').innerHTML='<p style="color:red;">Ошибка</p>'}
    }catch(e){tg.showAlert('Ошибка соединения')}
}

async function showBonuses(){
    const div=document.getElementById('profileContent');
    try{
        const r=await fetch('/api/my-bonuses?telegram_id='+userId);
        const data=await r.json();
        div.innerHTML=`<h3>🎁 Бонусы</h3><p>Визитов: ${data.visits}</p><p>Баланс: ${data.bonus}₽</p><p>До бонуса: ${data.next_bonus} визитов</p>`;
    }catch(e){div.innerHTML='<p>Ошибка</p>'}
}

async function shareRef(){
    tg.showAlert('Ссылка на бота: t.me/'+tg.initDataUnsafe.user.username);
}

// === АДМИН ===
async function showAdminBookings(){
    const div=document.getElementById('adminContent');
    div.innerHTML='Загрузка...';
    try{
        const r=await fetch('/api/admin/today-bookings');
        const bookings=await r.json();
        if(!bookings.length){div.innerHTML='<p>На сегодня записей нет.</p>';return}
        let html='<h3>📅 Записи на сегодня</h3>';
        bookings.forEach(b=>{
            html+=`<div class="booking-item"><span>🕐 ${b.time} — #${b.id}</span><button class="cancel-btn" onclick="adminCancel(${b.id})">❌ Отменить</button></div>`;
        });
        div.innerHTML=html;
    }catch(e){div.innerHTML='<p>Ошибка загрузки</p>'}
}

async function adminCancel(id){
    try{
        const r=await fetch('/api/admin/cancel-booking',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({booking_id:id})});
        const result=await r.json();
        if(result.ok){tg.showAlert('Запись отменена');showAdminBookings()}else{tg.showAlert('Ошибка')}
    }catch(e){tg.showAlert('Ошибка соединения')}
}

async function showAdminStats(){
    const div=document.getElementById('adminContent');
    try{
        const r=await fetch('/api/admin/stats');
        const data=await r.json();
        div.innerHTML=`<h3>📊 Статистика</h3><p>Записей сегодня: ${data.today}</p><p>Всего клиентов: ${data.clients}</p>`;
    }catch(e){div.innerHTML='<p>Ошибка</p>'}
}

async function showAdminMasters(){
    const div=document.getElementById('adminContent');
    try{
        const r=await fetch('/api/masters');
        const masters=await r.json();
        let html='<h3>👥 Мастера</h3>';
        masters.forEach(m=>{
            html+=`<div class="option"><b>${m.name}</b> ⭐${m.rating}<br><button class="dayoff-btn" onclick="toggleDayOff(${m.id},'2026-05-21')">📅 Выходной на завтра</button></div>`;
        });
        div.innerHTML=html;
    }catch(e){div.innerHTML='<p>Ошибка</p>'}
}

async function toggleDayOff(masterId,date){
    try{
        const r=await fetch('/api/toggle-dayoff',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({master_id:masterId,date:date})});
        const result=await r.json();
        tg.showAlert(result.message||'Готово');
    }catch(e){tg.showAlert('Ошибка соединения')}
}

async function showAdminServices(){
    const div=document.getElementById('adminContent');
    try{
        const r=await fetch('/api/services');
        const services=await r.json();
        let html='<h3>💇 Услуги</h3>';
        services.forEach(s=>{
            html+=`<div class="option"><b>${s.name}</b> — ${s.price}₽</div>`;
        });
        div.innerHTML=html;
    }catch(e){div.innerHTML='<p>Ошибка</p>'}
}

function ld(){
    sh(1);
}

init();
