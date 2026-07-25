// KukKeep Web Clipper — saves the current tab (title + selection + URL) to
// KukKeep via the shared backend's tRPC-over-HTTP API. Auth rides the existing
// `.kuklabs.com` session cookie (credentials: 'include'); host_permissions in
// the manifest let the extension call keep.kuklabs.com cross-origin without CORS.
// The contract mirrors lib/api.dart: batch envelope {"0":{"json": <input>}},
// result at [0].result.data.json, errors at [0].error.json.message.

const BASE = "https://keep.kuklabs.com";

async function unwrap(res) {
  if (res.status === 401) throw new Error("Please log in at keep.kuklabs.com first, then try again.");
  let body;
  try { body = await res.json(); } catch { throw new Error(`Server unavailable (${res.status}).`); }
  const entry = Array.isArray(body) ? body[0] : body;
  if (entry && entry.error) {
    throw new Error(entry.error?.json?.message || entry.error?.message || "Request failed.");
  }
  return entry && entry.result && entry.result.data ? entry.result.data.json : undefined;
}

async function trpcQuery(proc, input) {
  const enc = encodeURIComponent(JSON.stringify({ "0": { json: input ?? null } }));
  const res = await fetch(`${BASE}/api/trpc/${proc}?batch=1&input=${enc}`, {
    method: "GET",
    credentials: "include",
  });
  return unwrap(res);
}

async function trpcMutate(proc, input, companyId) {
  const headers = { "content-type": "application/json" };
  if (companyId != null) headers["x-company-id"] = String(companyId);
  const res = await fetch(`${BASE}/api/trpc/${proc}?batch=1`, {
    method: "POST",
    credentials: "include",
    headers,
    body: JSON.stringify({ "0": { json: input } }),
  });
  return unwrap(res);
}

function setStatus(msg, kind) {
  const el = document.getElementById("status");
  el.textContent = msg;
  el.className = "status" + (kind ? " " + kind : "");
}

async function init() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    document.getElementById("title").value = (tab && tab.title) || "";
    let selection = "";
    if (tab && tab.id != null) {
      try {
        const results = await chrome.scripting.executeScript({
          target: { tabId: tab.id },
          func: () => (window.getSelection ? window.getSelection().toString() : ""),
        });
        selection = (results && results[0] && results[0].result) || "";
      } catch (_) { /* some pages (chrome://, PDF viewer) disallow scripting */ }
    }
    const url = (tab && tab.url) || "";
    document.getElementById("body").value = (selection ? selection.trim() + "\n\n" : "") + url;
  } catch (_) { /* leave fields empty */ }
}

async function save() {
  const btn = document.getElementById("save");
  const title = document.getElementById("title").value.trim();
  const body = document.getElementById("body").value.trim();
  if (!title && !body) { setStatus("Add a title or some text first.", "err"); return; }
  btn.disabled = true;
  setStatus("Saving…");
  try {
    // keep.create is company-scoped — resolve the user's first company for the header.
    let companyId = null;
    try {
      const companies = await trpcQuery("company.list", null);
      if (Array.isArray(companies) && companies.length) companyId = companies[0].id;
    } catch (e) {
      // company.list failing with 401 means not logged in — surface that.
      throw e;
    }
    await trpcMutate("keep.create", { title, body, type: "note" }, companyId);
    setStatus("Saved to KukKeep ✓", "ok");
    setTimeout(() => window.close(), 900);
  } catch (e) {
    setStatus(e && e.message ? e.message : "Could not save.", "err");
    btn.disabled = false;
  }
}

document.getElementById("save").addEventListener("click", save);
init();
