const tg=window.Telegram.WebApp;tg.expand();tg.ready();tg.setHeaderColor('#0d0d0d');tg.setBackgroundColor('#0d0d0d');
let svc,mst,date,time,services,masters,isSubmitting=false;
let editMasterId=null,editServiceId=null;
const userId=tg.initDataUnsafe?.user?.id;
const adminIds=[5724746367];
const isAdmin=adminIds.includes(userId);

async function init(){await loadData();showMenu();}

async function loadData(){
    try{const r=await fetch('/api/services');services=await r.json();}catch(e){}
    try{const r=await fetch('/api/masters');masters=await r.json();}catch(e){}
}

function showMenu(){
    document.querySelectorAll('.section').forEach(el=>el.style.display='none');
    document.getElementById('menu').style.display='block';
    const list=document.getElementById('menu-list');
    let items=[{icon:'✂️',text:'Записаться',id:'book'},{icon:'📋',text:'Мои записи',id:'my-bookings'},{icon:'⭐',text:'Отзывы',id:'reviews'},{icon:'🎁',text:'Бонусы',id:'bonuses'},{icon:'🔗',text:'Поделиться',action:'share'}];
    if(isAdmin){items.push({icon:'📊',text:'Статистика',id:'stats'},{icon:'📅',text:'Записи на сегодня',id:'today-bookings'},{icon:'👥',text:'Мастера',id:'masters-admin'},{icon:'💇',text:'Услуги',id:'services-admin'},{icon:'📢',text:'Рассылка',id:'broadcast'});}
    list.innerHTML='';
    items.forEach(item=>{const d=document.createElement('div');d.className='menu-card';d.innerHTML=`<span>${item.icon}</span><span>${item.text}</span>`;d.onclick=()=>{if(item.action==='share')shareRef();else showSection(item.id);};list.appendChild(d);});
}

async function showSection(s){
    document.querySelectorAll('.section').forEach(el=>el.style.display='none');
    const sec=document.getElementById(s);if(sec)sec.style.display='block';
    if(s==='book'){await loadData();startBooking();}
    if(s==='my-bookings')loadMyBookings();
    if(s==='reviews')loadReviews();
    if(s==='bonuses')loadBonuses();
    if(s==='stats')loadStats();
    if(s==='today-bookings')loadTodayBookings();
    if(s==='masters-admin')loadMastersAdmin();
    if(s==='services-admin')loadServicesAdmin();
}

function goBack(){
    const bookSection=document.getElementById('book');
    if(bookSection.style.display==='block'){
        const steps=document.querySelectorAll('#book .step');
        const activeStep=document.querySelector('#book .step.active');
        if(activeStep&&activeStep.id==='b1'){showMenu();return;}
        for(let i=steps.length-1;i>=0;i--){if(steps[i].classList.contains('active')&&i>0){steps[i].classList.remove('active');steps[i-1].classList.add('active');return;}}
    }
    showMenu();
}

// === ЗАПИСЬ ===
function startBooking(){
    document.querySelectorAll('#book .step').forEach((el,i)=>el.classList.toggle('active',i===0));
    svc=null;mst=null;date=null;time=null;
    loadServicesUI();
}

function loadServicesUI(){
    const s=document.getElementById('svc');s.innerHTML='';
    if(!services||services.length===0){s.innerHTML='<p>Нет доступных услуг</p>';return;}
    services.filter(x=>x.is_active).forEach(x=>{const e=document.createElement('div');e.className='option';e.innerHTML=`<div class="info"><b>${x.name}</b><span>${x.duration} мин</span></div><strong style="color:#c9a96e">${x.price}₽</strong>`;e.onclick=()=>{svc=x;goStep(2);};s.appendChild(e)});
}

function loadMastersUI(){
    const m=document.getElementById('mst');m.innerHTML='';
    if(!masters||masters.length===0){m.innerHTML='<p>Нет доступных мастеров</p>';return;}
    masters.filter(x=>x.is_active).forEach(x=>{const e=document.createElement('div');e.className='option';e.innerHTML=`<img src="${x.photo_url||x.photo||''}" onerror="this.style.display='none'"><div class="info"><b>${x.name}</b><span>⭐${x.rating||'—'} | Опыт ${x.experience_years||x.experience||0} лет</span></div>`;e.onclick=()=>{mst=x;goStep(3);};m.appendChild(e)});
}

