// k6a-ctl app.js v1.3.2
var d = {};
var _toastT = null;

function ksuExec(cmd){
try{
if(window.ksu&&typeof window.ksu.exec==='function'){
try{window.ksu.exec(cmd,'',function(){})}catch(e1){}
try{window.ksu.exec(cmd)}catch(e2){}
return}}catch(e){}
try{if(window.KernelSU&&window.KernelSU.exec){window.KernelSU.exec(cmd,'',function(){})}}catch(e3){}
}

function api(path) {
    new Image().src = 'http://127.0.0.1:8767' + path + '&t=' + Date.now();
}

function toast(msg) {
    var t = document.getElementById('toast');
    t.textContent = msg;
    t.style.opacity = 1;
    clearTimeout(_toastT);
    _toastT = setTimeout(function(){ t.style.opacity = 0; }, 1600);
}

function setMode(m) {
    api('/mode?m=' + m);
    d.mode = m; render();
    toast('Modus → ' + m);
}

function setThp(on) {
    api('/thermal?t=' + (on ? 'on' : 'off'));
    d.thermal_protect = on ? 'on' : 'off';
    toast('Thermal-Schutz (Gaming-Deckel) ' + (on ? 'an' : 'aus'));
}

function setGoldCap(on) {
    api('/goldcap?g=' + (on ? 'on' : 'off'));
    d.gold_cap = on ? '1708800' : '0';
    toast('Gold-Cap ' + (on ? 'an (1708800)' : 'aus (2304 max)'));
}

function setProfile(p) {
    api('/profile?p=' + p);
    d.gov_profile_name = p;
    toast('Profil → ' + p);
}

function setDelegated(v) {
    api('/delegated?d=' + v);
    d.delegated = v;
    toast(v === '1' ? 'Delegation aktiviert' : 'Delegation deaktiviert');
}

function applyBattGuard() {
    var v = Number(document.getElementById('battGuardTemp').value);
    if (!Number.isInteger(v) || v < 35 || v > 60) { toast('Akku-Guard 35..60°C'); return; }
    api('/battguard?t=' + v);
    toast('Akku-Guard → ' + v + '°C');
}

function setBattGuardEn(v) {
    api('/battguard?e=' + (v ? '1' : '0'));
    toast(v ? 'Akku-Guard an' : 'Akku-Guard aus');
}

function parseBwFloors() {
    var r = {gpubw: [0,0,0], llcc: [0,0,0]};
    if (d.gov_bw_gpubw) {
        var parts = d.gov_bw_gpubw.replace(/^gpubw\s+/, '').trim().split(/\s+/);
        r.gpubw = parts.map(Number);
    }
    if (d.gov_bw_llcc) {
        var parts2 = d.gov_bw_llcc.replace(/^llcc\s+/, '').trim().split(/\s+/);
        r.llcc = parts2.map(Number);
    }
    return r;
}

function applyBwFloors() {
    var g = [], l = [];
    for (var i = 0; i < 3; i++) {
        var na = Number(document.getElementById('bw_gpubw_' + i).value);
        var nb = Number(document.getElementById('bw_llcc_' + i).value);
        if (!Number.isInteger(na) || na < 0 || na > 20000) { toast('GPU-BW L' + (i+2) + ' 0..20000'); return; }
        if (!Number.isInteger(nb) || nb < 0 || nb > 20000) { toast('LLCC L' + (i+2) + ' 0..20000'); return; }
        g.push(String(na));
        l.push(String(nb));
    }
    var path = '/bw_floors?bw=' + g.concat(l).join('_');
    new Image().src = 'http://127.0.0.1:8767' + path + '&t=' + Date.now();
    toast('BW-Floors gesendet');
    setTimeout(fetchData, 800);
}

function resetBwFloors() {
    var dg = [4000, 3000, 1500], dl = [0, 4000, 3000];
    for (var i = 0; i < 3; i++) {
        document.getElementById('bw_gpubw_' + i).value = dg[i];
        document.getElementById('bw_llcc_' + i).value = dl[i];
    }
    toast('BW-Floors auf gaming-Profil zurückgesetzt');
}

function parseHist(raw) {
    if (!raw) return [];
    var entries = raw.split(',');
    var result = [];
    for (var i = entries.length - 1; i >= 0 && result.length < 15; i--) {
        var parts = entries[i].split(':');
        if (parts.length === 3) {
            var ts = new Date(parseInt(parts[0]) * 1000);
            result.push({
                time: ts.toLocaleTimeString(),
                temp: parts[1] + '°C',
                trans: parts[2].replace(/>/g, ' → ')
            });
        }
    }
    return result;
}

function fetchData() {
    fetch('data.txt?_=' + Date.now())
        .then(function(r){ return r.text(); })
        .then(function(t){ parse(t); render(); })
        .catch(function(){});
}

