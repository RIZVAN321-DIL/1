const tg=window.Telegram.WebApp;tg.expand();tg.ready();tg.setHeaderColor('#0d0d0d');tg.setBackgroundColor('#0d0d0d');
let svc,mst,date,time,services,masters,isSubmitting=false;

// Инициализация
async function init(){
    await loadServices();
    await loadMasters();
}

// Переключение разделов
function sh(section){
    document.querySelectorAll('.step').forEach(el=>el.classList.remove('active'));
    document.getElementById('s-'+section).classList.add('active');
    if(section==='stats') loadStats();
    if(section==='bookings') loadBookings();
    if(section==='masters') loadMastersSection();
    if(section==='services') loadServicesSection();
    if(section==='book') resetBookSteps();
    if(section==='main'){} // главное меню
}

// === ГЛАВНОЕ МЕНЮ ===
function showSection(section){sh(section);}

// === СТАТИСТИКА ===
async function loadStats(){
    const div=document.getElementById('stats-content');
    div.innerHTML='Загрузка...';
    try{
        const r=await fetch('/api/admin/stats');
        const data=await r.json();
        div.innerHTML=`<div class="menu-item"><span>📅 Записей сегодня</span><strong>${data.today}</strong></div><div class="menu-item"><span>👥 Всего клиентов</span><strong>${data.clients}</strong></div><div class="menu-item"><span>📋 Всего записей</span><strong>${data.total||0}</strong></div>`;
    }catch(e){div.innerHTML='<p>Ошибка загрузки</p>'}
}

// === ЗАПИСИ ===
async function loadBookings(){
    const div=document.getElementById('bookings-content');
    div.innerHTML='Загрузка...';
    try{
        const r=await fetch('/api/admin/today-bookings');
        const bookings=await r.json();
        if(!bookings.length){div.innerHTML='<p>На сегодня записей нет.</p>';return}
        let html='';
        bookings.forEach(b=>{html+=`<div class="menu-item"><span>🕐 ${b.time}</span><span>#${b.id}</span></div>`;});
        div.innerHTML=html;
    }catch(e){div.innerHTML='<p>Ошибка загрузки</p>'}
}

// === МАСТЕРА ===
async function loadMastersSection(){
    const div=document.getElementById('masters-content');
    div.innerHTML='Загрузка...';
    try{
        const r=await fetch('/api/masters');
        const masters=await r.json();
        let html='';
        masters.forEach(m=>{html+=`<div class="menu-item"><span>👤 ${m.name}</span><span>⭐${m.rating}</span></div>`;});
        div.innerHTML=html;
    }catch(e){div.innerHTML='<p>Ошибка загрузки</p>'}
}

// === УСЛУГИ ===
async function loadServicesSection(){
    const div=document.getElementById('services-content');
    div.innerHTML='Загрузка...';
    try{
        const r=await fetch('/api/services');
        const services=await r.json();
        let html='';
        services.forEach(s=>{html+=`<div class="menu-item"><span>${s.name}</span><span>${s.price}₽</span></div>`;});
        div.innerHTML=html;
    }catch(e){div.innerHTML='<p>Ошибка загрузки</p>'}
}

// === ЗАПИСЬ ===
async function loadServices(){
    const r=await fetch('/api/services');services=await r.json();
    const s=document.getElementById('svc');s.innerHTML='';
    services.forEach(x=>{const e=document.createElement('div');e.className='menu-item';e.innerHTML=`<span>${x.name}</span><span>${x.price}₽</span>`;e.onclick=()=>{document.querySelectorAll('#svc .menu-item').forEach(el=>el.classList.remove('selected'));e.classList.add('selected');svc=x;};s.appendChild(e)});
}

async function loadMasters(){
    const r=await fetch('/api/masters');masters=await r.json();
    const m=document.getElementById('mst');m.innerHTML='';
    masters.forEach(x=>{const e=document.createElement('div');e.className='menu-item';e.innerHTML=`<span>${x.name}</span><span>⭐${x.rating}</span>`;e.onclick=()=>{document.querySelectorAll('#mst .menu-item').forEach(el=>el.classList.remove('selected'));e.classList.add('selected');mst=x;};m.appendChild(e)});
}

function resetBookSteps(){
    document.querySelectorAll('.book-step').forEach(el=>el.classList.remove('active'));
    document.getElementById('b1').classList.add('active');
    svc=null;mst=null;date=null;time=null;
}

function bookNx(n){
    if(n===1&&!svc){tg.showAlert('Выберите услугу');return}
    if(n===2&&!mst){tg.showAlert('Выберите мастера');return}
    if(n===3&&!date){tg.showAlert('Выберите дату');return}
    if(n===4&&!time){tg.showAlert('Выберите время');return}
    document.querySelectorAll('.book-step').forEach(el=>el.classList.remove('active'));
    document.getElementById('b'+(n+1)).classList.add('active');
    if(n===2)gd();
    if(n===3)gt();
    if(n===4){document.getElementById('sm_svc').textContent=svc.name;document.getElementById('sm_mst').textContent=mst.name;document.getElementById('sm_dt').textContent=date;document.getElementById('sm_tm').textContent=time;document.getElementById('sm_pr').textContent=svc.price+'₽';}
}

function bookPv(n){document.querySelectorAll('.book-step').forEach(el=>el.classList.remove('active'));document.getElementById('b'+n).classList.add('active');}

function gd(){const g=document.getElementById('dt');g.innerHTML='';const t=new Date();for(let i=0;i<7;i++){const d=new Date(t);d.setDate(t.getDate()+i);const ds=d.toISOString().split('T')[0];const b=document.createElement('div');b.className='grid-item';b.textContent=d.toLocaleDateString('ru-RU',{day:'numeric',month:'short',weekday:'short'});b.onclick=()=>{document.querySelectorAll('#dt .grid-item').forEach(e=>e.classList.remove('selected'));b.classList.add('selected');date=ds;};g.appendChild(b)}}

async function gt(){const g=document.getElementById('tm');g.innerHTML='';try{const r=await fetch('/api/booked-slots?date='+date+'&master_id='+mst.id);const bk=(await r.json()).map(x=>x.time);for(let h=10;h<21;h++)for(let m=0;m<60;m+=30){const t=String(h).padStart(2,'0')+':'+String(m).padStart(2,'0');const b=document.createElement('div');b.className='grid-item';if(bk.includes(t)){b.classList.add('booked');b.textContent=t}else{b.textContent=t;b.onclick=()=>{document.querySelectorAll('#tm .grid-item').forEach(e=>e.classList.remove('selected'));b.classList.add('selected');time=t}};g.appendChild(b)}}catch(e){tg.showAlert('Ошибка загрузки')}}

async function cf(){
    if(isSubmitting)return;
    const user=tg.initDataUnsafe.user;
    if(!user){tg.showAlert('Ошибка: данные пользователя недоступны');return}
    isSubmitting=true;
    const payload={telegram_id:user.id,chat_id:user.id,username:user.username||null,first_name:user.first_name||null,last_name:user.last_name||null,service_id:svc.id,master_id:mst.id,date:date,time:time};
    try{
        const r=await fetch('/api/book',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
        const result=await r.json();
        if(result.ok){tg.showAlert(`Запись подтверждена!\n${result.service}\nМастер: ${result.master}\n${result.date} в ${result.time}\nЦена: ${result.price}₽`);sh('main')}else{tg.showAlert(result.detail||'Ошибка')}
    }catch(e){tg.showAlert('Ошибка соединения')}
    isSubmitting=false;
}

init();
