const tg=window.Telegram.WebApp;tg.expand();tg.ready();tg.setHeaderColor('#0d0d0d');tg.setBackgroundColor('#0d0d0d');
let svc,mst,date,time,services,masters,isSubmitting=false;
let editMasterId=null,editServiceId=null;
const userId=tg.initDataUnsafe?.user?.id;
const adminIds=[5724746367];
const isAdmin=adminIds.includes(userId);

async function init(){
    await loadServicesData();
    await loadMastersData();
    if(isAdmin){document.getElementById('admin-menu').style.display='block';}else{showSection('book');}
}

function showSection(s){
    document.getElementById('admin-menu').style.display='none';
    document.querySelectorAll('.section').forEach(el=>el.style.display='none');
    const sec=document.getElementById('s-'+s);
    if(sec)sec.style.display='block';
    if(s==='stats')loadStats();
    if(s==='bookings')loadBookings();
    if(s==='masters')loadMastersSection();
    if(s==='services')loadServicesSection();
    if(s==='book')resetBook();
}

function backToMenu(){
    document.querySelectorAll('.section').forEach(el=>el.style.display='none');
    document.getElementById('admin-menu').style.display='block';
}
function backToStart(){if(isAdmin)backToMenu();}

// === СТАТИСТИКА ===
async function loadStats(){
    const d=document.getElementById('stats-content');d.innerHTML='Загрузка...';
    try{const r=await fetch('/api/admin/stats');const j=await r.json();d.innerHTML=`<div class="menu-card"><span>📅 Записей сегодня</span><strong>${j.today}</strong></div><div class="menu-card"><span>👥 Всего клиентов</span><strong>${j.clients}</strong></div><div class="menu-card"><span>📋 Всего записей</span><strong>${j.total||0}</strong></div>`;}catch(e){d.innerHTML='<p>Ошибка</p>'}
}

// === ЗАПИСИ ===
async function loadBookings(){
    const d=document.getElementById('bookings-content');d.innerHTML='Загрузка...';
    try{const r=await fetch('/api/admin/today-bookings');const b=await r.json();if(!b.length){d.innerHTML='<p>На сегодня записей нет.</p>';return}let h='';b.forEach(x=>{h+=`<div class="menu-card"><span>🕐 ${x.time} — #${x.id}</span><button class="cancel-btn" onclick="cancelBooking(${x.id})">❌ Отменить</button></div>`;});d.innerHTML=h;}catch(e){d.innerHTML='<p>Ошибка</p>'}
}
async function cancelBooking(id){
    try{const r=await fetch('/api/admin/cancel-booking',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({booking_id:id})});const j=await r.json();if(j.ok){tg.showAlert('Запись отменена');loadBookings();}else{tg.showAlert(j.detail||'Ошибка')}}catch(e){tg.showAlert('Ошибка')}
}

// === МАСТЕРА ===
async function loadMastersData(){try{const r=await fetch('/api/masters');masters=await r.json();}catch(e){}}
async function loadMastersSection(){
    const d=document.getElementById('masters-content');d.innerHTML='Загрузка...';
    await loadMastersData();
    let h='';masters.forEach(m=>{h+=`<div class="menu-card"><span>👤 ${m.name}</span><span>⭐${m.rating||'—'}</span><button class="cancel-btn" onclick="toggleMaster(${m.id})">${m.is_active?'⏸️ Отключить':'▶️ Включить'}</button><button class="cancel-btn" onclick="editMaster(${m.id})">✏️</button></div>`;});d.innerHTML=h||'<p>Нет мастеров</p>';
}
function showMasterForm(){editMasterId=null;document.getElementById('master-form-title').textContent='Добавить мастера';document.getElementById('mf-name').value='';document.getElementById('mf-photo').value='';document.getElementById('mf-exp').value='';document.querySelectorAll('.section').forEach(el=>el.style.display='none');document.getElementById('s-master-form').style.display='block';}
function editMaster(id){
    const m=masters.find(x=>x.id===id);if(!m)return;
    editMasterId=id;document.getElementById('master-form-title').textContent='Изменить мастера';document.getElementById('mf-name').value=m.name;document.getElementById('mf-photo').value=m.photo||'';document.getElementById('mf-exp').value=m.experience||0;
    document.querySelectorAll('.section').forEach(el=>el.style.display='none');document.getElementById('s-master-form').style.display='block';
}
async function saveMaster(){
    const name=document.getElementById('mf-name').value.trim();if(!name){tg.showAlert('Введите имя');return}
    const photo=document.getElementById('mf-photo').value.trim();const exp=parseInt(document.getElementById('mf-exp').value)||0;
    const url=editMasterId?'/api/admin/masters/'+editMasterId:'/api/admin/masters';
    const method=editMasterId?'PUT':'POST';
    try{const r=await fetch(url,{method,headers:{'Content-Type':'application/json'},body:JSON.stringify({name,photo_url:photo||null,experience_years:exp})});if(r.ok){tg.showAlert(editMasterId?'Мастер обновлён':'Мастер добавлен');showSection('masters');}else{tg.showAlert('Ошибка')}}catch(e){tg.showAlert('Ошибка')}
}
async function toggleMaster(id){
    try{const r=await fetch('/api/admin/masters/'+id+'/toggle',{method:'POST'});if(r.ok){tg.showAlert('Статус изменён');loadMastersSection();}}catch(e){tg.showAlert('Ошибка')}
}

