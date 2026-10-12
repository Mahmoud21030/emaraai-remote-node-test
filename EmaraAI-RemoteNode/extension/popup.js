const $ = id => document.getElementById(id);
chrome.storage.local.get({hub: "", last: null}, async v => {
  if (!v.hub) { try { const n = await (await fetch(chrome.runtime.getURL("node.json"))).json(); v.hub = String(n.hub || "").replace(/\/$/, ""); } catch (e) {} }
  v.hub = v.hub || "http://127.0.0.1:8797";
  $("hub").value = v.hub;
  $("dash").href = v.hub + "/dashboard";
  fetch(v.hub + "/health").then(r => r.json()).then(j => {
    $("st").innerHTML = '<span class="ok">Connected</span> to hub v' + j.version;
  }).catch(() => { $("st").innerHTML = '<span class="bad">Hub not running</span> at ' + v.hub; });
});
$("hub").addEventListener("change", e => chrome.storage.local.set({hub: e.target.value.replace(/\/$/, "")}, () => chrome.runtime.reload()));