function goStep(n){
    document.querySelectorAll('#book .step').forEach(el=>el.classList.remove('active'));
    document.getElementById('b'+n).classList.add('active');
    if(n===2)loadMastersUI();
    if(n===3)gd();
    if(n===4)gt();
    if(n===5){document.getElementById('sm_svc').textContent=svc.name;document.getElementById('sm_mst').textContent=mst.name;document.getElementById('sm_dt').textContent=date;document.getElementById('sm_tm').textContent=time;document.getElementById('sm_pr').textContent=svc.price+'₽';}
}

function gd(){const g=document.getElementById('dt');g.innerHTML='';const t=new Date();for(let i=0;i<7;i++){const d=new Date(t);d.setDate(t.getDate()+i);const ds=d.toISOString().split('T')[0];const b=document.createElement('div');b.className='grid-item';b.textContent=d.toLocaleDateString('ru-RU',{day:'numeric',month:'short',weekday:'short'});b.onclick=()=>{date=ds;goStep(4);};g.appendChild(b)}}

async function gt(){const g=document.getElementById('tm');g.innerHTML='';try{const r=await fetch(`/api/booked-slots?date=${date}&master_id=${mst.id}`);const bk=(await r.json()).map(x=>x.time);for(let h=10;h<21;h++)for(let m=0;m<60;m+=30){const t=String(h).padStart(2,'0')+':'+String(m).padStart(2,'0');const b=document.createElement('div');b.className='grid-item';if(bk.includes(t)){b.classList.add('booked');b.textContent=t}else{b.textContent=t;b.onclick=()=>{time=t;goStep(5);}};g.appendChild(b)}}catch(e){tg.showAlert('Ошибка загрузки')}}

async function cf(){
    if(isSubmitting)return;const user=tg.initDataUnsafe.user;if(!user){tg.showAlert('Ошибка');return}
    isSubmitting=true;
    const p={telegram_id:user.id,chat_id:user.id,username:user.username||null,first_name:user.first_name||null,last_name:user.last_name||null,service_id:svc.id,master_id:mst.id,date:date,time:time};
    try{const r=await fetch('/api/book',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(p)});const j=await r.json();if(j.ok){tg.showAlert('Запись подтверждена!');showMenu()}else{tg.showAlert(j.detail||'Ошибка')}}catch(e){tg.showAlert('Ошибка соединения')}
    isSubmitting=false;
}

// === МОИ ЗАПИСИ ===
async function loadMyBookings(){
    const d=document.getElementById('my-bookings-content');d.innerHTML='Загрузка...';
    try{const r=await fetch('/api/my-bookings?telegram_id='+userId);const b=await r.json();if(!b.length){d.innerHTML='<p>Нет записей</p>';return}let h='';b.forEach(x=>{h+=`<div class="option"><span>${x.date} ${x.time}</span>${x.status==='confirmed'?`<button class="cancel-btn" onclick="cancelMyBooking(${x.id})">❌</button>`:'❌ Отменена'}</div>`;});d.innerHTML=h;}catch(e){d.innerHTML='<p>Ошибка</p>'}
}
async function cancelMyBooking(id){try{const r=await fetch('/api/cancel-booking',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({booking_id:id})});const j=await r.json();if(j.ok){tg.showAlert('Запись отменена');loadMyBookings()}else{tg.showAlert('Ошибка')}}catch(e){tg.showAlert('Ошибка')}}