// === УСЛУГИ ===
async function loadServicesData(){try{const r=await fetch('/api/services');services=await r.json();}catch(e){}}
async function loadServicesSection(){
    const d=document.getElementById('services-content');d.innerHTML='Загрузка...';
    await loadServicesData();
    let h='';services.forEach(s=>{h+=`<div class="menu-card"><span>${s.name}</span><span>${s.price}₽</span><button class="cancel-btn" onclick="toggleService(${s.id})">${s.is_active?'⏸️ Отключить':'▶️ Включить'}</button><button class="cancel-btn" onclick="editService(${s.id})">✏️</button></div>`;});d.innerHTML=h||'<p>Нет услуг</p>';
}
function showServiceForm(){editServiceId=null;document.getElementById('service-form-title').textContent='Добавить услугу';document.getElementById('sf-name').value='';document.getElementById('sf-price').value='';document.getElementById('sf-duration').value='';document.getElementById('sf-category').value='';document.querySelectorAll('.section').forEach(el=>el.style.display='none');document.getElementById('s-service-form').style.display='block';}
function editService(id){
    const s=services.find(x=>x.id===id);if(!s)return;
    editServiceId=id;document.getElementById('service-form-title').textContent='Изменить услугу';document.getElementById('sf-name').value=s.name;document.getElementById('sf-price').value=s.price;document.getElementById('sf-duration').value=s.duration;document.getElementById('sf-category').value=s.category||'';
    document.querySelectorAll('.section').forEach(el=>el.style.display='none');document.getElementById('s-service-form').style.display='block';
}
async function saveService(){
    const name=document.getElementById('sf-name').value.trim();if(!name){tg.showAlert('Введите название');return}
    const price=parseInt(document.getElementById('sf-price').value)||0;const duration=parseInt(document.getElementById('sf-duration').value)||0;const category=document.getElementById('sf-category').value.trim();
    const url=editServiceId?'/api/admin/services/'+editServiceId:'/api/admin/services';
    const method=editServiceId?'PUT':'POST';
    try{const r=await fetch(url,{method,headers:{'Content-Type':'application/json'},body:JSON.stringify({name,price,duration_minutes:duration,category:category||null})});if(r.ok){tg.showAlert(editServiceId?'Услуга обновлена':'Услуга добавлена');showSection('services');}else{tg.showAlert('Ошибка')}}catch(e){tg.showAlert('Ошибка')}
}
async function toggleService(id){
    try{const r=await fetch('/api/admin/services/'+id+'/toggle',{method:'POST'});if(r.ok){tg.showAlert('Статус изменён');loadServicesSection();}}catch(e){tg.showAlert('Ошибка')}
}