function parse(t) {
    d = {};
    t.split('\n').forEach(function(l){
        var i = l.indexOf('=');
        if (i > 0) d[l.slice(0,i)] = l.slice(i+1);
    });
}

function render() {
    var st = (d.state || '--').toUpperCase();
    var pill = document.getElementById('statePill');
    pill.textContent = st;
    pill.className = 'pill ' + (d.state || '');

    document.getElementById('vTemp').textContent = (d.temp || '--') + '°C';
    document.getElementById('vSil').textContent  = (d.cpu_sil_mhz || '--') + ' MHz';
    document.getElementById('vGold').textContent = (d.cpu_gold_mhz || '--') + ' MHz';
    document.getElementById('vGpu').textContent  = (d.gpu_mhz || '--') + ' MHz';
    document.getElementById('vDel').textContent  = d.delegated === '1' ? 'aktiv (in-kernel)' : 'legacy (userspace)';
    document.getElementById('vTick').textContent = d.tick || '--';
    document.getElementById('vBat').textContent  = (d.bat || '--') + ' ' + (d.bat_temp || '');

    document.getElementById('vGovVer').textContent = d.gov_version || '--';
    document.getElementById('vGovState').textContent = (d.gov_state || '--').toUpperCase();
    document.getElementById('vGovThrottle').textContent = d.gov_throttle || '0';
    var hv = document.getElementById('vGovHash');
    if (d.gov_hash_state === '1') { hv.textContent = '✓ verified'; hv.style.color = '#4ade80'; }
    else if (d.gov_hash_state === '2') { hv.textContent = '✗ mismatch'; hv.style.color = '#f87171'; }
    else if (d.gov_hash_state === '3') { hv.textContent = '– nicht geprüft'; hv.style.color = '#fbbf24'; }
    else if (d.gov_hash_state === '0') { hv.textContent = '– pending'; hv.style.color = '#fbbf24'; }
    else {
        hv.textContent = d.gov_hash === '1' ? '✓ verified' : '✗ mismatch';
        hv.style.color = d.gov_hash === '1' ? '#4ade80' : '#f87171';
    }

    var pm = document.getElementById('vGovPolicyMax');
    if (pm) pm.textContent = d.gov_policy_max ? (Math.round(Number(d.gov_policy_max) / 1000) + ' MHz') : '--';

    var sa = document.getElementById('vGovStateAge');
    if (sa) sa.textContent = d.gov_state_age ? (Math.round(Number(d.gov_state_age) / 1000) + ' s') : '--';

    var ts = document.getElementById('vGovTempSrc');
    if (ts) {
        var tsNames = {'0':'—','1':'Gold cpu-1-*','2':'Silver cpu-0-*','3':'xo-therm','4':'soc-therm','5':'thermal_zone0'};
        if (d.gov_temp_valid === '0') { ts.textContent = '✗ keine Quelle (State gehalten)'; ts.style.color = '#f87171'; }
        else { ts.textContent = tsNames[d.gov_temp_src] || '--'; ts.style.color = ''; }
    }

    var bge = document.getElementById('battGuardToggle');
    if (bge && d.gov_batt_guard !== undefined) bge.checked = d.gov_batt_guard === '1';

    var profNames = {'1':'gaming','2':'battery','3':'badazz','5':'badazz_safe'};
    var profName = profNames[d.gov_profile] || d.gov_profile || '--';
    document.getElementById('vGovProfile').textContent = profName;

    document.getElementById('vGpuCaps').textContent = d.gov_gpu_caps || '--';

    var bgi = document.getElementById('battGuardTemp');
    if (bgi && d.gov_batt_temp && document.activeElement !== bgi) bgi.value = d.gov_batt_temp;

    var bw = parseBwFloors();
    for (var i = 0; i < 3; i++) {
        var gi = document.getElementById('bw_gpubw_' + i);
        var li = document.getElementById('bw_llcc_' + i);
        if (gi) gi.value = bw.gpubw[i] || 0;
        if (li) li.value = bw.llcc[i] || 0;
    }

    var histBody = document.getElementById('histBody');
    var hist = parseHist(d.gov_hist);
    if (histBody) {
        histBody.innerHTML = '';
        hist.forEach(function(h) {
            var tr = document.createElement('tr');
            tr.innerHTML = '<td>' + h.time + '</td><td>' + h.temp + '</td><td>' + h.trans + '</td>';
            histBody.appendChild(tr);
        });
    }

    var bg = document.getElementById('btnGaming');
    var bd = document.getElementById('btnDaily');
    bg.classList.toggle('active', d.mode === 'gaming');
    bd.classList.toggle('active', d.mode !== 'gaming');

    var thp = document.getElementById('thpToggle');
    if (d.thermal_protect !== undefined) thp.checked = d.thermal_protect === 'on';
    var gc = document.getElementById('gcToggle');
    if (d.gold_cap !== undefined) gc.checked = d.gold_cap !== '0';
}

