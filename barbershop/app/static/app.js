const tg=window.Telegram.WebApp;tg.expand();tg.ready();tg.setHeaderColor('#0d0d0d');tg.setBackgroundColor('#0d0d0d');
let svc,mst,date,time,services,masters,isSubmitting=false;

async function init(){await loadServices();await loadMasters();sh('main');}

function sh(section){
    document.querySelectorAll('#s-main,#s-stats,#s-bookings,#s-masters,#s-services,#s-book').forEach(el=>el.style.display='none');
    if(section==='main') document.getElementById('s-main').style.display='block';
    if(section==='stats'){document.getElementById('s-stats').style.display='block';loadStats();}
    if(section==='bookings'){document.getElementById('s-bookings').style.display='block';loadBookings();}
    if(section==='masters'){document.getElementById('s-masters').style.display='block';loadMastersSection();}
    if(section==='services'){document.getElementById('s-services').style.display='block';loadServicesSection();}
    if(section==='book'){document.getElementById('s-book').style.display='block';resetBook();}
}

function showSection(s){sh(s);}

// Статистика
async function loadStats(){
    const d=document.getElementById('stats-content');d.innerHTML='Загрузка...';
    try{const r=await fetch('/api/admin/stats');const j=await r.json();d.innerHTML=`<div class="menu-card"><span>📅 Записей сегодня</span><strong>${j.today}</strong></div><div class="menu-card"><span>👥 Всего клиентов</span><strong>${j.clients}</strong></div><div class="menu-card"><span>📋 Всего записей</span><strong>${j.total||0}</strong></div>`;}catch(e){d.innerHTML='<p>Ошибка</p>'}
}

// Записи
async function loadBookings(){
    const d=document.getElementById('bookings-content');d.innerHTML='Загрузка...';
    try{const r=await fetch('/api/admin/today-bookings');const b=await r.json();if(!b.length){d.innerHTML='<p>На сегодня записей нет.</p>';return}let h='';b.forEach(x=>{h+=`<div class="menu-card"><span>🕐 ${x.time}</span><span>#${x.id}</span></div>`;});d.innerHTML=h;}catch(e){d.innerHTML='<p>Ошибка</p>'}
}

// Мастера
async function loadMastersSection(){
    const d=document.getElementById('masters-content');d.innerHTML='Загрузка...';
    try{const r=await fetch('/api/masters');const m=await r.json();let h='';m.forEach(x=>{h+=`<div class="menu-card"><span>👤 ${x.name}</span><span>⭐${x.rating}</span></div>`;});d.innerHTML=h;}catch(e){d.innerHTML='<p>Ошибка</p>'}
}

// Услуги
async function loadServicesSection(){
    const d=document.getElementById('services-content');d.innerHTML='Загрузка...';
    try{const r=await fetch('/api/services');const s=await r.json();let h='';s.forEach(x=>{h+=`<div class="menu-card"><span>${x.name}</span><span>${x.price}₽</span></div>`;});d.innerHTML=h;}catch(e){d.innerHTML='<p>Ошибка</p>'}
}

// Запись
async function loadServices(){const r=await fetch('/api/services');services=await r.json();const s=document.getElementById('svc');s.innerHTML='';services.forEach(x=>{const e=document.createElement('div');e.className='menu-card';e.innerHTML=`<span>${x.name}</span><span>${x.price}₽</span>`;e.onclick=()=>{document.querySelectorAll('#svc .menu-card').forEach(el=>el.classList.remove('selected'));e.classList.add('selected');svc=x;};s.appendChild(e)});}
async function loadMasters(){const r=await fetch('/api/masters');masters=await r.json();const m=document.getElementById('mst');m.innerHTML='';masters.forEach(x=>{const e=document.createElement('div');e.className='menu-card';e.innerHTML=`<span>${x.name}</span><span>⭐${x.rating}</span>`;e.onclick=()=>{document.querySelectorAll('#mst .menu-card').forEach(el=>el.classList.remove('selected'));e.classList.add('selected');mst=x;};m.appendChild(e)});}

function resetBook(){
    document.querySelectorAll('#s-book .step').forEach((el,i)=>{if(i===0)el.classList.add('active');else el.classList.remove('active');});
    svc=null;mst=null;date=null;time=null;
}

function nx(n){
    if(n===2&&!svc){tg.showAlert('Выберите услугу');return}
    if(n===3&&!mst){tg.showAlert('Выберите мастера');return}
    if(n===4&&!date){tg.showAlert('Выберите дату');return}
    if(n===5&&!time){tg.showAlert('Выберите время');return}
    document.querySelectorAll('#s-book .step').forEach(el=>el.classList.remove('active'));
    document.getElementById('s'+n).classList.add('active');
    if(n===3)gd();if(n===4)gt();
    if(n===5){document.getElementById('sm_svc').textContent=svc.name;document.getElementById('sm_mst').textContent=mst.name;document.getElementById('sm_dt').textContent=date;document.getElementById('sm_tm').textContent=time;document.getElementById('sm_pr').textContent=svc.price+'₽';}
}

function pv(n){document.querySelectorAll('#s-book .step').forEach(el=>el.classList.remove('active'));document.getElementById('s'+n).classList.add('active');}

function gd(){const g=document.getElementById('dt');g.innerHTML='';const t=new Date();for(let i=0;i<7;i++){const d=new Date(t);d.setDate(t.getDate()+i);const ds=d.toISOString().split('T')[0];const b=document.createElement('div');b.className='grid-item';b.textContent=d.toLocaleDateString('ru-RU',{day:'numeric',month:'short',weekday:'short'});b.onclick=()=>{document.querySelectorAll('#dt .grid-item').forEach(e=>e.classList.remove('selected'));b.classList.add('selected');date=ds;};g.appendChild(b)}}

async function gt(){const g=document.getElementById('tm');g.innerHTML='';try{const r=await fetch('/api/booked-slots?date='+date+'&master_id='+mst.id);const bk=(await r.json()).map(x=>x.time);for(let h=10;h<21;h++)for(let m=0;m<60;m+=30){const t=String(h).padStart(2,'0')+':'+String(m).padStart(2,'0');const b=document.createElement('div');b.className='grid-item';if(bk.includes(t)){b.classList.add('booked');b.textContent=t}else{b.textContent=t;b.onclick=()=>{document.querySelectorAll('#tm .grid-item').forEach(e=>e.classList.remove('selected'));b.classList.add('selected');time=t}};g.appendChild(b)}}catch(e){tg.showAlert('Ошибка загрузки')}}

async function cf(){
    if(isSubmitting)return;const user=tg.initDataUnsafe.user;if(!user){tg.showAlert('Ошибка');return}
    isSubmitting=true;
    const p={telegram_id:user.id,chat_id:user.id,username:user.username||null,first_name:user.first_name||null,last_name:user.last_name||null,service_id:svc.id,master_id:mst.id,date:date,time:time};
    try{const r=await fetch('/api/book',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(p)});const j=await r.json();if(j.ok){tg.showAlert('Запись подтверждена!\n'+j.service+'\nМастер: '+j.master+'\n'+j.date+' в '+j.time+'\nЦена: '+j.price+'₽');sh('main')}else{tg.showAlert(j.detail||'Ошибка')}}catch(e){tg.showAlert('Ошибка соединения')}
    isSubmitting=false;
}

init();
