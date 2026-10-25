'use strict';

/* CPU Mode Control - front-end
   - live status poll: 1s visible / 5s hidden tab
   - apply: 3s minimum overlay, 10s hard timeout, backend verifies via readback
   - page close: sendBeacon -> server shuts down (watchdog unaffected) */

const qs = new URLSearchParams(location.search);
const TOKEN = qs.get('token') || '';
const API = 'cgi-bin/api.sh?token=' + encodeURIComponent(TOKEN) + '&op=';
const MODE_NAMES = {performance:'Performance', schedutil:'Schedutil', powersave:'Power Save', none:'None'};

const $ = id => document.getElementById(id);
const sleep = ms => new Promise(r => setTimeout(r, ms));

if (!TOKEN) {
  document.body.innerHTML =
    '<div class="offline">Invalid link &mdash; open this page from the KernelSU action button</div>';
  throw new Error('no token');
}

let busy = false;
let lastPoll = 0;
let offlineShown = false;

function fmtKHz(v){ if (v == null) return '\u2014'; const m = v/1000; return (m%1 ? m.toFixed(1) : String(m)) + ' MHz'; }
function fmtHz(v){ if (v == null) return '\u2014'; const m = v/1000000; return (m%1 ? m.toFixed(1) : String(m)) + ' MHz'; }

async function api(op){
  const r = await fetch(API + op, {cache:'no-store'});
  if (!r.ok) throw new Error('http ' + r.status);
  return r.json();
}

function render(j){
  if (offlineShown){ $('offline').classList.add('hidden'); offlineShown = false; }

  const b = $('modeBadge');
  b.textContent = MODE_NAMES[j.mode] || j.mode || 'None';
  b.className = 'badge ' + (j.mode || 'none');

  const w = $('wdBadge');
  if (j.watchdog && j.watchdog.running){
    w.classList.remove('hidden');
    w.textContent = 'watchdog \u00b7 ' + j.watchdog.interval + 's';
  } else {
    w.classList.add('hidden');
  }

  const keys = ['silver','gold','prime'];
  (j.clusters || []).forEach((c,i) => {
    const k = keys[i]; if (!k) return;
    $('c-'+k+'-gov').textContent = c.gov || '\u2014';
    $('c-'+k+'-cur').textContent = fmtKHz(c.cur);
    $('c-'+k+'-min').textContent = fmtKHz(c.min);
    $('c-'+k+'-max').textContent = fmtKHz(c.max);
  });

  const chips = $('coreChips');
  if (chips.children.length !== 8){
    chips.innerHTML = '';
    for (let i = 0; i < 8; i++){
      const d = document.createElement('div');
      d.className = 'chip';
      d.id = 'core-' + i;
      chips.appendChild(d);
    }
  }
  (j.cores || []).forEach(c => {
    const el = $('core-' + c.c);
    if (!el) return;
    el.textContent = 'CPU ' + c.c;
    el.className = 'chip ' + (c.on ? 'on' : 'off');
  });

  $('gpuGov').textContent = (j.gpu && j.gpu.gov) || '\u2014';
  $('gpuCur').textContent = (j.gpu && j.gpu.cur != null) ? fmtHz(j.gpu.cur) : '\u2014';
}

async function pollTick(){
  const gap = document.hidden ? 5000 : 1000;
  const now = Date.now();
  if (now - lastPoll < gap - 50) return;
  lastPoll = now;
  try { render(await api('status')); }
  catch(e){
    if (!offlineShown){ offlineShown = true; $('offline').classList.remove('hidden'); }
  }
}
setInterval(pollTick, 250);
pollTick();

function popup(title, cls, detail){
  $('popupTitle').textContent = title;
  $('popupTitle').className = cls;
  $('popupDetail').textContent = detail || '';
  $('popup').classList.remove('hidden');
  clearTimeout(popup._t);
  popup._t = setTimeout(() => $('popup').classList.add('hidden'), 4500);
}

function setButtons(dis){
  document.querySelectorAll('.mode-btn').forEach(b => { b.disabled = dis; });
}

async function applyMode(mode){
  if (busy) return;
  busy = true;
  setButtons(true);

  const label = MODE_NAMES[mode] || mode;
  const t0 = Date.now();

  $('overlayText').textContent = 'Applying ' + label + '\u2026';
  $('overlay').classList.remove('hidden');

  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 10000);
  let res = null;
  let dead = false;
  try { res = await (await fetch(API + 'apply&mode=' + mode, {signal: ctrl.signal})).json(); }
  catch(e){ dead = true; }
  clearTimeout(timer);

  const remain = 3000 - (Date.now() - t0);
  if (remain > 0) await sleep(remain);
  $('overlay').classList.add('hidden');

  if (res && res.ok){
    popup('\u2713 ' + label + ' applied successfully', 'ok',
      'verified in ' + res.elapsed + 's' + (res.attempts > 1 ? ' (' + res.attempts + ' attempts)' : ''));
  } else if (res && res.error === 'busy'){
    popup('Another operation is in progress', 'warn');
  } else if (res && res.ok === false){
    popup('\u2717 ' + label + ' FAILED', 'fail',
      (res.detail || res.error || '').split(';').join('\n'));
  } else {
    popup('\u2717 ' + label + ' TIMEOUT', 'fail', 'Mode not applied');
  }

  busy = false;
  setButtons(false);
  lastPoll = 0;
  pollTick();
}

document.querySelectorAll('.mode-btn').forEach(b => {
  b.addEventListener('click', () => applyMode(b.dataset.mode));
});

addEventListener('pagehide', () => {
  try {
    navigator.sendBeacon('cgi-bin/api.sh?op=shutdown&token=' + encodeURIComponent(TOKEN));
  } catch(e){}
});