setInterval(fetchData, 2000);
fetchData();

/* Cache Schliesszustand der Aufklapp-Kacheln (v1.4.4) */
(function(){
    for (var id of ["dSetup","dStatus","dGov","dBw","dHist"]) {
        var d = document.getElementById(id);
        if (!d) continue;
        var st = null;
        try { st = localStorage.getItem(id); } catch(e) {}
        if (st !== null) d.open = st === "1";
        d.addEventListener("toggle", function(){ try { localStorage.setItem(this.id, this.open ? "1":"0"); } catch(e){} });
    }
})();

/* ── Settings-Panel (v1.4.4) ───────────────────────────────────────────── */
var LS = function(k){ try { return localStorage.getItem('k6a.ui.'+k); } catch(e){ return null; } };
var LSset = function(k,v){ try { localStorage.setItem('k6a.ui.'+k, v); } catch(e){} };
var LSdel = function(k){ try { localStorage.removeItem('k6a.ui.'+k); } catch(e){} };

function applyCardAlpha(a){
    var v = parseInt(a,10); if (isNaN(v)) v = 100;
    if (v < 5) v = 5; if (v > 100) v = 100;
    var cs = getComputedStyle(document.body);
    var hex = (cs.getPropertyValue('--card')||'#141d2b').trim().replace('#','');
    if (/^[0-9a-fA-F]{3}$/.test(hex)) hex = hex[0]+hex[0]+hex[1]+hex[1]+hex[2]+hex[2];
    if (!/^[0-9a-fA-F]{6}$/.test(hex)) hex = '141d2b';
    var r = parseInt(hex.substr(0,2),16), g = parseInt(hex.substr(2,2),16), b = parseInt(hex.substr(4,2),16);
    var rgb = r+','+g+','+b;
    var sel = document.querySelectorAll('.card');
    for (var i=0;i<sel.length;i++){
        sel[i].style.backgroundColor = 'rgba('+rgb+','+(v/100)+')';
        var bc = (cs.getPropertyValue('--border')||'#1a2332').trim().replace('#','');
        if (/^[0-9a-fA-F]{3}$/.test(bc)) bc = bc[0]+bc[0]+bc[1]+bc[1]+bc[2]+bc[2];
        if (/^[0-9a-fA-F]{6}$/.test(bc)) {
            var r2=parseInt(bc.substr(0,2),16), g2=parseInt(bc.substr(2,2),16), b2=parseInt(bc.substr(4,2),16);
            sel[i].style.borderColor = 'rgba('+r2+','+g2+','+b2+','+Math.min(1,v/100+0.15)+')';
        }
    }
}

function setTheme(th){
    if (th) document.body.setAttribute('data-theme', th); else document.body.removeAttribute('data-theme');
    LSset('theme', th || '');
    var btns = document.querySelectorAll('#themeSwitch .ts-btn');
    for (var i=0;i<btns.length;i++) btns[i].classList.toggle('active', btns[i].getAttribute('data-th') === th);
    var al = LS('bgAlpha'); if (al) applyCardAlpha(al);
}

var IS_WV = /; wv\)/.test(navigator.userAgent);

function isFsEnabled() {
    return !!(document.fullscreenEnabled || document.webkitFullscreenEnabled);
}

function pickBg(){
    var p = document.getElementById('bgPick');
    if (!p) return;
    try { p.click(); }
    catch(e) {}
    if (IS_WV && !p.value) setTimeout(function(){ if (!p.value) toast('WebView: file-chooser evtl. blockiert — nutze URL oder bg.jpg'); }, 1500);
}

function setBgUrl(){
    var inp = document.getElementById('bgUrl');
    var u = inp && inp.value.trim();
    if (!u) return;
    LSdel('bgData');
    document.body.classList.add('has-bg');
    document.body.style.backgroundImage = 'url("' + u + '")';
    LSset('bgUrl', u);
    applyCardAlpha(LS('bgAlpha') || '70');
}

function probeBgJpg(){
    /* webroot/bg.jpg vorhanden? (brlaeuft ohne CORS — background-image laedet roh) */
    if (LS('bgData') || LS('bgUrl')) return;
    var img = new Image();
    img.onload = function(){
        document.body.classList.add('has-bg');
        document.body.style.backgroundImage = 'url(bg.jpg)';
    };
    img.src = 'bg.jpg?_=' + Date.now();
}

function setBg(file){
    if (!file) return;
    var fr = new FileReader();
    fr.onload = function(){
        try { LSset('bgData', fr.result); } catch(e){ toast('Bild zu gross fuer Speicherung — nur fuer diese Sitzung'); }
        document.body.classList.add('has-bg');
        document.body.style.backgroundImage = 'url(' + fr.result + ')';
        applyCardAlpha(LS('bgAlpha') || '70');
    };
    fr.readAsDataURL(file);
}