// === ОТЗЫВЫ ===
async function loadReviews(){
    const d=document.getElementById('reviews-content');d.innerHTML='Загрузка...';
    try{const r=await fetch('/api/my-confirmed-bookings?telegram_id='+userId);const b=await r.json();if(!b.length){d.innerHTML='<p>Нет завершённых записей</p>';return}let h='';b.forEach(x=>{h+=`<div class="option" onclick="showStars(${x.id})"><span>${x.date} ${x.time}</span></div>`;});d.innerHTML=h;}catch(e){d.innerHTML='<p>Ошибка</p>'}
}
function showStars(bookingId){
    const d=document.getElementById('reviews-content');let h='<h3>Оцените визит</h3><div class="stars-container">';
    for(let i=1;i<=5;i++){h+=`<span class="star" onclick="submitReview(${bookingId},${i})" style="font-size:40px;cursor:pointer;">☆</span>`;}
    h+='</div>';d.innerHTML=h;
    document.querySelectorAll('.star').forEach((s,idx)=>{s.addEventListener('mouseenter',()=>{document.querySelectorAll('.star').forEach((ss,i)=>{ss.textContent=i<=idx?'★':'☆'});});});
}
async function submitReview(bookingId,rating){try{const r=await fetch('/api/submit-review',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({booking_id:bookingId,rating:rating,telegram_id:userId})});const j=await r.json();if(j.ok){tg.showAlert('Спасибо за оценку! '+ '⭐'.repeat(rating));loadReviews()}else{tg.showAlert('Ошибка')}}catch(e){tg.showAlert('Ошибка')}}

// === БОНУСЫ ===
async function loadBonuses(){const d=document.getElementById('bonuses-content');try{const r=await fetch('/api/my-bonuses?telegram_id='+userId);const j=await r.json();d.innerHTML=`<p>Визитов: ${j.visits}</p><p>Баланс: ${j.bonus}₽</p><p>До бонуса: ${j.next_bonus} визитов</p>`;}catch(e){d.innerHTML='<p>Ошибка</p>'}}

// === СТАТИСТИКА ===
async function loadStats(){const d=document.getElementById('stats-content');try{const r=await fetch('/api/admin/stats');const j=await r.json();d.innerHTML=`<div class="menu-card"><span>📅 Записей сегодня</span><strong>${j.today}</strong></div><div class="menu-card"><span>👥 Клиентов</span><strong>${j.clients}</strong></div><div class="menu-card"><span>💰 Выручка сегодня</span><strong>${j.revenue||0}₽</strong></div>`;}catch(e){d.innerHTML='<p>Ошибка</p>'}}

// === ЗАПИСИ НА СЕГОДНЯ ===
async function loadTodayBookings(){const d=document.getElementById('today-bookings-content');try{const r=await fetch('/api/admin/today-bookings');const b=await r.json();if(!b.length){d.innerHTML='<p>Нет записей</p>';return}let h='';b.forEach(x=>{h+=`<div class="option"><span>${x.time} #${x.id}</span><button class="cancel-btn" onclick="adminCancel(${x.id})">❌</button></div>`;});d.innerHTML=h;}catch(e){d.innerHTML='<p>Ошибка</p>'}}
async function adminCancel(id){try{const r=await fetch('/api/admin/cancel-booking',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({booking_id:id})});const j=await r.json();if(j.ok){tg.showAlert('Запись отменена');loadTodayBookings()}else{tg.showAlert('Ошибка')}}catch(e){tg.showAlert('Ошибка')}}

// === МАСТЕРА ===
async function loadMastersAdmin(){const d=document.getElementById('masters-admin-content');await loadData();let h='';masters.forEach(m=>{h+=`<div class="option"><span>${m.name}</span><span>⭐${m.rating||'—'}</span><button class="cancel-btn" onclick="toggleMaster(${m.id})">${m.is_active?'⏸️':'▶️'}</button><button class="cancel-btn" onclick="editMaster(${m.id})">✏️</button></div>`;});d.innerHTML=h||'<p>Нет мастеров</p>';}
function showMasterForm(){editMasterId=null;document.getElementById('master-form-title').textContent='Добавить мастера';document.getElementById('mf-name').value='';document.getElementById('mf-photo').value='';document.getElementById('mf-exp').value='';document.getElementById('mf-file').value='';showSectionRaw('master-form');}
function editMaster(id){const m=masters.find(x=>x.id===id);if(!m)return;editMasterId=id;document.getElementById('master-form-title').textContent='Изменить мастера';document.getElementById('mf-name').value=m.name;document.getElementById('mf-photo').value=m.photo_url||m.photo||'';document.getElementById('mf-exp').value=m.experience_years||m.experience||0;showSectionRaw('master-form');}
function previewFile(){const f=document.getElementById('mf-file').files[0];if(f){const reader=new FileReader();reader.onload=()=>{document.getElementById('mf-photo').value=reader.result;};reader.readAsDataURL(f);}}
async function saveMaster(){
    const name=document.getElementById('mf-name').value.trim();if(!name){tg.showAlert('Введите имя');return}
    const photo=document.getElementById('mf-photo').value.trim();const exp=parseInt(document.getElementById('mf-exp').value)||0;
    const url=editMasterId?'/api/admin/masters/'+editMasterId:'/api/admin/masters';
    const method=editMasterId?'PUT':'POST';
    try{const r=await fetch(url,{method,headers:{'Content-Type':'application/json'},body:JSON.stringify({name,photo_url:photo||null,experience_years:exp})});if(r.ok){tg.showAlert(editMasterId?'Мастер обновлён':'Мастер добавлен');showSection('masters-admin')}else{tg.showAlert('Ошибка')}}catch(e){tg.showAlert('Ошибка')}
}
async function toggleMaster(id){try{const r=await fetch('/api/admin/masters/'+id+'/toggle',{method:'POST'});if(r.ok){tg.showAlert('Статус изменён');loadMastersAdmin()}}catch(e){tg.showAlert('Ошибка')}}

