const tg=window.Telegram.WebApp;tg.expand();tg.ready();tg.setHeaderColor('#0d0d0d');tg.setBackgroundColor('#0d0d0d');
let svc,mst,date,time,services,masters,isSubmitting=false;

async function init(){await loadServices();await loadMasters();}
async function loadServices(){const r=await fetch('/api/services');services=await r.json();const s=document.getElementById('svc');s.innerHTML='';services.forEach(x=>{const e=document.createElement('div');e.className='option';e.innerHTML=`<div class="info"><b>${x.name}</b><span>${x.duration} мин</span></div><strong style="color:#c9a96e">${x.price}₽</strong>`;e.onclick=()=>{document.querySelectorAll('#svc .option').forEach(el=>el.classList.remove('selected'));e.classList.add('selected');svc=x;};s.appendChild(e)});}
async function loadMasters(){const r=await fetch('/api/masters');masters=await r.json();const m=document.getElementById('mst');m.innerHTML='';masters.forEach(x=>{const e=document.createElement('div');e.className='option';e.innerHTML=`<img src="${x.photo}" onerror="this.style.display='none'"><div class="info"><b>${x.name}</b><span>⭐${x.rating} | Опыт ${x.experience} лет</span></div>`;e.onclick=()=>{document.querySelectorAll('#mst .option').forEach(el=>el.classList.remove('selected'));e.classList.add('selected');mst=x;};m.appendChild(e)});}

function gd(){const g=document.getElementById('dt');g.innerHTML='';const t=new Date();for(let i=0;i<7;i++){const d=new Date(t);d.setDate(t.getDate()+i);const ds=d.toISOString().split('T')[0];const b=document.createElement('div');b.textContent=d.toLocaleDateString('ru-RU',{day:'numeric',month:'short',weekday:'short'});b.onclick=()=>{document.querySelectorAll('#dt div').forEach(e=>e.classList.remove('selected'));b.classList.add('selected');date=ds;};g.appendChild(b)}}

async function gt(){const g=document.getElementById('tm');g.innerHTML='';try{const r=await fetch(`/api/booked-slots?date=${date}&master_id=${mst.id}`);if(!r.ok)throw new Error('Error');const bk=(await r.json()).map(x=>x.time);for(let h=10;h<21;h++)for(let m=0;m<60;m+=30){const t=`${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`;const b=document.createElement('div');if(bk.includes(t)){b.className='booked';b.textContent=t}else{b.textContent=t;b.onclick=()=>{document.querySelectorAll('#tm div').forEach(e=>e.classList.remove('selected'));b.classList.add('selected');time=t}};g.appendChild(b)}}catch(e){tg.showAlert('Ошибка загрузки времени')}}

function sh(n){document.querySelectorAll('.step').forEach(e=>e.classList.remove('active'));document.getElementById('s'+n).classList.add('active');if(n===3)gd();if(n===4)gt();if(n===5){document.getElementById('sm_svc').textContent=svc.name;document.getElementById('sm_mst').textContent=mst.name;document.getElementById('sm_dt').textContent=date;document.getElementById('sm_tm').textContent=time;document.getElementById('sm_pr').textContent=svc.price+'₽'}}

function nx(n){if(n===2&&!svc){tg.showAlert('Выберите услугу');return}if(n===3&&!mst){tg.showAlert('Выберите мастера');return}if(n===4&&!date){tg.showAlert('Выберите дату');return}if(n===5&&!time){tg.showAlert('Выберите время');return}sh(n)}

function pv(n){sh(n)}

async function cf(){
    if(isSubmitting)return;const user=tg.initDataUnsafe.user;if(!user){tg.showAlert('Ошибка: данные пользователя недоступны');return}
    isSubmitting=true;const btn=document.querySelector('.btn-confirm');btn.textContent='Создаём...';btn.disabled=true;
    const payload={telegram_id:user.id,chat_id:user.id,username:user.username||null,first_name:user.first_name||null,last_name:user.last_name||null,service_id:svc.id,master_id:mst.id,date:date,time:time};
    try{const res=await fetch('/api/book',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});const result=await res.json();if(result.ok){tg.showAlert(`Запись подтверждена!\n\n${result.service}\nМастер: ${result.master}\n${result.date} в ${result.time}\nЦена: ${result.price}₽`);tg.close()}else{tg.showAlert(`${result.detail||'Ошибка записи'}`)}}catch(e){tg.showAlert('Ошибка соединения')}
    isSubmitting=false;btn.textContent='Подтвердить';btn.disabled=false;
}

init();