function setBgAlpha(v){
    LSset('bgAlpha', String(v));
    applyCardAlpha(v);
}

function resetSettings(){
    LSdel('bgData'); LSdel('bgAlpha'); LSdel('theme');
    document.body.classList.remove('has-bg');
    document.body.style.backgroundImage = '';
    document.body.style.removeProperty('--card');
    document.body.removeAttribute('data-theme');
    var btns = document.querySelectorAll('#themeSwitch .ts-btn');
    for (var i=0;i<btns.length;i++) btns[i].classList.remove('active');
    var al = document.getElementById('bgAlpha'); if (al) al.value = '100';
    toast('Settings zurueckgesetzt');
}

function checkUpdates(){
    var v = document.getElementById('vUpd');
    v.textContent = '...';
    fetch('https://raw.githubusercontent.com/vandalsquad187/k6a-ctl/main/module.prop?_=' + Date.now())
        .then(function(r){ return r.text(); })
        .then(function(t){
            var m = /version=([0-9.]+)/.exec(t);
            var remote = m ? m[1] : null;
            var local = (typeof d !== 'undefined' && d.modver) ? d.modver : null;
            if (!local) { v.textContent = 'unbekannt'; return; }
            if (remote === local) { v.textContent = 'aktuell v' + local; v.style.color = '#4ade80'; }
            else { v.textContent = 'neu v' + remote + ' (lokal v' + local + ')'; v.style.color = '#fbbf24'; }
        })
        .catch(function(){ v.textContent = 'offline'; });
}

function toggleFs(){
    var el = document.documentElement;
    var vf = document.getElementById('vFs');
    var rs = el.requestFullscreen || el.webkitRequestFullscreen || el.mozRequestFullScreen;
    if (!rs || !isFsEnabled()) {
        if (IS_WV) {
            bodyFsMode();
            toast('WebView: echtes Vollbild nicht moeglich — CSS-Modus aktiv');
            if (vf) vf.textContent = 'pseudo';
        } else {
            if (vf) vf.textContent = 'n/a';
            toast('Fullscreen nicht unterstuetzt');
        }
        return;
    }
    if (!document.fullscreenElement) {
        try {
            var p = rs.call(el);
            if (p && p.then) p.then(function(){ if (vf) vf.textContent='an'; })
                .catch(function(){ if (vf) vf.textContent='blockiert'; toast('Fullscreen vom Browser blockiert'); });
            else if (vf) vf.textContent = 'an';
        } catch(e) { if (vf) vf.textContent='blockiert'; toast('Fullscreen blockiert'); }
    } else {
        var ex = document.exitFullscreen || document.webkitExitFullscreen;
        try { ex && ex.call(document); } catch(e){}
        if (vf) vf.textContent = 'aus';
    }
}

function bodyFsMode(){
    var b = document.body;
    if (b.classList.contains('fs-mode')) {
        b.classList.remove('fs-mode');
        var vf2 = document.getElementById('vFs');
        if (vf2) vf2.textContent = 'aus';
        return;
    }
    b.classList.add('fs-mode');
}

function openSettings(){
    var p = document.getElementById('settingsPanel');
    p.hidden = false; p.classList.add('open');
}
function closeSettings(){
    var p = document.getElementById('settingsPanel');
    p.hidden = true; p.classList.remove('open');
}

function panelToast(){
    var t = document.getElementById('toast');
    t.style.opacity = 1;
    setTimeout(function(){ t.style.opacity = 0; }, 1600);
}

/* Theme + Hintergrund beim Start wiederherstellen (v1.4.4) */
(function(){
    var th = LS('theme');
    if (th) setTheme(th);
    var bd = LS('bgData');
    if (bd) {
        document.body.classList.add('has-bg');
        document.body.style.backgroundImage = 'url(' + bd + ')';
    } else {
        var bu = LS('bgUrl');
        if (bu) {
            document.body.classList.add('has-bg');
            document.body.style.backgroundImage = 'url("' + bu + '")';
        } else {
            probeBgJpg();
        }
    }
    var al = LS('bgAlpha') || (bd || bu ? '70' : '100');
    var alEl = document.getElementById('bgAlpha');
    if (alEl) alEl.value = al;
    applyCardAlpha(al);
})();

document.addEventListener('fullscreenchange', function(){
    var vf = document.getElementById('vFs');
    if (vf) vf.textContent = document.fullscreenElement ? 'an' : 'aus';
});
document.addEventListener('webkitfullscreenchange', function(){
    var vf = document.getElementById('vFs');
    if (vf) vf.textContent = document.webkitFullscreenElement ? 'an' : 'aus';
});
