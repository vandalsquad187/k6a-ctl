// k6a-ctl app.js v1.1.0
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
    var MP = '/data/adb/modules/k6a-ctl';
    var m;
    if ((m = path.match(/^\/mode\?m=(\w+)$/)))
        ksuExec("sed -i 's|^mode=.*|mode=" + m[1] + "|' " + MP + "/config/settings.conf");
    else if ((m = path.match(/^\/thermal\?t=(\w+)$/)))
        ksuExec("sed -i 's|^thermal_protect=.*|thermal_protect=" + m[1] + "|' " + MP + "/config/settings.conf");
    else if ((m = path.match(/^\/profile\?p=(\w+)$/)))
        ksuExec("sed -i 's|^profile=.*|profile=" + m[1] + "|' " + MP + "/config/settings.conf");
    else if ((m = path.match(/^\/delegated\?d=(\d)$/)))
        ksuExec("sed -i 's|^delegated=.*|delegated=" + m[1] + "|' " + MP + "/config/settings.conf");
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
    toast('Thermal-Schutz ' + (on ? 'an' : 'aus'));
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
    var vals = [];
    for (var i = 0; i < 3; i++) {
        vals.push(document.getElementById('bw_gpubw_' + i).value || '0');
        vals.push(document.getElementById('bw_llcc_' + i).value || '0');
    }
    var cmd = "echo '" + vals.join(' ') + "' > /sys/kernel/k6a_gov/bw_floors";
    ksuExec(cmd);
    toast('BW-Floors angewendet');
    setTimeout(fetchData, 500);
}

function resetBwFloors() {
    var defaults = [2000, 0, 1500, 4000, 1000, 3000];
    for (var i = 0; i < 3; i++) {
        document.getElementById('bw_gpubw_' + i).value = defaults[i*2];
        document.getElementById('bw_llcc_' + i).value = defaults[i*2+1];
    }
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
    hv.textContent = d.gov_hash === '1' ? '✓ verified' : '✗ mismatch';
    hv.style.color = d.gov_hash === '1' ? '#4ade80' : '#f87171';

    var profNames = {'1':'gaming','2':'battery','3':'badazz','5':'badazz_safe'};
    var profName = profNames[d.gov_profile] || d.gov_profile || '--';
    document.getElementById('vGovProfile').textContent = profName;

    document.getElementById('vGpuCaps').textContent = d.gov_gpu_caps || '--';

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
}

setInterval(fetchData, 2000);
fetchData();