// === УСЛУГИ ===
async function loadServicesAdmin(){const d=document.getElementById('services-admin-content');await loadData();let h='';services.forEach(s=>{h+=`<div class="option"><span>${s.name}</span><span>${s.price}₽</span><button class="cancel-btn" onclick="toggleService(${s.id})">${s.is_active?'⏸️':'▶️'}</button><button class="cancel-btn" onclick="editService(${s.id})">✏️</button></div>`;});d.innerHTML=h||'<p>Нет услуг</p>';}
function showServiceForm(){editServiceId=null;document.getElementById('service-form-title').textContent='Добавить услугу';document.getElementById('sf-name').value='';document.getElementById('sf-price').value='';document.getElementById('sf-duration').value='';document.getElementById('sf-category').value='';showSectionRaw('service-form');}
function editService(id){const s=services.find(x=>x.id===id);if(!s)return;editServiceId=id;document.getElementById('service-form-title').textContent='Изменить услугу';document.getElementById('sf-name').value=s.name;document.getElementById('sf-price').value=s.price;document.getElementById('sf-duration').value=s.duration_minutes||s.duration;document.getElementById('sf-category').value=s.category||'';showSectionRaw('service-form');}
async function saveService(){
    const name=document.getElementById('sf-name').value.trim();if(!name){tg.showAlert('Введите название');return}
    const price=parseInt(document.getElementById('sf-price').value)||0;const duration=parseInt(document.getElementById('sf-duration').value)||0;const category=document.getElementById('sf-category').value.trim();
    const url=editServiceId?'/api/admin/services/'+editServiceId:'/api/admin/services';
    const method=editServiceId?'PUT':'POST';
    try{const r=await fetch(url,{method,headers:{'Content-Type':'application/json'},body:JSON.stringify({name,price,duration_minutes:duration,category:category||null})});if(r.ok){tg.showAlert(editServiceId?'Услуга обновлена':'Услуга добавлена');showSection('services-admin')}else{tg.showAlert('Ошибка')}}catch(e){tg.showAlert('Ошибка')}
}
async function toggleService(id){try{const r=await fetch('/api/admin/services/'+id+'/toggle',{method:'POST'});if(r.ok){tg.showAlert('Статус изменён');loadServicesAdmin()}}catch(e){tg.showAlert('Ошибка')}}

// === РАССЫЛКА ===
async function sendBroadcast(){const text=document.getElementById('broadcast-text').value.trim();if(!text){tg.showAlert('Введите текст');return}try{const r=await fetch('/api/admin/broadcast',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text})});const j=await r.json();if(j.ok){tg.showAlert('Рассылка отправлена: '+j.sent+'/'+j.total)}else{tg.showAlert('Ошибка')}}catch(e){tg.showAlert('Ошибка')}}

// === ПОДЕЛИТЬСЯ ===
function shareRef(){tg.showAlert('Ссылка на бота: t.me/Barber_Kirovsk_bot');}

function showSectionRaw(id){document.querySelectorAll('.section').forEach(el=>el.style.display='none');document.getElementById(id).style.display='block';}

init();