// === ЗАПИСЬ (без кнопки Далее) ===
async function loadServicesData(){
    try{const r=await fetch('/api/services');services=await r.json();}catch(e){}
}
async function loadServicesUI(){
    await loadServicesData();
    const s=document.getElementById('svc');s.innerHTML='';
    services.filter(x=>x.is_active).forEach(x=>{const e=document.createElement('div');e.className='menu-card';e.innerHTML=`<span>${x.name}</span><span>${x.price}₽</span>`;e.onclick=()=>{svc=x;nx(2);};s.appendChild(e)});
}
async function loadMastersUI(){
    await loadMastersData();
    const m=document.getElementById('mst');m.innerHTML='';
    masters.filter(x=>x.is_active).forEach(x=>{const e=document.createElement('div');e.className='menu-card';e.innerHTML=`<span>👤 ${x.name}</span><span>⭐${x.rating||'—'}</span>`;e.onclick=()=>{mst=x;nx(3);};m.appendChild(e)});
}

function resetBook(){
    document.querySelectorAll('.book-step').forEach((el,i)=>{el.classList.toggle('active',i===0);});
    svc=null;mst=null;date=null;time=null;
    loadServicesUI();
}

function nx(n){
    if(n===2&&!svc){tg.showAlert('Выберите услугу');return}
    if(n===3){document.querySelectorAll('.book-step').forEach(el=>el.classList.remove('active'));document.getElementById('b2').classList.add('active');loadMastersUI();return}
    if(n===4&&!mst){tg.showAlert('Выберите мастера');return}
    if(n===5&&!date){tg.showAlert('Выберите дату');return}
    if(n===6&&!time){tg.showAlert('Выберите время');return}
    document.querySelectorAll('.book-step').forEach(el=>el.classList.remove('active'));
    if(n===4){document.getElementById('b3').classList.add('active');gd();return}
    if(n===5){document.getElementById('b4').classList.add('active');gt();return}
    if(n===6){document.getElementById('b5').classList.add('active');document.getElementById('sm_svc').textContent=svc.name;document.getElementById('sm_mst').textContent=mst.name;document.getElementById('sm_dt').textContent=date;document.getElementById('sm_tm').textContent=time;document.getElementById('sm_pr').textContent=svc.price+'₽';return}
}

// При выборе мастера — сразу дата
function pv(n){
    document.querySelectorAll('.book-step').forEach(el=>el.classList.remove('active'));
    document.getElementById('b'+(n-1)).classList.add('active');
    if(n-1===2)loadMastersUI();
}

function gd(){const g=document.getElementById('dt');g.innerHTML='';const t=new Date();for(let i=0;i<7;i++){const d=new Date(t);d.setDate(t.getDate()+i);const ds=d.toISOString().split('T')[0];const b=document.createElement('div');b.className='grid-item';b.textContent=d.toLocaleDateString('ru-RU',{day:'numeric',month:'short',weekday:'short'});b.onclick=()=>{date=ds;nx(5);};g.appendChild(b)}}

async function gt(){const g=document.getElementById('tm');g.innerHTML='';try{const r=await fetch('/api/booked-slots?date='+date+'&master_id='+mst.id);const bk=(await r.json()).map(x=>x.time);for(let h=10;h<21;h++)for(let m=0;m<60;m+=30){const t=String(h).padStart(2,'0')+':'+String(m).padStart(2,'0');const b=document.createElement('div');b.className='grid-item';if(bk.includes(t)){b.classList.add('booked');b.textContent=t}else{b.textContent=t;b.onclick=()=>{time=t;nx(6);}};g.appendChild(b)}}catch(e){tg.showAlert('Ошибка')}}

async function cf(){
    if(isSubmitting)return;const user=tg.initDataUnsafe.user;if(!user){tg.showAlert('Ошибка');return}
    isSubmitting=true;
    const p={telegram_id:user.id,chat_id:user.id,username:user.username||null,first_name:user.first_name||null,last_name:user.last_name||null,service_id:svc.id,master_id:mst.id,date:date,time:time};
    try{const r=await fetch('/api/book',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(p)});const j=await r.json();if(j.ok){tg.showAlert('Запись подтверждена!');backToStart()}else{tg.showAlert(j.detail||'Ошибка')}}catch(e){tg.showAlert('Ошибка соединения')}
    isSubmitting=false;
}

init();
