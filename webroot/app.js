// k6a-ctl app.js v1.0.0
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
    // Transport 1: Image-Beacon an localhost-server
    new Image().src = 'http://127.0.0.1:8767' + path + '&t=' + Date.now();
    // Transport 2: KSU-Bridge als Fallback (Doppelwrite harmlos, gleicher Wert)
    var MP = '/data/adb/modules/k6a-ctl';
    var m;
    if ((m = path.match(/^\/mode\?m=(\w+)$/)))
        ksuExec("sed -i 's|^mode=.*|mode=" + m[1] + "|' " + MP + "/config/settings.conf");
    else if ((m = path.match(/^\/thermal\?t=(\w+)$/)))
        ksuExec("sed -i 's|^thermal_protect=.*|thermal_protect=" + m[1] + "|' " + MP + "/config/settings.conf");
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

    var bg = document.getElementById('btnGaming');
    var bd = document.getElementById('btnDaily');
    bg.classList.toggle('active', d.mode === 'gaming');
    bd.classList.toggle('active', d.mode !== 'gaming');

    var thp = document.getElementById('thpToggle');
    if (d.thermal_protect !== undefined) thp.checked = d.thermal_protect === 'on';
}

setInterval(fetchData, 2000);
fetchData();