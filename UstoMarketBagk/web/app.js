const API = ""; // same origin: /products, /masters, /orders
/** Программа баллов мастеров (временно отключена). */
const MASTER_POINTS_ENABLED = false;
/** QR / штрих-код мастера в профиле (временно отключён). */
const MASTER_BARCODE_ENABLED = false;
function fullUrl(path) {
  if (!path || typeof path !== "string") return "";
  path = path.trim();
  if (path.startsWith("http")) return path;
  return path.startsWith("/") ? path : "/" + path;
}

/** Оптимизированный URL картинки (бэкенд сохраняет WebP в static/images). */
function productImageUrl(path) {
  const url = fullUrl(path);
  if (!url) return "";
  return url;
}

function hasMasterBarcode(me) {
  if (!me || me.barcode == null) return false;
  const s = String(me.barcode).trim();
  if (!s || s === "Обратитесь к администратору") return false;
  return (
    s.startsWith("http") ||
    s.startsWith("/") ||
    s.startsWith("static/") ||
    /\.(webp|png|jpg|jpeg|gif|svg)$/i.test(s)
  );
}

function renderMasterBarcode(me) {
  if (hasMasterBarcode(me)) {
    const src = productImageUrl(me.barcode);
    return `<div class="profile-barcode-placeholder profile-barcode-placeholder--code"><img src="${escapeHtml(src)}" alt="Штрих-код" loading="lazy"></div>`;
  }
  return `<div class="profile-barcode-placeholder">Обратитесь к администратору</div>`;
}

const state = {
  screen: "home",
  products: [],
  recommended: [],
  masters: [],
  loadingProducts: false,
  loadingMasters: false,

  cart: [],
  selectedProductId: null,
  backScreen: "home",

  qHome: "",
  qMaterials: "",
  qProducts: "",
  qMasters: "",
  qHomeDraft: "",
  qMaterialsDraft: "",
  qProductsDraft: "",
  qMastersDraft: "",
  searchCity: "",

  // materials navigation (categories -> subcategories -> items)
  materialsStep: "categories", // categories | subcategories | items
  selectedCategory: null,
  selectedSubcategory: null,

  // masters navigation (categories -> list -> details)
  mastersStep: "categories", // categories | list
  selectedMasterCategory: null,
  selectedMasterId: null,
  masterPhotoIndex: 0,
  masterBackStep: "list",

  checkout: {
    name: "",
    phone: "",
    address: "",
    deliveryType: "delivery", // delivery | pickup
    payment: "cash",          // cash | card
    comment: ""
  },
  checkoutLoading: false,
  checkoutError: "",
  checkoutOk: false,
  lastOrderId: "",

  // вкладка «Стройматериалы»: фильтр категории для популярных товаров
  homeCategoryFilter: "Все",
  // каталог: фильтр бренда/категории
  catalogBrandFilter: "Все",

  // details hero swipe (product)
  detailsPhotoIndex: 0,
  detailsSizeIndex: 0,
  detailsColorIndex: 0,
  detailsCalcLength: 4,
  detailsCalcWidth: 4,

  // lightbox
  lbOpen: false,
  lbIndex: 0,
  lbPhotos: [],

  // cart swipe UI (which item has actions open)
  cartSwipeOpenId: null,

  // профиль: данные с бэкенда
  profileMe: null,
  profileOrders: [],
  profileNotifications: [],
  profileUnreadCount: 0,
  profileLoading: false,
  profileTheme: "light",
  profileLang: "ru",
  profileSection: null,
  addressSheetOpen: false,
  favorites: [],

  searchResults: { home: [], materials: [], products: [] },
  searchLoading: false,
  searchSeq: 0,

  accessToken: null,
  refreshToken: null,
  authStep: "phone",
  authMode: "master",
  authPhone: "",
  authName: "",
  authPassword: "",
  authConfirm: "",
  authLoading: false,
  authError: "",

  chat: {
    sessionId: null,
    messages: [],
    loading: false,
    error: "",
    pick: null,
    checkoutOpen: false,
    orderId: null,
  },

  siteAbout: null,
  siteAboutLoading: false,

  // сметный калькулятор (mobile-first, без клавиатуры)
  calc: {
    length: 4.0,
    width: 4.0,
    height: 3.0,
    doors: 1,    // минимум 1 дверь в комнате
    windows: 1,  // минимум 1 окно в комнате
    productId: null,
    serviceId: null, // null = только материалы, без работы мастера
  },
};

/** Площадь стандартных проёмов (м²), как в API estimate-room. */
const CALC_DOOR_AREA_M2 = 1.6;
const CALC_WINDOW_AREA_M2 = 2.25;

/** Технические нормы расхода для калькулятора (по id товара или по ключу категории). */
const PRODUCT_CALC_OVERRIDES = {
  // пример из ТЗ — подхватится, если id совпадёт
  mashad_super: { consumption: 0.3, packaging: 3, laborPrice: 15, unitType: "вед.", kind: "enamel" },
};

/** Услуги мастеров в Таджикистане: ставка за 1 м² стен. */
const CALC_SERVICES = [
  {
    id: "painting",
    name: "Покраска стен",
    pricePerM2: 15,
    kinds: ["paint", "emulsion"],
    hint: "Окраска стен эмульсией / краской",
  },
  {
    id: "enamel",
    name: "Покраска эмалью",
    pricePerM2: 18,
    kinds: ["enamel"],
    hint: "Эмаль по металлу / дереву",
  },
  {
    id: "plastering",
    name: "Штукатурка",
    pricePerM2: 25,
    kinds: ["plaster", "putty"],
    hint: "Выравнивание стен штукатуркой",
  },
  {
    id: "puttying",
    name: "Шпатлёвка",
    pricePerM2: 12,
    kinds: ["putty"],
    hint: "Финишная / стартовая шпатлёвка",
  },
  {
    id: "priming",
    name: "Грунтовка",
    pricePerM2: 8,
    kinds: ["primer"],
    hint: "Грунт перед покраской или шпатлёвкой",
  },
  {
    id: "ceiling",
    name: "Покраска потолка",
    pricePerM2: 12,
    kinds: ["paint", "emulsion"],
    hint: "Окраска потолка",
    areaMode: "ceiling",
  },
];

const CALC_ROOM_PRESETS = [
  { label: "3×3", length: 3, width: 3 },
  { label: "3×4", length: 3, width: 4 },
  { label: "4×4", length: 4, width: 4 },
  { label: "4×5", length: 4, width: 5 },
  { label: "4×6", length: 4, width: 6 },
];

const LS_CART = "gm_cart";
const LS_CHECKOUT = "gm_checkout";
const LS_PROFILE_THEME = "gm_profile_theme";
const LS_PROFILE_LANG = "gm_profile_lang";
const LS_FAV = "gm_fav";
const LS_AUTH_KIND = "gm_auth_kind";
const LS_ACCESS = "gm_access_token";
const LS_REFRESH = "gm_refresh_token";
const LS_MASTER = "gm_master_cache";

let searchDebounceTimer = null;

function searchDraftValue() {
  if (state.screen === "home") return state.qHomeDraft;
  if (state.screen === "materials") return state.qMaterialsDraft;
  if (state.screen === "products") return state.qProductsDraft;
  return state.qMastersDraft;
}

function setSearchDraftValue(v) {
  if (state.screen === "home") state.qHomeDraft = v;
  else if (state.screen === "materials") state.qMaterialsDraft = v;
  else if (state.screen === "products") state.qProductsDraft = v;
  else state.qMastersDraft = v;
}

function clearSearchForScreen(screen) {
  if (screen === "home") {
    state.qHome = "";
    state.qHomeDraft = "";
  } else if (screen === "materials") {
    state.qMaterials = "";
    state.qMaterialsDraft = "";
    state.searchResults.materials = [];
  } else if (screen === "products") {
    state.qProducts = "";
    state.qProductsDraft = "";
    state.searchResults.products = [];
  } else if (screen === "masters") {
    state.qMasters = "";
    state.qMastersDraft = "";
  }
}

function normalizeCityName(s) {
  return String(s || "")
    .toLowerCase()
    .replace(/^г\.\s*/i, "")
    .replace(/\s+/g, " ")
    .trim();
}

function getMasterCities() {
  var set = {};
  (state.masters || []).forEach(function (m) {
    var c = (m.city || "").trim();
    if (c) set[c] = true;
  });
  return Object.keys(set).sort(function (a, b) {
    return a.localeCompare(b, "ru");
  });
}

function masterMatchesCity(m, cityFilter) {
  var f = (cityFilter || "").trim();
  if (!f) return true;
  var c = (m.city || "").trim();
  if (!c) return false;
  var nf = normalizeCityName(f);
  var nc = normalizeCityName(c);
  return nc === nf || nc.indexOf(nf) !== -1 || nf.indexOf(nc) !== -1;
}

function applySearchQuery(opts) {
  opts = opts || {};
  const keepFocus = !!opts.keepFocus;
  const inp = document.querySelector('input[data-act="q"]');
  const raw = inp ? inp.value : searchDraftValue();
  const v = (raw || "").trim();
  const selStart = inp && typeof inp.selectionStart === "number" ? inp.selectionStart : null;
  setSearchDraftValue(raw || "");

  if (state.screen === "home") {
    state.qHome = v;
    state.qMasters = v;
    state.qMastersDraft = raw || "";
    render();
  } else if (state.screen === "materials") {
    state.qMaterials = v;
    if (v.length >= 2) fetchProductSearch(v, "materials");
    else {
      state.searchResults.materials = [];
      render();
    }
  } else if (state.screen === "products") {
    state.qProducts = v;
    if (v.length >= 2) fetchProductSearch(v, "products");
    else {
      state.searchResults.products = [];
      render();
    }
  } else if (state.screen === "masters") {
    state.qMasters = v;
    state.qHome = v;
    state.qHomeDraft = raw || "";
    render();
  } else {
    render();
  }

  if (keepFocus) {
    requestAnimationFrame(function () {
      var again = document.querySelector('input[data-act="q"]');
      if (!again) return;
      again.focus();
      try {
        if (selStart != null) again.setSelectionRange(selStart, selStart);
      } catch (_) {}
    });
  } else if (inp) {
    try { inp.blur(); } catch (_) {}
  }
}

function syncSearchClearButton(inputEl) {
  if (!inputEl) return;
  const wrap = inputEl.closest(".search");
  if (!wrap) return;
  const btn = wrap.querySelector('[data-act="q-clear"]');
  if (btn) btn.classList.toggle("hidden", !(inputEl.value || "").trim());
}

function loadFav() {
  try {
    const raw = localStorage.getItem(LS_FAV);
    if (raw) state.favorites = JSON.parse(raw);
  } catch (_) {}
}
function saveFav() {
  try { localStorage.setItem(LS_FAV, JSON.stringify(state.favorites || [])); } catch (_) {}
}
function isFav(id) {
  return (state.favorites || []).indexOf(String(id)) !== -1;
}
function toggleFav(id) {
  const sid = String(id);
  if (!state.favorites) state.favorites = [];
  const i = state.favorites.indexOf(sid);
  if (i === -1) state.favorites.push(sid);
  else state.favorites.splice(i, 1);
  saveFav();
}

function loadCart() {
  try {
    const raw = localStorage.getItem(LS_CART);
    if (raw) {
      state.cart = JSON.parse(raw).map(function (it) {
        if (!it.cartKey) it.cartKey = makeCartKey(it.productId, it.name || "item");
        return it;
      });
    }
  } catch (_) {}
}
function saveCart() {
  try { localStorage.setItem(LS_CART, JSON.stringify(state.cart)); } catch (_) {}
}

function loadCheckout() {
  try {
    const raw = localStorage.getItem(LS_CHECKOUT);
    if (raw) state.checkout = { ...state.checkout, ...JSON.parse(raw) };
  } catch (_) {}
  try {
    const t = localStorage.getItem(LS_PROFILE_THEME);
    if (t) state.profileTheme = (t === "default" ? "light" : t);
  } catch (_) {}
  try {
    const l = localStorage.getItem(LS_PROFILE_LANG);
    if (l) state.profileLang = l;
  } catch (_) {}
}
function saveCheckout() {
  try { localStorage.setItem(LS_CHECKOUT, JSON.stringify(state.checkout)); } catch (_) {}
}

function loadAuth() {
  try {
    state.accessToken = localStorage.getItem(LS_ACCESS) || null;
    state.refreshToken = localStorage.getItem(LS_REFRESH) || null;
    const raw = localStorage.getItem(LS_MASTER);
    if (raw) state.profileMe = JSON.parse(raw);
    const kind = localStorage.getItem(LS_AUTH_KIND);
    if (kind && state.profileMe) state.profileMe.kind = kind;
  } catch (_) {}
}

function saveAuth(me, access, refresh) {
  state.accessToken = access || state.accessToken;
  state.refreshToken = refresh || state.refreshToken;
  if (me) state.profileMe = me;
  try {
    if (state.accessToken) localStorage.setItem(LS_ACCESS, state.accessToken);
    if (state.refreshToken) localStorage.setItem(LS_REFRESH, state.refreshToken);
    if (me) {
      localStorage.setItem(LS_MASTER, JSON.stringify(me));
      if (me.kind || me.user_kind) localStorage.setItem(LS_AUTH_KIND, me.kind || me.user_kind);
    }
  } catch (_) {}
}

function clearAuth() {
  state.accessToken = null;
  state.refreshToken = null;
  state.profileMe = null;
  state.profileOrders = [];
  state.profileNotifications = [];
  state.profileUnreadCount = 0;
  try {
    localStorage.removeItem(LS_ACCESS);
    localStorage.removeItem(LS_REFRESH);
    localStorage.removeItem(LS_MASTER);
    localStorage.removeItem(LS_AUTH_KIND);
  } catch (_) {}
}

function authHeaders(extra) {
  const h = Object.assign({}, extra || {});
  if (state.accessToken) h.Authorization = "Bearer " + state.accessToken;
  return h;
}

function isLoggedIn() {
  return !!(state.accessToken && state.profileMe);
}

function isClientUser() {
  return !!(state.profileMe && (state.profileMe.kind === "client" || state.profileMe.user_kind === "client"));
}

function isMasterUser() {
  return !!(state.profileMe && state.profileMe.master_id != null && !isClientUser());
}

function authApiPrefix() {
  return state.authMode === "client" ? "/auth/client" : "/auth";
}

async function apiPostJson(path, body, useAuth) {
  const opts = {
    method: "POST",
    headers: Object.assign({ "Content-Type": "application/json" }, useAuth ? authHeaders() : {}),
    body: JSON.stringify(body || {}),
  };
  const r = await fetch(API + path, opts);
  let data = null;
  try { data = await r.json(); } catch (_) {}
  if (!r.ok) {
    const msg = (data && (data.detail || data.message || data.error)) || ("HTTP " + r.status);
    throw new Error(typeof msg === "string" ? msg : JSON.stringify(msg));
  }
  return data;
}

async function authFetch(path, opts) {
  opts = opts || {};
  opts.headers = authHeaders(opts.headers || {});
  let r = await fetch(API + path, opts);
  if (r.status === 401 && state.refreshToken) {
    try {
      const refreshPath = isClientUser() ? "/auth/client/refresh" : "/auth/refresh";
      const ref = await apiPostJson(refreshPath, { refresh_token: state.refreshToken }, false);
      if (ref && ref.access_token) {
        saveAuth(state.profileMe, ref.access_token, ref.refresh_token || state.refreshToken);
        opts.headers = authHeaders(opts.headers || {});
        r = await fetch(API + path, opts);
      }
    } catch (_) {
      clearAuth();
    }
  }
  return r;
}

function normalizeAuthPhoneInput(raw) {
  const digits = String(raw || "").replace(/\D/g, "");
  if (digits.length >= 9) return "+992" + digits.slice(-9);
  if (digits.length) return "+992" + digits;
  return "";
}

function applyLoginResponse(body) {
  const isClient = body.user_kind === "client" || body.client_id != null;
  const me = isClient ? {
    kind: "client",
    user_kind: "client",
    client_id: body.client_id,
    name: body.name || "",
    phone: body.phone,
  } : {
    kind: "master",
    user_kind: "master",
    master_id: body.master_id,
    name: body.name,
    phone: body.phone,
    points: body.points,
    master_code: body.master_code,
    barcode: body.master_code,
    debt: body.debt || 0,
    support_whatsapp: body.support_whatsapp || "992872148008",
  };
  saveAuth(me, body.access_token, body.refresh_token);
  const digits = String(body.phone || "").replace(/\D/g, "").slice(-9);
  if (digits) {
    state.checkout.phone = digits;
    saveCheckout();
  }
}

async function scheduleProductSearch(q, screen) {
  fetchProductSearch((q || "").trim(), screen);
}

async function fetchProductSearch(q, screen) {
  const key = screen === "products" ? "products" : "materials";
  const seq = ++state.searchSeq;
  state.searchLoading = true;
  render();
  try {
    let url = API + "/products/search?q=" + encodeURIComponent(q) + "&limit=48";
    const cat = screen === "materials" ? state.homeCategoryFilter : state.selectedCategory;
    if (cat && cat !== "Все" && cat !== "All") {
      url += "&category=" + encodeURIComponent(cat);
    }
    const r = await fetch(url);
    if (seq !== state.searchSeq) return;
    state.searchResults[key] = r.ok ? ((await r.json()) || []) : [];
  } catch (e) {
    if (seq === state.searchSeq) state.searchResults[key] = [];
  } finally {
    if (seq === state.searchSeq) {
      state.searchLoading = false;
      render();
    }
  }
}

function getMaterialsTabProductList() {
  const q = (state.qMaterials || "").trim();
  const catFilter = state.homeCategoryFilter || "Все";
  if (q.length >= 2) {
    let list = state.searchResults.materials || [];
    if (catFilter !== "Все") {
      list = list.filter(function (p) { return (p.category || "").trim() === catFilter; });
    }
    return list;
  }
  const recommended = state.recommended || [];
  const allProducts = (state.products || []).concat(recommended);
  var seen = {};
  var popularPool = allProducts.filter(function (p) {
    if (seen[p.id]) return false;
    seen[p.id] = true;
    return true;
  });
  if (catFilter !== "Все") {
    popularPool = popularPool.filter(function (p) { return (p.category || "").trim() === catFilter; });
  }
  return popularPool;
}

function getMaterialsProductList() {
  const q = (state.qProducts || "").trim();
  if (q.length >= 2 && (state.materialsStep === "items" || state.materialsStep === "categories")) {
    return state.searchResults.products || [];
  }
  const cat = state.selectedCategory || "";
  const sub = state.selectedSubcategory || "";
  let items = getItems(cat, sub);
  if (q) items = items.filter(function (p) { return productMatches(p, q.toLowerCase()); });
  return items;
}

async function ensureChatSession() {
  if (state.chat.sessionId) return;
  const data = await apiPostJson("/chat/session", {}, false);
  state.chat.sessionId = data.session_id;
  if (!state.chat.messages.length) {
    state.chat.messages.push({ role: "system", type: "text", text: "Здравствуйте! Я помогу собрать заказ по списку материалов." });
    state.chat.messages.push({ role: "system", type: "text", text: "Напишите список, например: «цемент 5 мешков, профиль 20 шт»." });
  }
}

function pushChatMessage(msg) {
  state.chat.messages.push(msg);
}

function handleChatResponse(data) {
  state.chat.pick = null;
  if (data.type === "invoice" && data.draft) {
    pushChatMessage({ role: "system", type: "invoice", draft: data.draft });
  } else if (data.type === "pick") {
    pushChatMessage({ role: "system", type: "pick", prompt: data.prompt, itemIndex: data.item_index, options: data.options || [] });
    state.chat.pick = { prompt: data.prompt, itemIndex: data.item_index, options: data.options || [] };
  } else if (data.message) {
    pushChatMessage({ role: "system", type: "text", text: data.message });
  } else if (data.error) {
    pushChatMessage({ role: "system", type: "text", text: data.error });
  }
}

async function chatSendMessage(text) {
  if (!text || !text.trim() || !state.chat.sessionId) return;
  const trimmed = text.trim();
  pushChatMessage({ role: "user", type: "text", text: trimmed });
  state.chat.loading = true;
  state.chat.error = "";
  render();
  try {
    const data = await apiPostJson("/chat/message", { session_id: state.chat.sessionId, text: trimmed }, false);
    handleChatResponse(data);
  } catch (e) {
    pushChatMessage({ role: "system", type: "text", text: e.message || "Ошибка сервера" });
  } finally {
    state.chat.loading = false;
    render();
  }
}

async function chatPickOption(productId, itemIndex) {
  if (!state.chat.sessionId) return;
  state.chat.loading = true;
  render();
  try {
    const data = await apiPostJson("/chat/pick", {
      session_id: state.chat.sessionId,
      item_index: itemIndex,
      product_id: productId,
    }, false);
    handleChatResponse(data);
  } catch (e) {
    pushChatMessage({ role: "system", type: "text", text: e.message || "Ошибка выбора" });
  } finally {
    state.chat.loading = false;
    render();
  }
}

async function chatAction(action, payload) {
  if (!state.chat.sessionId) return;
  state.chat.loading = true;
  render();
  try {
    const data = await apiPostJson("/chat/action", {
      session_id: state.chat.sessionId,
      action: action,
      payload: payload || {},
    }, false);
    handleChatResponse(data);
  } catch (e) {
    pushChatMessage({ role: "system", type: "text", text: e.message || "Ошибка" });
  } finally {
    state.chat.loading = false;
    render();
  }
}

async function chatSubmitOrder() {
  const c = state.checkout;
  const name = (c.name || "").trim();
  const phone = normalizePhone(c.phone);
  const address = (c.address || "").trim();
  if (!name) { state.checkoutError = "Введите имя"; render(); return; }
  if (!phone || phone.length < 8) { state.checkoutError = "Введите телефон"; render(); return; }
  if (c.deliveryType === "delivery" && !address) { state.checkoutError = "Введите адрес"; render(); return; }
  state.chat.loading = true;
  state.checkoutError = "";
  render();
  try {
    const data = await apiPostJson("/chat/submit", {
      session_id: state.chat.sessionId,
      client_name: name,
      client_phone: phone,
      client_address: c.deliveryType === "delivery" ? address : "",
      payment_type: c.payment === "card" ? "card" : "cash",
      comment: (c.comment || "").trim() || null,
    }, false);
    if (data.error) throw new Error(data.error);
    state.chat.orderId = data.order_id || data.id;
    state.chat.checkoutOpen = false;
    pushChatMessage({ role: "system", type: "text", text: "Заказ №" + state.chat.orderId + " оформлен! Мы свяжемся с вами." });
    state.chat.sessionId = null;
    state.chat.messages = [];
  } catch (e) {
    state.checkoutError = e.message || "Не удалось оформить заказ";
  } finally {
    state.chat.loading = false;
    render();
  }
}

function escapeHtml(str) {
  var s = String(str || "");
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
function normalizeSocialUrl(raw) {
  var value = String(raw || "").trim();
  if (!value) return "";
  if (value.indexOf("://") === -1) value = "https://" + value;
  return value;
}
function formatPrice(v) {
  const n = Number(v || 0);
  return n.toLocaleString("ru-RU", { maximumFractionDigits: 0 });
}
function formatPriceSmn(v) {
  return formatPrice(v) + " смн";
}
function normalizePhone(p) {
  return String(p || "").replace(/[^\d+]/g, "").trim();
}
function productMatches(p, q) {
  const hay = `${p.name || ""} ${p.category || ""} ${p.subcategory || ""}`.toLowerCase();
  return hay.includes(q);
}
function masterMatches(m, q) {
  q = String(q || "").toLowerCase().trim();
  if (!q) return true;
  const services = (m.services || [])
    .map(function (s) { return (s && s.name) || ""; })
    .join(" ");
  const cats = Array.isArray(m.categories)
    ? m.categories.join(" ")
    : String(m.categories || "");
  const hay = [
    m.name || "",
    m.category || "",
    cats,
    m.description || "",
    m.city || "",
    m.phone || "",
    services,
  ]
    .join(" ")
    .toLowerCase();
  return hay.indexOf(q) !== -1;
}

function uniq(arr) {
  return Array.from(new Set(arr.filter(Boolean)));
}

function getProductById(id) {
  var n = parseInt(id, 10);
  var p = state.products.find(function (x) { return x.id === n || x.id == id; });
  if (p) return p;
  return state.recommended && state.recommended.find(function (x) { return x.id === n || x.id == id; });
}

function productSizes(p) {
  return Array.isArray(p && p.sizes) ? p.sizes : [];
}
function productColors(p) {
  return Array.isArray(p && p.colors) ? p.colors : [];
}
function hasProductVariants(p) {
  return productSizes(p).length > 0 || productColors(p).length > 0;
}
function colorHex(c) {
  var h = (c && (c.hex || c.value || c.code)) || "#cccccc";
  h = String(h).trim();
  if (h.charAt(0) !== "#") h = "#" + h;
  return h;
}
function isLightColor(hex) {
  hex = String(hex || "").replace("#", "");
  if (hex.length === 3) hex = hex.split("").map(function (c) { return c + c; }).join("");
  if (hex.length < 6) return true;
  var r = parseInt(hex.slice(0, 2), 16);
  var g = parseInt(hex.slice(2, 4), 16);
  var b = parseInt(hex.slice(4, 6), 16);
  if (isNaN(r) || isNaN(g) || isNaN(b)) return true;
  return (r * 299 + g * 587 + b * 114) / 1000 > 180;
}
function buildVariantName(baseName, size, color) {
  var parts = [];
  if (size && size.name) parts.push(size.name);
  if (color && color.name) parts.push(color.name);
  if (!parts.length) return baseName;
  return baseName + " (" + parts.join(", ") + ")";
}
function makeCartKey(productId, name) {
  return String(productId) + "_" + name;
}
function getVariantSelection(p, sizeIndex, colorIndex) {
  var sizes = productSizes(p);
  var colors = productColors(p);
  var size = sizes.length ? sizes[Math.max(0, Math.min(sizeIndex, sizes.length - 1))] : null;
  var color = colors.length ? colors[Math.max(0, Math.min(colorIndex, colors.length - 1))] : null;
  var price = size ? Number(size.price) : Number(p.price) || 0;
  var name = buildVariantName(p.name, size, color);
  return {
    size: size,
    color: color,
    price: price,
    name: name,
    cartKey: makeCartKey(p.id, name),
  };
}
function getDetailVariantSelection(p) {
  return getVariantSelection(p, state.detailsSizeIndex, state.detailsColorIndex);
}
function getDefaultVariantSelection(p) {
  return getVariantSelection(p, 0, 0);
}
function findCartItem(cartKey) {
  return state.cart.find(function (c) { return c.cartKey === cartKey; });
}
function cartItemKey(it) {
  return it.cartKey || makeCartKey(it.productId, it.name || "item");
}

/* ===== PRODUCTS (materials) ===== */
function getCategories() {
  return uniq(state.products.map(p => (p.category || "").trim()).filter(x => x));
}
function getSubcategories(category) {
  return uniq(
    state.products
      .filter(p => (p.category || "").trim() === category)
      .map(p => (p.subcategory || "").trim())
      .filter(x => x)
  );
}
function getItems(category, subcategory) {
  return state.products.filter(p =>
    (p.category || "").trim() === category &&
    (p.subcategory || "").trim() === subcategory
  );
}

/* ===== CART ===== */
function cartCount() {
  return state.cart.reduce((s, it) => s + (it.qty || 0), 0);
}
function cartTotal() {
  return state.cart.reduce((s, it) => s + (Number(it.price || 0) * Number(it.qty || 0)), 0);
}

/* ===== MASTERS HELPERS ===== */
function normalizeCategories(cat) {
  // поддержим: строка "электрик" / массив ["электрик","сантехник"] / "электрик, сантехник"
  if (!cat) return [];
  if (Array.isArray(cat)) return cat.map(x => String(x).trim()).filter(Boolean);
  const s = String(cat).trim();
  if (!s) return [];
  if (s.includes(",")) return s.split(",").map(x => x.trim()).filter(Boolean);
  return [s];
}

function getMasterCategoriesList(m) {
  // unified categories: m.categories or m.category
  const cats = normalizeCategories(m.categories);
  if (cats.length) return cats;
  return normalizeCategories(m.category);
}

/** ID из data-id приходит строкой; в API id — число. */
function normalizeMasterId(id) {
  if (id == null || id === "") return null;
  const n = parseInt(String(id), 10);
  return Number.isFinite(n) ? n : id;
}

function getMasterById(id) {
  const want = normalizeMasterId(id);
  if (want == null) return null;
  return state.masters.find(function (x) {
    return normalizeMasterId(x.id) === want || String(x.id) === String(want);
  }) || null;
}

function getAllMasterCategories() {
  const all = [];
  for (const m of state.masters) {
    const cats = getMasterCategoriesList(m);
    for (const c of cats) all.push(c);
  }
  const uniqCats = uniq(all.map(x => String(x).trim()).filter(Boolean));
  return ["Все мастера", ...uniqCats];
}

function masterHasCategory(m, cat) {
  if (!cat || cat === "Все мастера" || cat === "ВСЕ МАСТЕРА") return true;
  const cats = getMasterCategoriesList(m).map(x => x.toLowerCase());
  return cats.includes(String(cat).toLowerCase());
}

function getMasterAvatar(m) {
  return (m.avatar || m.photo || (m.photos && m.photos[0]) || "").trim();
}

function getMasterWorks(m) {
  const a = Array.isArray(m.work_photos) ? m.work_photos : null;
  const b = Array.isArray(m.works) ? m.works : null;
  const c = Array.isArray(m.workPhotos) ? m.workPhotos : null;

  let arr = a || b || c || [];
  arr = arr.map(x => String(x || "").trim()).filter(Boolean);

  // если раньше m.photos использовалось как общий массив:
  if (!arr.length && Array.isArray(m.photos) && m.photos.length > 1) {
    arr = m.photos.slice(1).map(x => String(x || "").trim()).filter(Boolean);
  }
  return arr;
}

function getMasterServices(m) {
  // ожидаем: services: [{name, price}]
  // поддержим варианты: price_list, prices, services_list
  const candidates = [
    m.services,
    m.price_list,
    m.prices,
    m.services_list,
  ];

  let list = null;
  for (const c of candidates) {
    if (Array.isArray(c)) { list = c; break; }
  }
  if (!list) return [];

  return list
    .map(x => {
      if (!x) return null;
      if (typeof x === "string") return { name: x, price: null };
      const name = (x.name ?? x.title ?? x.service ?? "").toString().trim();
      const price = (x.price ?? x.cost ?? x.amount);
      if (!name) return null;
      return { name, price: price == null ? null : Number(price) };
    })
    .filter(Boolean);
}

/* ===== NAV RESETS ===== */
function resetMaterialsToRoot() {
  state.materialsStep = "categories";
  state.selectedCategory = null;
  state.selectedSubcategory = null;
}
function resetMastersToRoot() {
  state.mastersStep = "categories";
  state.selectedMasterCategory = null;
  state.selectedMasterId = null;
  state.masterPhotoIndex = 0;
}

/* ===== ROUTING ===== */
function setScreen(screen) {
  var prev = state.screen;
  state.screen = screen;
  if (screen === "checkout") state.backScreen = "cart";
  else if (screen === "chat_order") state.backScreen = prev === "chat_order" ? "home" : prev;
  else if (screen === "master_auth" || screen === "client_auth") state.backScreen = prev === "publish" ? "publish" : "profile";
  else if (screen === "cart") state.backScreen = prev;
  else if (screen === "orders" || screen === "notifications" || screen === "about") state.backScreen = "profile";
  else if (screen === "calculator") state.backScreen = prev === "calculator" ? "materials" : prev;
  if (screen === "profile" || screen === "orders" || screen === "notifications") fetchProfileData();
  if (screen === "calculator") fetchProductsOnce();
  if (screen === "profile" && isDesktopLayout() && !state.profileSection) {
    state.profileSection = "orders";
  }
  if (screen === "chat_order") {
    ensureChatSession().catch(function (e) {
      state.chat.error = e.message || "Не удалось начать чат";
      render();
    });
  }
  if (screen === "about") fetchSiteAbout();

  if (screen === "products") {
    resetMaterialsToRoot();
  }
  if (screen === "masters") {
    resetMastersToRoot();
  }
  if (screen === "cart") {
    state.cartSwipeOpenId = null;
  }

  render();

  if (screen === "materials" || screen === "products" || screen === "details" || screen === "calculator") fetchProductsOnce();
  if (screen === "home" || screen === "masters" || screen === "master_details") fetchMastersOnce();
}

function openDetails(productId, fromScreen) {
  state.selectedProductId = productId;
  state.backScreen = fromScreen || "materials";
  state.detailsPhotoIndex = 0;
  state.detailsSizeIndex = 0;
  state.detailsColorIndex = 0;
  state.screen = "details";
  render();
}

function openMasterDetails(masterId) {
  state.selectedMasterId = normalizeMasterId(masterId);
  state.masterPhotoIndex = 0;
  state.masterBackStep = state.mastersStep || "list";
  state.screen = "master_details";
  fetchMastersOnce();
  render();
}

function addToCart(productId, opts) {
  opts = opts || {};
  var p = getProductById(productId);
  if (!p) {
    var id = typeof productId === "number" ? productId : parseInt(productId, 10);
    if (isNaN(id)) id = productId;
    p = state.products.find(function (x) { return x.id == id; });
    if (!p) p = state.recommended && state.recommended.find(function (x) { return x.id == id; });
  }
  if (!p) return;

  var sel = opts.fromDetail
    ? getDetailVariantSelection(p)
    : (opts.selection || getDefaultVariantSelection(p));

  var existing = findCartItem(sel.cartKey);
  if (existing) existing.qty += 1;
  else {
    state.cart.push({
      cartKey: sel.cartKey,
      productId: p.id,
      name: sel.name,
      price: sel.price,
      unit: p.unit || "",
      photo: fullUrl((p.photos && p.photos[0]) || p.image || ""),
      qty: 1,
      sizeName: sel.size ? sel.size.name : "",
      colorName: sel.color ? sel.color.name : "",
    });
  }
  saveCart();
  render();
}

function clearCart() {
  state.cart = [];
  state.cartSwipeOpenId = null;
  saveCart();
  render();
}

function openCheckout() {
  state.checkoutError = "";
  state.checkoutOk = false;
  state.lastOrderId = "";
  setScreen("checkout");
}

/* ===== LIGHTBOX ===== */
function openLightbox(photos, startIndex = 0) {
  state.lbPhotos = photos || [];
  state.lbIndex = Math.max(0, Math.min(startIndex, state.lbPhotos.length - 1));
  state.lbOpen = true;
  render();
}
function closeLightbox() {
  state.lbOpen = false;
  render();
}
function nextPhoto(delta) {
  if (!state.lbPhotos.length) return;
  state.lbIndex = (state.lbIndex + delta + state.lbPhotos.length) % state.lbPhotos.length;
  render();
}

/* ===== API ===== */
async function fetchSiteAbout() {
  if (state.siteAbout && !state.siteAboutLoading) return;
  state.siteAboutLoading = true;
  render();
  try {
    const res = await fetch(API + "/site/about");
    if (res.ok) state.siteAbout = await res.json();
    else state.siteAbout = null;
  } catch (_) {
    state.siteAbout = null;
  }
  if (!state.siteAbout) {
    state.siteAbout = {
      years_experience: 20,
      instagram_url: "",
      tiktok_url: "",
      whatsapp_url: "",
    };
  }
  state.siteAboutLoading = false;
  render();
}

async function fetchAllProducts() {
  const pageSize = 100;
  let offset = 0;
  const all = [];
  while (true) {
    const res = await fetch(API + "/products?limit=" + pageSize + "&offset=" + offset);
    if (!res.ok) break;
    const data = await res.json();
    if (Array.isArray(data)) return data;
    const items = data.items || [];
    all.push.apply(all, items);
    if (!data.has_more || items.length === 0) break;
    offset += pageSize;
  }
  return all;
}

async function fetchProductsOnce() {
  if (state.products.length && !state.loadingProducts) return;
  state.loadingProducts = true;
  render();
  try {
    const [products, rRec] = await Promise.all([
      fetchAllProducts(),
      fetch(API + "/products/recommended?limit=50"),
    ]);
    state.products = (products || []).map(function (p) {
      return isCalculatorProduct(p) ? enrichProductForCalc(p) : p;
    });
    if (rRec.ok) {
      var rec = (await rRec.json()) || [];
      state.recommended = rec.map(function (p) {
        return isCalculatorProduct(p) ? enrichProductForCalc(p) : p;
      });
    }
  } catch (e) {
    console.error(e);
  } finally {
    state.loadingProducts = false;
    render();
  }
}

async function fetchProfileData() {
  if (!isLoggedIn()) {
    state.profileMe = null;
    state.profileOrders = [];
    state.profileNotifications = [];
    state.profileUnreadCount = 0;
    render();
    return;
  }
  state.profileLoading = true;
  render();
  try {
    const mePath = isClientUser() ? "/auth/client/me" : "/auth/me";
    const rMe = await authFetch(mePath);
    if (rMe.ok) {
      const data = await rMe.json();
      if (isClientUser() || data.client_id != null) {
        state.profileMe = Object.assign({}, state.profileMe || {}, {
          kind: "client",
          client_id: data.client_id,
          name: data.name,
          phone: data.phone,
        });
      } else if (data.master_id != null) {
        state.profileMe = Object.assign({}, state.profileMe || {}, data, { kind: "master" });
      }
      if (state.profileMe) {
        try { localStorage.setItem(LS_MASTER, JSON.stringify(state.profileMe)); } catch (_) {}
      }
    } else if (rMe.status === 401) {
      clearAuth();
      state.profileLoading = false;
      render();
      return;
    }
    const rOrders = await authFetch("/orders/history");
    if (rOrders.ok) state.profileOrders = (await rOrders.json()) || [];
    else state.profileOrders = [];
    if (isMasterUser()) {
      const [rNotif, rUnread] = await Promise.all([
        authFetch("/notifications?limit=50"),
        authFetch("/notifications/unread_count"),
      ]);
      if (rNotif.ok) state.profileNotifications = (await rNotif.json()) || [];
      else state.profileNotifications = [];
      if (rUnread.ok) {
        const u = await rUnread.json();
        state.profileUnreadCount = u.count != null ? u.count : 0;
      } else state.profileUnreadCount = 0;
    } else {
      state.profileNotifications = [];
      state.profileUnreadCount = 0;
    }
  } catch (e) {
    console.error(e);
  } finally {
    state.profileLoading = false;
    render();
  }
}

async function fetchMastersOnce() {
  if (state.masters.length || state.loadingMasters) return;
  state.loadingMasters = true;
  render();
  try {
    const res = await fetch(API + "/masters");
    if (!res.ok) throw new Error("masters load failed");
    const raw = (await res.json()) || [];
    state.masters = raw.map(function (m) {
      const photo = fullUrl(m.image || (m.portfolio && m.portfolio[0]) || "");
      const workPhotos = (m.portfolio || []).map(fullUrl).filter(Boolean);
      const services = (m.services || []).map(function (s) {
        return { name: s.name || "", price: s.price != null ? Number(s.price) : null };
      });
      const firstPrice = services.length && services[0].price != null ? services[0].price : null;
      const phone = (m.phone || "").trim();
      const wa = phone.replace(/\D/g, "");
      return Object.assign({}, m, {
        id: normalizeMasterId(m.id),
        avatar: photo,
        photo: photo,
        work_photos: workPhotos.length ? workPhotos : (photo ? [photo] : []),
        works: workPhotos.length ? workPhotos : (photo ? [photo] : []),
        services: services,
        categories: Array.isArray(m.categories) ? m.categories : [],
        phone: phone,
        whatsapp: wa,
        price_from: firstPrice,
      });
    });
  } catch (e) {
    console.error(e);
  } finally {
    state.loadingMasters = false;
    render();
  }
}

async function submitOrder() {
  state.checkoutError = "";
  state.checkoutOk = false;
  state.lastOrderId = "";

  const name = (state.checkout.name || "").trim();
  const phone = normalizePhone(state.checkout.phone);
  const address = (state.checkout.address || "").trim();

  if (!name) { state.checkoutError = "Введите имя"; render(); return; }
  if (!phone || phone.length < 8) { state.checkoutError = "Введите корректный номер телефона"; render(); return; }
  if (state.checkout.deliveryType === "delivery" && !address) { state.checkoutError = "Введите адрес доставки или выберите самовывоз"; render(); return; }
  if (!state.cart.length) { state.checkoutError = "Корзина пуста"; render(); return; }

  const items = state.cart.map((it) => ({
    product_id: it.productId,
    product_name: it.name,
    qty: it.qty,
    unit: it.unit || "",
    price: Number(it.price || 0),
  }));

  const total = cartTotal();
  const orderPayload = {
    client_name: name,
    client_phone: phone,
    client_address: state.checkout.deliveryType === "pickup" ? "Самовывоз" : address,
    total_price: total,
    payment_type: (state.checkout.payment || "cash").toLowerCase(),
    items: state.cart.map(function (it) {
      return {
        product_id: parseInt(it.productId, 10) || 0,
        name: it.name || "",
        qty: parseFloat(it.qty) || 1,
        price: Number(it.price || 0),
      };
    }),
  };

  state.checkoutLoading = true;
  render();

  try {
    const res = await fetch(API + "/orders", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(orderPayload),
    });

    if (!res.ok) {
      const text = await res.text().catch(function () { return ""; });
      throw new Error(text || "Ошибка оформления заказа");
    }

    const data = await res.json().catch(function () { return {}; });
    state.lastOrderId = data.id != null ? String(data.id) : "";
    state.checkoutOk = true;

    state.cart = [];
    state.cartSwipeOpenId = null;
    saveCart();

  } catch (e) {
    console.error(e);
    state.checkoutError = "Не получилось оформить заказ. Проверь данные и попробуй ещё раз.";
  } finally {
    state.checkoutLoading = false;
    render();
  }
}

/* ===== UI PARTS ===== */
function tab(id, iconName, label) {
  // Корзина открывается со стройматериалов — подсвечиваем вкладку «Материалы».
  const isActive =
    state.screen === id || (id === "materials" && state.screen === "cart");
  const ic = typeof icon === "function" ? icon(iconName, "tab-ico") : iconName;
  return `
    <button class="tab ${isActive ? "active" : ""}" data-act="nav" data-screen="${id}">
      <div class="i">${ic}</div>
      <div>${label}</div>
    </button>
  `;
}

function tabPlus(id) {
  const active = state.screen === id ? "active" : "";
  return `
    <button class="tab tab-plus ${active}" data-act="nav" data-screen="${id}" aria-label="Публикация">
      <div class="tab-plus-inner">${typeof icon === "function" ? icon("plus", "tab-ico", 22) : "+"}</div>
    </button>
  `;
}

function renderBottomNav() {
  return `
    ${tab("home", "home", "Главная")}
    ${tab("masters", "users", "Мастера")}
    ${tabPlus("publish")}
    ${tab("materials", "box", "Материалы")}
    ${tab("profile", "user", "Профиль")}
  `;
}

function renderDesktopHeader() {
  const count = cartCount();
  const showSearch = ["home", "masters", "materials", "products"].includes(state.screen);
  const themeDark = state.profileTheme === "dark";
  return `
    <header class="desk-header desktop-header">
      <div class="desk-header-inner">
        <button type="button" class="desk-logo" data-act="nav" data-screen="home">
          <span class="desk-logo-mark">${icon("package", "", 22)}</span>
          <span class="desk-logo-text">Ustomarket</span>
        </button>
        ${showSearch ? `<div class="desk-search-wrap">${renderSearchBar("desk")}</div>` : `<div class="desk-search-wrap desk-search-wrap--placeholder"></div>`}
        <nav class="desk-actions" aria-label="Основная навигация">
          <button type="button" class="desk-action ${state.screen === "masters" ? "active" : ""}" data-act="nav" data-screen="masters">${icon("users")}<span>Мастера</span></button>
          <button type="button" class="desk-action ${state.screen === "materials" ? "active" : ""}" data-act="nav" data-screen="materials">${icon("box")}<span>Материалы</span></button>
          <button type="button" class="desk-action ${state.screen === "products" ? "active" : ""}" data-act="nav" data-screen="products">${icon("grid")}<span>Каталог</span></button>
          <button type="button" class="desk-action desk-action-cart ${state.screen === "cart" ? "active" : ""}" data-act="nav" data-screen="cart">
            ${icon("cart")}
            <span>Корзина</span>
            ${count ? `<span class="desk-badge">${count}</span>` : ""}
          </button>
          <button type="button" class="desk-action ${state.screen === "profile" ? "active" : ""}" data-act="nav" data-screen="profile">${icon("user")}<span>Профиль</span></button>
          <button type="button" class="desk-action desk-theme-btn" data-act="toggle-theme" aria-label="${themeDark ? "Светлая тема" : "Тёмная тема"}">${icon(themeDark ? "sun" : "moon")}<span>${themeDark ? "Светлая" : "Тёмная"}</span></button>
        </nav>
      </div>
    </header>
  `;
}

function renderDesktopNav() {
  const cats = getCategories().slice(0, 12);
  if (!cats.length) return "";
  return `
    <nav class="desk-nav" aria-label="Категории">
      <div class="desk-nav-inner">
        <button type="button" class="desk-nav-all" data-act="nav" data-screen="products">
          ${icon("menu", "", 18)}<span>Все категории</span>
        </button>
        <div class="desk-nav-links">
          ${cats
            .map(function (c) {
              const active =
                (state.screen === "products" || state.screen === "materials") && state.selectedCategory === c ? " active" : "";
              return `<button type="button" class="desk-nav-link${active}" data-act="desk-open-cat" data-cat="${escapeHtml(c)}">${escapeHtml(c)}</button>`;
            })
            .join("")}
        </div>
      </div>
    </nav>
  `;
}

function renderDesktopFooter() {
  return `
    <footer class="desk-footer">
      <div class="desk-footer-inner">
        <div class="desk-footer-brand">
          <div class="desk-footer-logo">${icon("package", "", 20)} Ustobozor</div>
          <p class="desk-footer-tagline">Строительные материалы и мастера — минимум лишнего, максимум удобства.</p>
        </div>
        <div class="desk-footer-col">
          <div class="desk-footer-title">Покупателям</div>
          <button type="button" class="desk-footer-link" data-act="nav" data-screen="chat_order">Чат-заказ</button>
          <button type="button" class="desk-footer-link" data-act="nav" data-screen="calculator">Калькулятор сметы</button>
          <button type="button" class="desk-footer-link" data-act="nav" data-screen="materials">Стройматериалы</button>
          <button type="button" class="desk-footer-link" data-act="nav" data-screen="products">Каталог</button>
          <button type="button" class="desk-footer-link" data-act="nav" data-screen="cart">Корзина</button>
          <button type="button" class="desk-footer-link" data-act="nav" data-screen="orders">Заказы</button>
        </div>
        <div class="desk-footer-col">
          <div class="desk-footer-title">Услуги</div>
          <button type="button" class="desk-footer-link" data-act="nav" data-screen="masters">Мастера</button>
          <button type="button" class="desk-footer-link" data-act="nav" data-screen="profile">Профиль</button>
        </div>
        <div class="desk-footer-col">
          <div class="desk-footer-title">Контакты</div>
          <span class="desk-footer-muted">Доставка по городу</span>
          <span class="desk-footer-muted">Поддержка в WhatsApp</span>
        </div>
      </div>
      <div class="desk-footer-bottom">© ${new Date().getFullYear()} Ustobozor</div>
    </footer>
  `;
}

function renderCatalogSidebar() {
  const cats = getCategories();
  const active = state.selectedCategory || "";
  return `
    <aside class="desk-sidebar">
      <div class="desk-sidebar-head">
        ${icon("grid", "desk-sidebar-ico", 18)}
        <span>Каталог</span>
      </div>
      <nav class="desk-sidebar-nav">
        <button type="button" class="desk-sidebar-item ${!active ? "active" : ""}" data-act="mat-reset">Все категории</button>
        ${cats
          .map(function (c) {
            const on = active === c ? " active" : "";
            return `<button type="button" class="desk-sidebar-item${on}" data-act="open-cat" data-cat="${escapeHtml(c)}">${escapeHtml(c)}</button>`;
          })
          .join("")}
      </nav>
    </aside>
  `;
}

function renderSearchBar(variant) {
  const show = ["home", "masters", "materials", "products"].includes(state.screen);
  if (!show) return "";

  if (state.searchCity == null) state.searchCity = "";

  const v =
    state.screen === "home"
      ? state.qHomeDraft
      : state.screen === "materials"
      ? state.qMaterialsDraft
      : state.screen === "products"
      ? state.qProductsDraft
      : state.qMastersDraft;

  let placeholder = "Поиск...";
  if (state.screen === "home") placeholder = "Мастер, профессия, город…";
  if (state.screen === "materials") placeholder = "Поиск товаров…";
  if (state.screen === "products") {
    if (state.materialsStep === "categories") placeholder = "Поиск категорий или товаров…";
    if (state.materialsStep === "subcategories") placeholder = "Поиск подкатегорий…";
    if (state.materialsStep === "items") placeholder = "Поиск товаров…";
  }
  if (state.screen === "masters") {
    if (state.mastersStep === "categories") placeholder = "Поиск категории…";
    if (state.mastersStep === "list") placeholder = "Мастер, профессия, город…";
  }

  const hasText = !!(v || "").trim();
  const showCity =
    state.screen === "home" || state.screen === "masters";
  const cities = getMasterCities();
  const citySelect = showCity
    ? `<select class="search-city" data-act="search-city" aria-label="Город" title="Фильтр по городу">
        <option value="">Все города</option>
        ${cities
          .map(function (c) {
            return `<option value="${escapeHtml(c)}"${
              state.searchCity === c ? " selected" : ""
            }>${escapeHtml(c)}</option>`;
          })
          .join("")}
      </select>`
    : "";

  return `
    <form class="search${variant === "desk" ? " search--desk" : ""}${
      showCity ? " search--with-city" : ""
    }" data-search-form autocomplete="off" action="#" onsubmit="return false">
      <div class="icon">${icon("search", "search-ico", 18)}</div>
      <input type="search" enterkeyhint="search" value="${escapeHtml(v)}" data-act="q" placeholder="${placeholder}" autocomplete="off">
      ${citySelect}
      <button type="button" class="search-clear${hasText ? "" : " hidden"}" data-act="q-clear" aria-label="Очистить">${icon("close", "", 16)}</button>
      <button type="submit" class="search-submit" data-act="q-submit" aria-label="Искать">${icon("search", "", 18)}</button>
    </form>
  `;
}

function renderHeader() {
  const s = state.screen;
  if (s === "details") {
    const p = state.products.find(x => x.id == state.selectedProductId) || (state.recommended && state.recommended.find(x => x.id == state.selectedProductId));
    return `<div class="header-with-back"><button class="back-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">${p ? escapeHtml(p.name) : "Товар"}</span></div>`;
  }
  if (s === "master_details") return `<div class="header-with-back"><button class="back-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">Мастер</span></div>`;
  if (s === "cart") return `<div class="header-with-back"><button class="back-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">Моя корзина (${state.cart.length})</span></div>`;
  if (s === "checkout") return `<div class="header-with-back"><button class="back-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">Оформление</span></div>`;
  if (s === "profile" && (state.profileSection === "language" || state.profileSection === "projects")) {
    return `<div class="header-with-back"><button class="back-btn" data-act="profile-back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">Профиль</span></div>`;
  }
  if (s === "profile") {
    return `<div class="brand-row"><div class="brand">Ustobozor</div></div>`;
  }
  if (s === "orders") return `<div class="header-with-back"><button class="back-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">Мои заказы</span></div>`;
  if (s === "notifications") return `<div class="header-with-back"><button class="back-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">Уведомления ${state.profileUnreadCount > 0 ? "(" + state.profileUnreadCount + ")" : ""}</span></div>`;
  if (s === "chat_order") return `<div class="header-with-back"><button class="back-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">Чат-заказ</span><button class="icon-btn chat-clear-btn" data-act="chat-reset" aria-label="Очистить">${icon("close", "", 18)}</button></div>`;
  if (s === "master_auth" || s === "client_auth") {
    const title = "Вход";
    return `<div class="header-with-back"><button class="back-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">${title}</span></div>`;
  }
  if (s === "about") {
    const aboutTxt = aboutI18n(state.profileLang);
    return `<div class="header-with-back"><button class="back-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">${aboutTxt.title}</span></div>`;
  }
  if (s === "calculator") {
    return `<div class="header-with-back"><button class="back-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button><span class="header-title">Калькулятор сметы</span></div>`;
  }
  if (s === "home") {
    return `<div class="home-header-desk desk-only"><div class="brand-row"><div class="brand">Ustomarket</div></div>${renderSearchBar()}</div>`;
  }
  if (s === "materials") {
    const count = cartCount();
    return `
      <div class="brand-row">
        <div class="brand">Стройматериалы</div>
      </div>
      <div class="materials-search-row">
        ${renderSearchBar()}
        <button type="button" class="materials-cart-btn" data-act="nav" data-screen="cart" aria-label="Корзина">
          <span class="materials-cart-ico">${icon("cart", "", 22)}${count ? `<span class="materials-cart-badge">${count}</span>` : ""}</span>
          <span class="materials-cart-label">Корзина</span>
        </button>
      </div>
    `;
  }
  if (s === "publish") {
    return `<div class="brand-row"><div class="brand">Публикация</div></div>`;
  }
  return `<div class="brand-row"><div class="brand">Ustobozor</div></div>${renderSearchBar()}`;
}

/* ===== CALCULATOR ===== */
function calcSafeNumber(value, fallback) {
  var n = Number(value);
  if (!isFinite(n) || isNaN(n)) return fallback;
  return n;
}

function calcClamp(value, min, max) {
  var n = calcSafeNumber(value, min);
  if (n < min) return min;
  if (n > max) return max;
  return n;
}

function calcRoundStep(value, step) {
  var s = calcSafeNumber(step, 0.1);
  if (s <= 0) return value;
  return Math.round(value / s) * s;
}

function calcFormatDim(value) {
  var n = calcSafeNumber(value, 0);
  return (Math.round(n * 10) / 10).toFixed(1);
}

function calcProductText(p) {
  return [
    p && p.name,
    p && p.category,
    p && p.subcategory,
    p && p.brand,
    p && p.articul,
  ].join(" ").toLowerCase();
}

function isCalculatorProduct(p) {
  if (!p) return false;
  if (p.consumption != null && p.packaging != null) return true;
  var text = calcProductText(p);
  return /эмаль|краск|шпат|шпакл|грунт|эмульс|mashad|mashhad|лак|краска|putty|paint|enamel|штукатур|rotband|plaster/.test(text);
}

function packagingFromProductSizes(p) {
  var sizes = (p && p.sizes) || [];
  var best = null;
  for (var i = 0; i < sizes.length; i++) {
    var name = String((sizes[i] && sizes[i].name) || "");
    var m = name.match(/(\d+(?:[.,]\d+)?)\s*(кг|kg|л|l)\b/i);
    if (!m) continue;
    var val = parseFloat(String(m[1]).replace(",", "."));
    if (!isFinite(val) || val <= 0) continue;
    if (best == null || val > best) best = val;
  }
  return best;
}

function inferCalcSpecs(p) {
  var text = calcProductText(p);
  var idKey = String(p && p.id != null ? p.id : "");
  if (PRODUCT_CALC_OVERRIDES[idKey]) return Object.assign({}, PRODUCT_CALC_OVERRIDES[idKey]);
  if (/шпат|шпакл|putty/.test(text)) {
    return { consumption: 1.0, packaging: 20, laborPrice: 12, unitType: "меш.", kind: "putty" };
  }
  if (/штукатур|rotband|plaster/.test(text)) {
    return { consumption: 8.5, packaging: 25, laborPrice: 25, unitType: "меш.", kind: "plaster" };
  }
  if (/грунт/.test(text)) {
    return { consumption: 0.15, packaging: 10, laborPrice: 8, unitType: "вед.", kind: "primer" };
  }
  if (/эмаль|enamel|mashad|mashhad|пф-115|пф 115/.test(text)) {
    return { consumption: 0.3, packaging: 3, laborPrice: 18, unitType: "вед.", kind: "enamel" };
  }
  if (/эмульс|emulsion/.test(text)) {
    return { consumption: 0.25, packaging: 5, laborPrice: 15, unitType: "вед.", kind: "emulsion" };
  }
  // краски по умолчанию
  return { consumption: 0.25, packaging: 5, laborPrice: 15, unitType: "вед.", kind: "paint" };
}

function enrichProductForCalc(p) {
  if (!p) return null;
  var specs = inferCalcSpecs(p);
  var fromSize = packagingFromProductSizes(p);
  var packaging = calcSafeNumber(p.packaging, 0) > 0
    ? Number(p.packaging)
    : (fromSize != null ? fromSize : specs.packaging);
  var consumption = calcSafeNumber(p.consumption, 0) > 0 ? Number(p.consumption) : specs.consumption;
  var laborPrice = calcSafeNumber(p.laborPrice, NaN);
  if (!isFinite(laborPrice) || laborPrice < 0) laborPrice = specs.laborPrice;
  var unitType = (p.unitType && String(p.unitType).trim()) || specs.unitType || "шт.";
  var price = calcSafeNumber(p.price, 0);
  var sizes = p.sizes || [];
  if (sizes.length && calcSafeNumber(sizes[0].price, 0) > 0) {
    // если у фасовки есть цена — берём цену ближайшей к packaging
    var matched = null;
    for (var i = 0; i < sizes.length; i++) {
      var nm = String(sizes[i].name || "");
      var m = nm.match(/(\d+(?:[.,]\d+)?)/);
      if (!m) continue;
      var v = parseFloat(String(m[1]).replace(",", "."));
      if (isFinite(v) && Math.abs(v - packaging) < 0.05) {
        matched = sizes[i];
        break;
      }
    }
    var sizePrice = calcSafeNumber((matched || sizes[0]).price, 0);
    if (sizePrice > 0) price = sizePrice;
  }
  return Object.assign({}, p, {
    consumption: Math.max(0.01, consumption),
    packaging: Math.max(0.1, packaging),
    laborPrice: Math.max(0, laborPrice),
    unitType: unitType,
    price: Math.max(0, price),
    kind: specs.kind || p.kind || "paint",
  });
}

function getSelectedCalcService() {
  if (!state.calc.serviceId) return null;
  return CALC_SERVICES.find(function (s) { return s.id === state.calc.serviceId; }) || null;
}

function getCalculatorProducts() {
  var all = (state.products || []).concat(state.recommended || []);
  var seen = {};
  var out = [];
  var service = getSelectedCalcService();
  var kindFilter = service && service.kinds && service.kinds.length ? service.kinds : null;

  for (var i = 0; i < all.length; i++) {
    var raw = all[i];
    if (!raw || raw.id == null) continue;
    var key = String(raw.id);
    if (seen[key]) continue;
    if (!isCalculatorProduct(raw)) continue;
    seen[key] = true;
    var enriched = enrichProductForCalc(raw);
    if (kindFilter && kindFilter.indexOf(enriched.kind) === -1) continue;
    out.push(enriched);
  }
  out.sort(function (a, b) {
    return String(a.name || "").localeCompare(String(b.name || ""), "ru");
  });
  return out;
}

function ensureCalcProductSelected() {
  var list = getCalculatorProducts();
  if (!list.length) {
    state.calc.productId = null;
    return null;
  }
  var current = list.find(function (p) { return String(p.id) === String(state.calc.productId); });
  if (!current) {
    state.calc.productId = list[0].id;
    current = list[0];
  }
  return current;
}

function computeCalcEstimate() {
  var length = calcClamp(state.calc.length, 1.0, 30);
  var width = calcClamp(state.calc.width, 1.0, 30);
  var height = calcClamp(state.calc.height, 2.0, 5.0);
  var doors = Math.max(1, Math.round(calcSafeNumber(state.calc.doors, 1)));
  var windows = Math.max(1, Math.round(calcSafeNumber(state.calc.windows, 1)));
  state.calc.length = length;
  state.calc.width = width;
  state.calc.height = height;
  state.calc.doors = doors;
  state.calc.windows = windows;

  var service = getSelectedCalcService();
  var product = ensureCalcProductSelected();

  var grossWallArea = (length + width) * 2 * height;
  var openingsArea = doors * CALC_DOOR_AREA_M2 + windows * CALC_WINDOW_AREA_M2;
  var wallArea = Math.max(0, grossWallArea - openingsArea);
  var ceilingArea = length * width;
  var workArea = service && service.areaMode === "ceiling" ? ceilingArea : wallArea;
  if (!isFinite(wallArea) || wallArea < 0) wallArea = 0;
  if (!isFinite(ceilingArea) || ceilingArea < 0) ceilingArea = 0;
  if (!isFinite(workArea) || workArea < 0) workArea = 0;

  // площадь для расхода материала: потолок — потолок, иначе стены (уже без окон/дверей)
  var materialArea = service && service.areaMode === "ceiling" ? ceilingArea : wallArea;

  var packs = 0;
  var materialsCost = 0;
  var unitType = "шт.";
  if (product) {
    var consumption = Math.max(0.01, calcSafeNumber(product.consumption, 0.25));
    var packaging = Math.max(0.1, calcSafeNumber(product.packaging, 1));
    var price = Math.max(0, calcSafeNumber(product.price, 0));
    packs = Math.ceil((materialArea * consumption) / packaging);
    if (!isFinite(packs) || packs < 0) packs = 0;
    materialsCost = packs * price;
    if (!isFinite(materialsCost) || materialsCost < 0) materialsCost = 0;
    unitType = product.unitType || "шт.";
  }

  var laborRate = service ? Math.max(0, calcSafeNumber(service.pricePerM2, 0)) : 0;
  var laborCost = service ? workArea * laborRate : 0;
  if (!isFinite(laborCost) || laborCost < 0) laborCost = 0;

  return {
    wallArea: wallArea,
    grossWallArea: grossWallArea,
    openingsArea: openingsArea,
    doors: doors,
    windows: windows,
    ceilingArea: ceilingArea,
    workArea: workArea,
    materialArea: materialArea,
    packs: packs,
    materialsCost: materialsCost,
    laborCost: laborCost,
    laborRate: laborRate,
    total: materialsCost + laborCost,
    unitType: unitType,
    product: product,
    service: service,
  };
}

function formatSomoni(n) {
  var v = calcSafeNumber(n, 0);
  return Math.round(v).toLocaleString("ru-RU");
}

function unitLabel(count, unitType) {
  var u = (unitType || "шт.").trim();
  return count + " " + u;
}

function renderCalculatorSection() {
  var products = getCalculatorProducts();
  var estimate = computeCalcEstimate();
  var selectedId = state.calc.productId;
  var service = estimate.service;
  var presets = CALC_ROOM_PRESETS.map(function (pr) {
    var active =
      Math.abs(state.calc.length - pr.length) < 0.01 &&
      Math.abs(state.calc.width - pr.width) < 0.01;
    return `<button type="button" class="calc-chip${active ? " is-active" : ""}" data-act="calc-preset" data-length="${pr.length}" data-width="${pr.width}">${pr.label}</button>`;
  }).join("");

  var serviceChips = [
    `<button type="button" class="calc-chip${state.calc.serviceId ? "" : " is-active"}" data-act="calc-service" data-id="">Без работы</button>`,
  ].concat(CALC_SERVICES.map(function (s) {
    var active = state.calc.serviceId === s.id ? " is-active" : "";
    return `<button type="button" class="calc-chip${active}" data-act="calc-service" data-id="${escapeHtml(s.id)}">${escapeHtml(s.name)} · ${s.pricePerM2} с/м²</button>`;
  })).join("");

  var options = products.length
    ? products.map(function (p) {
        var sel = String(p.id) === String(selectedId) ? " selected" : "";
        return `<option value="${escapeHtml(String(p.id))}"${sel}>${escapeHtml(p.name)} — ${formatSomoni(p.price)} с.</option>`;
      }).join("")
    : `<option value="">Нет подходящих товаров</option>`;

  var areaHint = service && service.areaMode === "ceiling"
    ? `Площадь потолка: <strong>${calcFormatDim(estimate.ceilingArea)} м²</strong>`
    : `Стены: <strong>${calcFormatDim(estimate.grossWallArea)} м²</strong> − проёмы <strong>${calcFormatDim(estimate.openingsArea)} м²</strong> (${estimate.doors} дв. + ${estimate.windows} ок.) = <strong>${calcFormatDim(estimate.wallArea)} м²</strong>`;

  return `
    <section class="calculator-section" aria-label="Сметный калькулятор">
      <div class="calc-head">
        <div class="calc-title">Калькулятор сметы</div>
        <div class="calc-subtitle">Материал + услуга мастера — только кликами, без клавиатуры</div>
      </div>

      <div class="calc-block">
        <div class="calc-block-label">Быстрый выбор комнаты</div>
        <div class="calc-chips">${presets}</div>
      </div>

      <div class="calc-block">
        <div class="calc-block-label">Размеры помещения</div>
        <div class="calc-steppers">
          <div class="calc-stepper-row">
            <span class="calc-stepper-name">Длина</span>
            <div class="calc-stepper-controls">
              <button type="button" class="calc-step-btn" data-act="calc-step" data-field="length" data-delta="-0.5" aria-label="Уменьшить длину">−</button>
              <span class="calc-step-val" id="length-val">${calcFormatDim(state.calc.length)}</span>
              <span class="calc-step-unit">м</span>
              <button type="button" class="calc-step-btn" data-act="calc-step" data-field="length" data-delta="0.5" aria-label="Увеличить длину">+</button>
            </div>
          </div>
          <div class="calc-stepper-row">
            <span class="calc-stepper-name">Ширина</span>
            <div class="calc-stepper-controls">
              <button type="button" class="calc-step-btn" data-act="calc-step" data-field="width" data-delta="-0.5" aria-label="Уменьшить ширину">−</button>
              <span class="calc-step-val" id="width-val">${calcFormatDim(state.calc.width)}</span>
              <span class="calc-step-unit">м</span>
              <button type="button" class="calc-step-btn" data-act="calc-step" data-field="width" data-delta="0.5" aria-label="Увеличить ширину">+</button>
            </div>
          </div>
          <div class="calc-stepper-row">
            <span class="calc-stepper-name">Высота потолка</span>
            <div class="calc-stepper-controls">
              <button type="button" class="calc-step-btn" data-act="calc-step" data-field="height" data-delta="-0.1" aria-label="Уменьшить высоту">−</button>
              <span class="calc-step-val" id="height-val">${calcFormatDim(state.calc.height)}</span>
              <span class="calc-step-unit">м</span>
              <button type="button" class="calc-step-btn" data-act="calc-step" data-field="height" data-delta="0.1" aria-label="Увеличить высоту">+</button>
            </div>
          </div>
          <div class="calc-stepper-row">
            <span class="calc-stepper-name">Двери</span>
            <div class="calc-stepper-controls">
              <button type="button" class="calc-step-btn" data-act="calc-step" data-field="doors" data-delta="-1" aria-label="Уменьшить число дверей">−</button>
              <span class="calc-step-val" id="doors-val">${state.calc.doors}</span>
              <span class="calc-step-unit">шт</span>
              <button type="button" class="calc-step-btn" data-act="calc-step" data-field="doors" data-delta="1" aria-label="Увеличить число дверей">+</button>
            </div>
          </div>
          <div class="calc-stepper-row">
            <span class="calc-stepper-name">Окна</span>
            <div class="calc-stepper-controls">
              <button type="button" class="calc-step-btn" data-act="calc-step" data-field="windows" data-delta="-1" aria-label="Уменьшить число окон">−</button>
              <span class="calc-step-val" id="windows-val">${state.calc.windows}</span>
              <span class="calc-step-unit">шт</span>
              <button type="button" class="calc-step-btn" data-act="calc-step" data-field="windows" data-delta="1" aria-label="Увеличить число окон">+</button>
            </div>
          </div>
        </div>
        <div class="calc-area-hint">${areaHint}</div>
        <div class="calc-area-hint">Норма проёма: дверь ${CALC_DOOR_AREA_M2} м², окно ${CALC_WINDOW_AREA_M2} м² (минимум по 1 шт.)</div>
      </div>

      <div class="calc-block">
        <div class="calc-block-label">Услуга мастера</div>
        <div class="calc-chips calc-chips--wrap">${serviceChips}</div>
        ${service ? `<div class="calc-area-hint">${escapeHtml(service.hint)} · <strong>${service.pricePerM2} сомони/м²</strong></div>` : `<div class="calc-area-hint">Выберите услугу, чтобы добавить работу в смету</div>`}
      </div>

      <div class="calc-block">
        <div class="calc-block-label">Материал</div>
        <label class="calc-select-wrap">
          <select id="calc-product-select" class="calc-select" data-act="calc-product" aria-label="Выбор товара">
            ${options}
          </select>
        </label>
        ${service ? `<div class="calc-area-hint">Показаны материалы под услугу «${escapeHtml(service.name)}»</div>` : ""}
      </div>

      <div class="calc-receipt">
        <div class="calc-receipt-title">Смета</div>
        <div class="calc-receipt-row">
          <span>Требуемое количество</span>
          <strong>${unitLabel(estimate.packs, estimate.unitType)}</strong>
        </div>
        <div class="calc-receipt-row">
          <span>Стоимость материалов</span>
          <strong>${formatSomoni(estimate.materialsCost)} сомони</strong>
        </div>
        ${service ? `
        <div class="calc-receipt-row">
          <span>${escapeHtml(service.name)} (${calcFormatDim(estimate.workArea)} м² × ${estimate.laborRate} с)</span>
          <strong>${formatSomoni(estimate.laborCost)} сомони</strong>
        </div>` : `
        <div class="calc-receipt-row">
          <span>Стоимость работы</span>
          <strong>не выбрана</strong>
        </div>`}
        <div class="calc-receipt-divider"></div>
        <div class="calc-receipt-total">
          <span>Итоговая смета</span>
          <strong>${formatSomoni(estimate.total)} сомони</strong>
        </div>
        ${estimate.product
          ? `<div class="calc-receipt-note">${escapeHtml(estimate.product.name)} · расход ${calcSafeNumber(estimate.product.consumption, 0)} кг/м² · упак. ${calcSafeNumber(estimate.product.packaging, 0)} кг${service ? " · " + escapeHtml(service.name) : ""}</div>`
          : `<div class="calc-receipt-note">Выберите материал${service ? " или оставьте только стоимость услуги" : ""}</div>`}
      </div>
    </section>
  `;
}

function renderCalculator() {
  return `
    <div class="calc-page">
      ${state.loadingProducts && !getCalculatorProducts().length
        ? `<div class="empty-state">Загрузка товаров…</div>`
        : ""}
      ${renderCalculatorSection()}
      <div class="calc-page-actions">
        <button type="button" class="btn btn-accent" data-act="nav" data-screen="products">Открыть каталог</button>
        <button type="button" class="btn btn-outline" data-act="nav" data-screen="masters">Найти мастера</button>
      </div>
    </div>
  `;
}

function productCard(p, from) {
  const photo = productImageUrl((p.photos && p.photos[0]) || p.image || "");
  const favOn = isFav(p.id) ? " is-active" : "";
  const unit = (p.unit && String(p.unit).trim()) ? String(p.unit).trim() : "шт";
  const colors = productColors(p);
  const sizes = productSizes(p);
  const displayPrice = sizes.length ? Number(sizes[0].price) : Number(p.price) || 0;
  const variantHint = (colors.length || sizes.length)
    ? `<div class="p-variants">
        ${colors.slice(0, 5).map(function (c) {
          var hex = colorHex(c);
          return `<span class="p-variant-dot${isLightColor(hex) ? " is-light" : ""}" style="background:${escapeHtml(hex)}" title="${escapeHtml(c.name || "")}"></span>`;
        }).join("")}
        ${sizes.length ? `<span class="p-variant-tag">${sizes.length} ${sizes.length === 1 ? "размер" : "разм."}</span>` : ""}
      </div>`
    : "";
  return `
    <div class="p-card">
      <div class="p-img" data-act="open" data-id="${p.id}" data-from="${from}">
        ${photo ? `<img src="${photo}" alt="${escapeHtml(p.name)}" loading="lazy">` : `<div class="p-img-empty">Нет фото</div>`}
        <button type="button" class="p-fav${favOn}" data-act="fav" data-id="${p.id}" aria-label="В избранное">${icon("heart", "", 18)}</button>
        <button type="button" class="p-add-float" data-act="add" data-id="${p.id}" aria-label="В корзину">${icon("cart", "", 18)}</button>
      </div>
      <div class="p-body">
        <div class="p-price">${formatPriceSmn(displayPrice)}</div>
        <div class="p-name">${escapeHtml(p.name)}</div>
        <div class="p-unit">${escapeHtml(unit)}</div>
        ${variantHint}
      </div>
    </div>
  `;
}

function masterCard(m) {
  const photo = getMasterAvatar(m);
  const initials = (m.name || "M")
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((s) => s[0].toUpperCase())
    .join("");

  const wa = (m.whatsapp || m.phone || "").replace(/\s+/g, "");
  const phone = (m.phone || "").trim();
  const cats = getMasterCategoriesList(m);

  return `
    <div class="m-card m-card-row">
      <div class="m-card-left" data-act="open-master" data-id="${m.id}">
        <div class="m-ava m-ava-sm">
          ${photo ? `<img src="${photo}" alt="${escapeHtml(m.name)}">` : initials}
        </div>
        <div class="m-main" style="flex:1;min-width:0;">
          <div class="m-name">${escapeHtml(m.name || "Мастер")}</div>
          <div class="m-tags">${cats.slice(0, 3).map(c => `<span class="m-tag">${escapeHtml(c)}</span>`).join("")}</div>
          <div class="m-price">${m.price_from != null ? `от ${formatPriceSmn(m.price_from)}` : ""}</div>
        </div>
      </div>
      <div class="m-card-actions">
        ${phone ? `<button class="m-btn-circle m-btn-call" data-act="call" data-phone="${escapeHtml(phone)}" aria-label="Позвонить">${icon("phone", "", 18)}</button>` : ""}
        ${wa ? `<a class="m-btn-circle m-btn-wa" href="https://wa.me/${wa}" target="_blank" rel="noopener" aria-label="WhatsApp">${icon("message", "", 18)}</a>` : ""}
      </div>
    </div>
  `;
}

function renderLightboxHTML() {
  return `
    <div class="lb ${state.lbOpen ? "show" : ""}" data-act="lb-close">
      <div class="lb-top">
        <div class="lb-count">${state.lbPhotos.length ? (state.lbIndex + 1) + " / " + state.lbPhotos.length : ""}</div>
        <button class="icon-btn" data-act="lb-close">${icon("close", "", 18)}</button>
      </div>

      ${state.lbPhotos.length ? `<img class="lb-img" src="${state.lbPhotos[state.lbIndex]}" alt="">` : ``}

      <div class="lb-nav">
        <div class="lb-side" data-act="lb-prev"></div>
        <div class="lb-side" data-act="lb-next"></div>
      </div>
    </div>
  `;
}

function getMasterHeroImage(m) {
  const avatar = getMasterAvatar(m);
  if (avatar) return productImageUrl(avatar);
  const works = getMasterWorks(m);
  if (works.length) return productImageUrl(works[0]);
  return "";
}

function homeMasterCard(m) {
  const photo = getMasterHeroImage(m);
  const cats = getMasterCategoriesList(m);
  const price = m.price_from != null ? `от ${formatPriceSmn(m.price_from)}` : "";

  return `
    <div class="home-master-card" data-act="open-master" data-id="${m.id}">
      <div class="home-master-card-img">
        ${photo
          ? `<img src="${photo}" alt="${escapeHtml(m.name)}" loading="lazy">`
          : `<div class="home-master-card-placeholder">${icon("hammer", "", 40)}</div>`}
      </div>
      <div class="home-master-card-body">
        <div class="home-master-card-name">${escapeHtml(m.name || "Мастер")}</div>
        ${cats.length
          ? `<div class="home-master-card-tags">${cats.slice(0, 3).map(function (c) {
              return `<span class="home-master-card-tag">${escapeHtml(c)}</span>`;
            }).join("")}</div>`
          : ""}
        ${price ? `<div class="home-master-card-price">${price}</div>` : ""}
      </div>
    </div>
  `;
}

function renderHomeMaterialsBanner() {
  return `
    <button type="button" class="home-materials-banner" data-act="nav" data-screen="materials">
      <div class="home-materials-banner-icon">${icon("box", "", 24)}</div>
      <div class="home-materials-banner-text">
        <div class="home-materials-banner-title">Стройматериалы</div>
        <div class="home-materials-banner-desc">Каталог товаров с доставкой</div>
      </div>
      <div class="home-materials-banner-cta">${icon("chevronRight", "", 18)}</div>
    </button>
  `;
}

function renderMaterialsCatalogBanner() {
  return `
    <button type="button" class="home-materials-banner home-materials-banner--catalog" data-act="nav" data-screen="products">
      <div class="home-materials-banner-icon">${icon("grid", "", 24)}</div>
      <div class="home-materials-banner-text">
        <div class="home-materials-banner-title">Полный каталог</div>
        <div class="home-materials-banner-desc">Категории, подкатегории и все товары</div>
      </div>
      <div class="home-materials-banner-cta">${icon("chevronRight", "", 18)}</div>
    </button>
  `;
}

/* ===== SCREENS ===== */
function renderHome() {
  const q = (state.qHome || "").trim().toLowerCase();
  let list = state.masters || [];
  if (q) list = list.filter(function (m) { return masterMatches(m, q); });

  return `
    <div class="home-screen">
      <div class="home-brand mobile-only">Ustomarket</div>
      <div class="home-search-mobile mobile-only">${renderSearchBar()}</div>

      ${renderHomeMaterialsBanner()}

      ${
        state.loadingMasters && !state.masters.length
          ? `<div class="empty-state">Загрузка мастеров…</div>`
          : list.length
            ? `<div class="home-master-list">${list.map(homeMasterCard).join("")}</div>`
            : `<div class="empty-state">${q ? "Мастера не найдены." : "Пока нет мастеров."}</div>`
      }
    </div>
  `;
}

function renderMaterialsTab() {
  const q = (state.qMaterials || "").trim();
  const list = getMaterialsTabProductList();
  const categories = ["Все"].concat(getCategories().slice(0, 6));
  const catFilter = state.homeCategoryFilter || "Все";
  const searching = q.length >= 2;

  return `
    ${renderMaterialsCatalogBanner()}

    <div class="section-title">${searching ? "Результаты поиска" : "Популярные товары"}</div>
    <div class="chip-row">
      ${categories.map(function (c) {
        const active = (c === catFilter) ? " chip-active" : "";
        return `<button class="chip${active}" data-act="set-materials-cat" data-val="${escapeHtml(c)}">${escapeHtml(c)}</button>`;
      }).join("")}
    </div>

    ${
      state.searchLoading && searching
        ? `<div style="opacity:.7;padding:10px 6px;">Поиск…</div>`
        : state.loadingProducts && !state.products.length && !searching
        ? `<div style="opacity:.7;padding:10px 6px;">Загрузка…</div>`
        : list.length
          ? `<div class="grid grid-popular products-grid">${list.map(function (p) { return productCard(p, "materials"); }).join("")}</div>`
          : `<div style="opacity:.7;padding:10px 6px;">${searching ? "Ничего не найдено." : "Нет товаров."}</div>`
    }

    <div class="materials-quick-actions">
      <button type="button" class="btn btn-outline btn-block" data-act="nav" data-screen="chat_order">${icon("message", "", 18)} Чат-заказ</button>
      <button type="button" class="btn btn-outline btn-block" data-act="nav" data-screen="calculator">${icon("hammer", "", 18)} Калькулятор сметы</button>
    </div>
  `;
}

function renderPublishWork() {
  const loggedIn = isMasterUser();
  return `
    <div class="publish-screen">
      <p class="publish-subtitle">Добавляйте фото выполненных работ — клиенты увидят их в вашем профиле.</p>
      <div class="publish-center">
        <div class="publish-icon">${icon("folder", "", 44)}</div>
        <p class="publish-hint">${loggedIn
          ? "Скоро здесь можно будет публиковать работы прямо из приложения."
          : "Войдите как мастер, чтобы публиковать работы и управлять профилем."}</p>
        ${loggedIn ? "" : `<button type="button" class="btn btn-accent btn-block" data-act="nav" data-screen="master_auth">Войти как мастер</button>`}
      </div>
    </div>
  `;
}

/** Материалы: 3 шага */
function wrapCatalogLayout(html) {
  return `<div class="desk-layout">${renderCatalogSidebar()}<div class="desk-layout-main">${html}</div></div>`;
}

function renderMaterials() {
  const q = (state.qProducts || "").trim();
  const qLower = q.toLowerCase();
  const productSearchMode = q.length >= 2 && (state.materialsStep === "items" || state.materialsStep === "categories");

  if (productSearchMode && state.materialsStep === "categories") {
    const items = getMaterialsProductList();
    return wrapCatalogLayout(`
      <div class="section-title">Результаты поиска</div>
      ${state.searchLoading ? `<div class="empty-state">Поиск…</div>` : items.length
        ? `<div class="grid grid-catalog products-grid">${items.map(function (p) { return productCard(p, "products"); }).join("")}</div>`
        : `<div class="empty-state">Ничего не найдено.</div>`}
    `);
  }

  if (state.materialsStep === "categories") {
    let cats = getCategories();
    if (qLower) cats = cats.filter(c => c.toLowerCase().includes(qLower));
    const brandCats = ["Все"].concat(cats.slice(0, 8));
    const catalogBrand = state.catalogBrandFilter || "Все";
    let showCats = cats;
    if (catalogBrand !== "Все") showCats = cats.filter(c => c === catalogBrand);

    return wrapCatalogLayout(`
      <div class="section-title">Категории</div>
      <div class="chip-row chip-row-brands desk-only-hide">
        ${brandCats.map(c => `
          <button class="chip ${c === catalogBrand ? "chip-active" : ""}" data-act="set-catalog-brand" data-val="${escapeHtml(c)}">${escapeHtml(c)}</button>
        `).join("")}
      </div>

      ${
        state.loadingProducts && !state.products.length
          ? `<div class="empty-state">Загрузка…</div>`
          : showCats.length
            ? `<div class="cat-grid">
                ${showCats.map(c => `
                  <div class="cat-card" data-act="open-cat" data-cat="${escapeHtml(c)}">
                    <div class="cat-card-ico">${icon("box", "", 20)}</div>
                    <div class="name">${escapeHtml(c)}</div>
                  </div>
                `).join("")}
              </div>`
            : `<div class="empty-state">Категории не найдены.</div>`
      }
    `);
  }

  if (state.materialsStep === "subcategories") {
    const cat = state.selectedCategory || "";
    let subs = getSubcategories(cat);
    if (qLower) subs = subs.filter(s => s.toLowerCase().includes(qLower));

    return wrapCatalogLayout(`
      <div class="mat-topbar">
        <button type="button" class="icon-btn" data-act="mat-back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button>
        <div class="mat-title">${escapeHtml(cat)}</div>
      </div>

      ${
        subs.length
          ? `<div class="sub-list">
              ${subs.map(s => `
                <div class="sub-item" data-act="open-sub" data-sub="${escapeHtml(s)}">
                  <div class="sub-left">
                    <div class="sub-ico">${icon("layers", "", 18)}</div>
                    <div class="sub-name">${escapeHtml(s)}</div>
                  </div>
                  <div class="sub-arrow">${icon("chevronRight", "", 16)}</div>
                </div>
              `).join("")}
            </div>`
          : `<div class="empty-state">Подкатегории не найдены.</div>`
      }
    `);
  }

  const cat = state.selectedCategory || "";
  const sub = state.selectedSubcategory || "";
  let items = productSearchMode ? getMaterialsProductList() : getItems(cat, sub);
  if (!productSearchMode && qLower) items = items.filter(p => productMatches(p, qLower));

  return wrapCatalogLayout(`
    <div class="mat-topbar">
      <button type="button" class="icon-btn" data-act="mat-back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button>
      <div class="mat-title">${escapeHtml(cat)} / ${escapeHtml(sub)}</div>
    </div>

    ${
      state.searchLoading && productSearchMode
        ? `<div class="empty-state">Поиск…</div>`
        : items.length
        ? `<div class="grid grid-catalog products-grid">${items.map(p => productCard(p, "products")).join("")}</div>`
        : `<div class="empty-state">Товары не найдены.</div>`
    }
  `);
}

/** Мастера: категории -> список */
function renderMasters() {
  const q = (state.qMasters || "").trim().toLowerCase();

  // categories
  if (state.mastersStep === "categories") {
    let cats = getAllMasterCategories();
    if (q) cats = cats.filter(c => c.toLowerCase().includes(q));
    const allCats = ["ВСЕ МАСТЕРА"].concat(cats);

    return `
      <div class="section-title">Категории услуг</div>

      ${
        state.loadingMasters && !state.masters.length
          ? `<div style="opacity:.7;padding:10px 6px;">Загрузка…</div>`
          : allCats.length
            ? `<div class="cat-grid">
                ${allCats.map(c => `
                  <div class="cat-card ${c === "ВСЕ МАСТЕРА" ? "cat-card-all" : ""}" data-act="open-master-cat" data-cat="${escapeHtml(c)}">
                    <div class="name">${escapeHtml(c)}</div>
                  </div>
                `).join("")}
              </div>`
            : `<div style="opacity:.7;padding:10px 6px;">Категории не найдены.</div>`
      }
    `;
  }

  // list
  const cat = state.selectedMasterCategory || "ВСЕ МАСТЕРА";
  let list = state.masters.filter(m => masterHasCategory(m, cat));
  if (q) list = list.filter(m => masterMatches(m, q));
  if (state.searchCity) list = list.filter(m => masterMatchesCity(m, state.searchCity));

  return `
    <div class="mat-topbar">
      <button class="icon-btn" data-act="masters-back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button>
      <div class="mat-title">ВСЕ МАСТЕРА (${list.length})</div>
    </div>

    ${
      state.loadingMasters && !state.masters.length
        ? `<div style="opacity:.7;padding:10px 6px;">Загрузка…</div>`
        : list.length
          ? `<div class="m-list">${list.map(masterCard).join("")}</div>`
          : `<div style="opacity:.7;padding:10px 6px;">Мастера не найдены.</div>`
    }
  `;
}

/** Детальный экран мастера */
function renderMasterDetails() {
  const m = getMasterById(state.selectedMasterId);
  if (!m) {
    if (state.loadingMasters) {
      return `<div style="opacity:.7;padding:10px 6px;">Загрузка…</div>`;
    }
    return `<div style="opacity:.7;padding:10px 6px;">Мастер не найден</div>`;
  }

  const avatar = getMasterAvatar(m);
  const works = getMasterWorks(m);
  const cats = getMasterCategoriesList(m);

  const wa = (m.whatsapp || m.phone || "").replace(/\s+/g, "");
  const phone = (m.phone || "").trim();

  const photosForSwipe = works.length ? works : (avatar ? [avatar] : []);
  if (state.masterPhotoIndex >= photosForSwipe.length) state.masterPhotoIndex = 0;
  const mainPhoto = photosForSwipe[state.masterPhotoIndex] || "";

  const services = getMasterServices(m);

  return `
    <div class="pd">
      <div class="pd-topbar">
        <button class="icon-btn" data-act="master-back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button>
        <div></div>
      </div>

      <div class="pd-hero">
        <div class="img" data-swipe="master" data-act="open-master-photo" data-index="${state.masterPhotoIndex}">
          ${
            mainPhoto
              ? `<img src="${mainPhoto}" alt="${escapeHtml(m.name)}">`
              : `<div class="pd-placeholder">${icon("hammer", "pd-placeholder-ico", 48)}</div>`
          }
        </div>

        ${
          works.length > 1
            ? `<div class="pd-thumbs">
                ${works.map((ph, idx) => `
                  <div class="pd-thumb"
                       data-act="set-master-photo"
                       data-index="${idx}"
                       style="${idx===state.masterPhotoIndex ? 'border-color: rgba(17,17,17,.35);' : ''}">
                    <img src="${ph}" alt="">
                  </div>
                `).join("")}
              </div>`
            : ``
        }
      </div>

      <div class="pd-info">
        <div class="pd-name">${escapeHtml(m.name || "Мастер")}</div>

        <div style="margin-top:8px;display:flex;gap:8px;flex-wrap:wrap;">
          ${cats.length ? cats.map(c => `<div class="m-tag">${escapeHtml(c)}</div>`).join("") : `<div class="m-tag">Мастер</div>`}
        </div>

        ${m.description ? `<div class="pd-desc">${escapeHtml(m.description)}</div>` : `<div class="pd-desc" style="opacity:.7">Описание пока не заполнено.</div>`}

        ${m.price_from != null ? `<div style="margin-top:8px;opacity:.85;font-weight:950;">от ${formatPriceSmn(m.price_from)}</div>` : ``}

        <div style="margin-top:12px;display:flex;gap:10px;">
          ${wa ? `<a class="btn btn-accent pd-contact-btn" href="https://wa.me/${wa}" target="_blank" rel="noopener">${icon("message", "", 18)} WhatsApp</a>` : ``}
          ${phone ? `<button class="btn btn-ghost pd-contact-btn" data-act="call" data-phone="${escapeHtml(phone)}">${icon("phone", "", 18)} Позвонить</button>` : ``}
        </div>

        <div class="section-title" style="margin-top:14px">Прайс</div>
        ${
          services.length
            ? `<div style="display:flex;flex-direction:column;gap:10px;">
                ${services.map(s => `
                  <div style="border:1px solid rgba(0,0,0,.08);background:#fff;border-radius:16px;padding:12px;display:flex;justify-content:space-between;gap:10px;">
                    <div style="font-weight:900;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                      ${escapeHtml(s.name)}
                    </div>
                    <div style="font-weight:950;opacity:.9;flex-shrink:0;">
                      ${s.price == null ? "—" : formatPriceSmn(s.price)}
                    </div>
                  </div>
                `).join("")}
              </div>`
            : `<div style="opacity:.7;padding:10px 6px;">Прайс пока не заполнен.</div>`
        }

        <div class="section-title" style="margin-top:14px">Фото работ</div>
        ${
          works.length
            ? `<div class="grid">
                ${works.slice(0, 6).map((ph, idx) => `
                  <div class="p-card">
                    <div class="p-img" data-act="open-works-lightbox" data-index="${idx}">
                      <img src="${ph}" alt="">
                    </div>
                    <div class="p-body">
                      <div class="p-name" style="opacity:.8;">Работа ${idx + 1}</div>
                    </div>
                  </div>
                `).join("")}
              </div>`
            : `<div style="opacity:.7;padding:10px 6px;">Фото работ пока нет.</div>`
        }
      </div>
    </div>
  `;
}

/** Детальный экран товара */
function buildRecommendations(current) {
  var all = (state.products || []).concat(state.recommended || []);
  var seen = {};
  all = all.filter(function (p) {
    if (p.id === current.id || seen[p.id]) return false;
    seen[p.id] = true;
    return true;
  });
  var sub = (current.subcategory || "").trim().toLowerCase();
  var cat = (current.category || "").trim().toLowerCase();

  var rec = sub ? all.filter(function (p) { return (p.subcategory || "").trim().toLowerCase() === sub; }) : [];

  if (rec.length < 6 && cat) {
    var byCat = all.filter(function (p) { return (p.category || "").trim().toLowerCase() === cat; });
    var ids = {};
    rec.forEach(function (x) { ids[x.id] = true; });
    for (var i = 0; i < byCat.length && rec.length < 6; i++) {
      if (!ids[byCat[i].id]) { rec.push(byCat[i]); ids[byCat[i].id] = true; }
    }
  }

  if (rec.length < 6) {
    var ids2 = {};
    rec.forEach(function (x) { ids2[x.id] = true; });
    for (var j = 0; j < all.length && rec.length < 6; j++) {
      if (!ids2[all[j].id]) { rec.push(all[j]); ids2[all[j].id] = true; }
    }
  }

  return rec.slice(0, 6);
}

function renderProductVariants(p) {
  var colors = productColors(p);
  var sizes = productSizes(p);
  if (!colors.length && !sizes.length) return "";

  var sel = getDetailVariantSelection(p);
  var parts = [];
  if (sel.size) parts.push(sel.size.name);
  if (sel.color) parts.push(sel.color.name);

  var html = "";

  if (parts.length) {
    html += `<div class="pd-selected-variant">`;
    if (sel.color) {
      html += `<span class="pd-selected-dot${isLightColor(colorHex(sel.color)) ? " is-light" : ""}" style="background:${escapeHtml(colorHex(sel.color))}"></span>`;
    }
    html += `<span>Выбрано: ${escapeHtml(parts.join(", "))}</span></div>`;
  }

  if (colors.length) {
    html += `
      <div class="pd-variant-block">
        <div class="pd-variant-label">Цвет</div>
        <div class="pd-colors">
          ${colors.map(function (c, idx) {
            var hex = colorHex(c);
            var active = idx === state.detailsColorIndex ? " is-active" : "";
            var light = isLightColor(hex) ? " is-light" : "";
            return `<button type="button" class="pd-color${active}${light}" data-act="select-detail-color" data-index="${idx}" style="background:${escapeHtml(hex)}" title="${escapeHtml(c.name || "")}" aria-label="${escapeHtml(c.name || "Цвет")}"><span class="pd-color-ring"></span></button>`;
          }).join("")}
        </div>
        ${sel.color ? `<div class="pd-variant-name">${escapeHtml(sel.color.name)}</div>` : ""}
      </div>`;
  }

  if (sizes.length) {
    html += `
      <div class="pd-variant-block">
        <div class="pd-variant-label">Размер / объём</div>
        <div class="pd-sizes">
          ${sizes.map(function (s, idx) {
            var active = idx === state.detailsSizeIndex ? " is-active" : "";
            return `<button type="button" class="pd-size${active}" data-act="select-detail-size" data-index="${idx}"><span class="pd-size-name">${escapeHtml(s.name)}</span><span class="pd-size-price">${formatPriceSmn(s.price)}</span></button>`;
          }).join("")}
        </div>
      </div>`;
  }

  return `<div class="pd-variants">${html}</div>`;
}

function renderDetailConsumption(p) {
  if (!isCalculatorProduct(p)) return "";
  var enriched = enrichProductForCalc(p);
  var sel = getDetailVariantSelection(p);
  var packaging = enriched.packaging;
  var price = Number(sel.price) || enriched.price;
  if (sel.sizeName) {
    var m = String(sel.sizeName).match(/(\d+(?:[.,]\d+)?)/);
    if (m) {
      var v = parseFloat(String(m[1]).replace(",", "."));
      if (isFinite(v) && v > 0) packaging = v;
    }
  }
  var product = Object.assign({}, enriched, { packaging: packaging, price: price });
  var length = calcClamp(state.detailsCalcLength || 4, 1, 30);
  var width = calcClamp(state.detailsCalcWidth || 4, 1, 30);
  var height = 3;
  var doors = 1;
  var windows = 1;
  var gross = (length + width) * 2 * height;
  var openings = doors * CALC_DOOR_AREA_M2 + windows * CALC_WINDOW_AREA_M2;
  var wallArea = Math.max(0, gross - openings);
  var packs = Math.ceil((wallArea * product.consumption) / packaging);
  if (!isFinite(packs) || packs < 0) packs = 0;
  var cost = packs * price;
  if (!isFinite(cost) || cost < 0) cost = 0;

  var presets = CALC_ROOM_PRESETS.map(function (pr) {
    var active = Math.abs(length - pr.length) < 0.01 && Math.abs(width - pr.width) < 0.01;
    return `<button type="button" class="calc-chip${active ? " is-active" : ""}" data-act="calc-detail-preset" data-length="${pr.length}" data-width="${pr.width}">${pr.label}</button>`;
  }).join("");

  return `
    <div class="pd-calc">
      <div class="pd-calc-title">Расчёт расхода</div>
      <div class="pd-calc-norm">Норма: ${product.consumption} кг/м² · упак. ${packaging} кг (${escapeHtml(product.unitType)})</div>
      <div class="calc-chips" style="margin:10px 0">${presets}</div>
      <div class="pd-calc-row"><span>Площадь стен (1 дв. + 1 ок.)</span><strong>${calcFormatDim(wallArea)} м²</strong></div>
      <div class="pd-calc-row"><span>Требуемое количество</span><strong>${packs} ${escapeHtml(product.unitType)}</strong></div>
      <div class="pd-calc-row pd-calc-row--total"><span>Стоимость материалов</span><strong>${formatSomoni(cost)} сомони</strong></div>
      <button type="button" class="btn btn-outline pd-calc-btn" data-act="nav" data-screen="calculator" data-calc-product="${escapeHtml(String(p.id))}">Открыть полный калькулятор</button>
    </div>
  `;
}

function renderDetails() {
  var p = getProductById(state.selectedProductId);
  if (!p) return "<div style=\"opacity:.7;padding:10px 6px;\">Товар не найден</div>";

  const photos = (p.photos || []).map(fullUrl);
  if (state.detailsPhotoIndex >= photos.length) state.detailsPhotoIndex = 0;
  const main = photos[state.detailsPhotoIndex] || photos[0] || "";

  const rec = buildRecommendations(p);
  const sel = getDetailVariantSelection(p);

  return `
    <div class="pd pd--product">
      <div class="pd-topbar">
        <button class="icon-btn" data-act="back" aria-label="Назад">${icon("chevronLeft", "", 18)}</button>
        <div class="pd-breadcrumb">${p.category ? escapeHtml(p.category) : "Каталог"}${p.subcategory ? ` / ${escapeHtml(p.subcategory)}` : ""}</div>
      </div>

      <div class="pd-layout">
        <div class="pd-hero">
          <div class="img" data-act="open-photo" data-index="${state.detailsPhotoIndex}" data-swipe="details">
            ${main ? `<img src="${main}" alt="${escapeHtml(p.name)}">` : ``}
          </div>

          ${
            photos.length > 1
              ? `<div class="pd-thumbs">
                  ${photos.map((ph, idx) => `
                    <div class="pd-thumb" data-act="set-detail-photo" data-index="${idx}" style="${idx===state.detailsPhotoIndex ? 'border-color: rgba(17,17,17,.35);' : ''}">
                      <img src="${ph}" alt="">
                    </div>
                  `).join("")}
                </div>`
              : ``
          }
        </div>

        <div class="pd-info">
          <div class="pd-name">${escapeHtml(p.name)}</div>
          <div class="pd-price">${formatPriceSmn(sel.price)}${p.unit ? ` <span class="pd-unit">/ ${escapeHtml(p.unit)}</span>` : ""}</div>
          <div class="pd-meta">
            ${p.category ? escapeHtml(p.category) : ""}${p.subcategory ? ` • ${escapeHtml(p.subcategory)}` : ""}
            ${p.articul ? ` • Арт: ${escapeHtml(p.articul)}` : ""}
          </div>

          ${renderProductVariants(p)}

          ${p.description ? `<div class="pd-desc">${escapeHtml(p.description)}</div>` : `<div class="pd-desc muted-text">Описание пока не заполнено.</div>`}

          ${renderDetailConsumption(p)}

          <div class="pd-actions">
            <button class="btn-buy" data-act="buy-now-detail" data-id="${p.id}">Купить сейчас</button>
            <button class="btn-cart" data-act="add-detail" data-id="${p.id}">В корзину</button>
          </div>
        </div>
      </div>

      <div class="pd-rec">
        <div class="section-title">Рекомендуем также</div>
        ${rec.length ? `<div class="grid grid-rec">${rec.map(x => productCard(x, "details")).join("")}</div>`
                     : `<div class="empty-state">Пока нет похожих товаров.</div>`}
      </div>
    </div>
  `;
}

/* ===== Advanced Cart (photo + swipe actions + qty controls) ===== */
function renderCart() {
  if (!state.cart.length) return `<div style="opacity:.7;padding:18px 6px;">Корзина пуста</div>`;

  const total = cartTotal();

  return `
    <div class="cart-header-row">
      <span class="cart-select-all">Все товары</span>
      <button type="button" class="cart-clear-all" data-act="clear-cart">Очистить всё</button>
    </div>

    <div class="cart-items">
      ${state.cart.map((it) => {
        const cKey = cartItemKey(it);
        const open = state.cartSwipeOpenId === cKey;
        const lineTotal = Number(it.price || 0) * Number(it.qty || 0);
        const photo = it.photo || "";
        const variantLine = [it.sizeName, it.colorName].filter(Boolean).join(" • ");
        return `
          <div
            data-swipe="cart"
            data-cart-key="${escapeHtml(cKey)}"
            style="
              position:relative;
              border-radius:18px;
              overflow:hidden;
              border:1px solid rgba(0,0,0,.08);
              background:#ffffff;
              box-shadow:0 16px 45px rgba(0,0,0,.55);
              touch-action: pan-y;
            "
          >
            <div style="
              position:absolute; inset:0;
              display:flex; justify-content:flex-end; align-items:stretch;
              background:rgba(220,38,38,.18);
            ">
              <button
                class="btn"
                data-act="remove-item"
                data-cart-key="${escapeHtml(cKey)}"
                style="
                  width:104px;
                  border-radius:0;
                  background:#111111;
                  color:#ffffff;
                  font-weight:950;
                "
              >Удалить</button>
            </div>

            <div
              style="
                position:relative;
                transform: translateX(${open ? "-104px" : "0px"});
                transition: transform .18s ease;
                padding:12px;
                display:flex;
                gap:12px;
                align-items:flex-start;
                background:#ffffff;
              "
            >
              <div style="
                width:62px;height:62px;border-radius:16px;overflow:hidden;
                border:1px solid rgba(255,255,255,.10);
                background:rgba(0,0,0,.04);
                flex-shrink:0;
              ">
                ${photo ? `<img src="${photo}" alt="" style="width:100%;height:100%;object-fit:cover;display:block">` : ``}
              </div>

              <div style="flex:1;min-width:0;">
                <div style="font-weight:950;line-height:1.2;">${escapeHtml(it.name)}</div>
                <div style="opacity:.7;font-size:12px;margin-top:4px;">
                  ${formatPriceSmn(it.price)}${it.unit ? ` / ${escapeHtml(it.unit)}` : ""}
                  ${variantLine ? `<span class="cart-variant-line"> • ${escapeHtml(variantLine)}</span>` : ""}
                </div>

                <div style="display:flex;align-items:center;justify-content:space-between;margin-top:10px;gap:10px;">
                  <div style="display:flex;align-items:center;gap:8px;">
                    <button class="btn btn-ghost" data-act="qty-minus" data-cart-key="${escapeHtml(cKey)}" style="width:44px;padding:10px 0;border-radius:14px;">−</button>
                    <div style="min-width:34px;text-align:center;font-weight:950;">${it.qty}</div>
                    <button class="btn btn-ghost" data-act="qty-plus" data-cart-key="${escapeHtml(cKey)}" style="width:44px;padding:10px 0;border-radius:14px;">+</button>
                  </div>

                  <div style="font-weight:950;">
                    ${formatPriceSmn(lineTotal)}
                  </div>
                </div>

                <div style="margin-top:8px;display:flex;gap:8px;justify-content:flex-end;">
                  <button class="btn btn-ghost" data-act="cart-close-swipe" style="padding:8px 10px;border-radius:14px;">Скрыть</button>
                  <button class="btn btn-ghost" data-act="cart-open-swipe" data-cart-key="${escapeHtml(cKey)}" style="padding:8px 10px;border-radius:14px;">⋯</button>
                </div>
              </div>
            </div>
          </div>
        `;
      }).join("")}
    </div>

    <div class="cart-footer">
      <div class="cart-total-label">Итого к оплате: (${state.cart.length})</div>
      <div class="cart-total-value">${formatPriceSmn(total)}</div>
      <button class="btn btn-accent btn-checkout" data-act="checkout">Оформить</button>
    </div>
  `;
}

function renderCheckout() {
  const c = state.checkout;
  const total = cartTotal();

  return `
    <div class="checkout-form">
      <div class="checkout-section">
        <div class="checkout-section-title">КОНТАКТНЫЕ ДАННЫЕ</div>
        <input class="checkout-input" data-check="name" value="${escapeHtml(c.name)}" placeholder="Ваше имя">
        <div class="checkout-phone-wrap">
          <span class="checkout-phone-prefix">+992</span>
          <input class="checkout-input checkout-phone-input" data-check="phone" value="${escapeHtml(c.phone)}" placeholder="Введите номер">
        </div>
      </div>

      <div class="checkout-section">
        <div class="checkout-section-title">ДЕТАЛИ ЗАКАЗА</div>
        <div class="checkout-label">Способ получения</div>
        <div class="checkout-toggles">
          <button class="btn ${c.deliveryType==='delivery'?'btn-accent':'btn-ghost'}" data-act="set-delivery" data-val="delivery">Доставка</button>
          <button class="btn ${c.deliveryType==='pickup'?'btn-accent':'btn-ghost'}" data-act="set-delivery" data-val="pickup">Самовывоз</button>
        </div>
        ${c.deliveryType === "delivery" ? `
        <div class="checkout-label">Адрес доставки</div>
        <input class="checkout-input" data-check="address" value="${escapeHtml(c.address)}" placeholder="Введите адрес...">
        ` : ""}
        <div class="checkout-label">Комментарий</div>
        <textarea class="checkout-input checkout-comment" data-check="comment" placeholder="">${escapeHtml(c.comment)}</textarea>
      </div>

      ${state.checkoutError ? `<div class="checkout-error">${escapeHtml(state.checkoutError)}</div>` : ""}
      ${state.checkoutOk ? `<div class="checkout-success">Заказ отправлен ✅ ${state.lastOrderId ? `Номер: ${escapeHtml(state.lastOrderId)}` : ""}</div><button class="btn btn-accent" data-act="nav" data-screen="home">На главную</button>` : ""}
    </div>

    ${!state.checkoutOk ? `
    <div class="checkout-sticky">
      <div class="checkout-sticky-left">
        <div class="checkout-sticky-label">Итого к оплате:</div>
        <div class="checkout-sticky-total">${formatPriceSmn(total)}</div>
      </div>
      <button class="btn btn-accent btn-checkout-submit" data-act="submit-order" ${state.checkoutLoading ? "disabled" : ""}>${state.checkoutLoading ? "Отправка…" : "ОФОРМИТЬ ЗАКАЗ"}</button>
    </div>
    ` : ""}
  `;
}

function isDesktopLayout() {
  try {
    return window.matchMedia("(min-width: 1024px)").matches;
  } catch (_) {
    return false;
  }
}

function profileLangLabel() {
  return state.profileLang === "tj" ? "Тоҷикӣ" : "Русский";
}

function aboutI18n(lang) {
  if (lang === "tj") {
    return {
      title: "Дар бораи мо",
      company: "ООО ОРОИШ 2015",
      desc: "Мо зиёда аз 20 сол дар соҳаи сохтмонӣ оптом ва чакана савдои маводҳои сохтмонӣ мекунем.",
      years: function (y) { return "Дар бозор аллакай " + y + " сол"; },
      social: "Мо дар шабакаҳои иҷтимоӣ",
      socialEmpty: "Пайвандҳои шабакаҳои иҷтимоӣ ҳанӯз дар админка илова нашудаанд.",
      loading: "Боркунӣ…",
    };
  }
  return {
    title: "О нас",
    company: "ООО ОРОИШ 2015",
    desc: "Мы уже более 20 лет занимаемся оптовой и розничной торговлей в сфере строительных материалов.",
    years: function (y) { return "На рынке уже " + y + " лет"; },
    social: "Мы в соцсетях",
    socialEmpty: "Ссылки на соцсети пока не добавлены в админке.",
    loading: "Загрузка…",
  };
}

function renderProfileContentPanel() {
  const section = state.profileSection;
  if (section === "orders") return renderOrders();
  if (section === "notifications") return renderNotificationsScreen();
  if (section === "projects") {
    return `
      <div class="profile-projects-panel">
        <div class="section-title">Мои проекты</div>
        <div class="profile-content-empty">Сохранённые строительные объекты появятся здесь. Откройте приложение Ustobozor для полного функционала проектов.</div>
      </div>
    `;
  }
  if (section === "addresses") {
    return `
      <div class="profile-address-form">
        <div class="section-title">Адреса доставки</div>
        <textarea placeholder="Введите адрес доставки..." data-check="address">${escapeHtml((state.checkout && state.checkout.address) || "")}</textarea>
        <div style="margin-top:12px">
          <button class="btn btn-accent" type="button" data-act="save-address">Сохранить адрес</button>
        </div>
      </div>
    `;
  }
  if (section === "language") {
    return `
      <div class="profile-menu-block">
        <button class="profile-menu-row ${state.profileLang === "ru" ? "active" : ""}" data-act="set-lang" data-val="ru" type="button">
          <span>Русский</span>
          ${state.profileLang === "ru" ? `<span class="profile-menu-trail">${icon("check", "", 16)}</span>` : ""}
        </button>
        <button class="profile-menu-row ${state.profileLang === "tj" ? "active" : ""}" data-act="set-lang" data-val="tj" type="button">
          <span>Тоҷикӣ</span>
          ${state.profileLang === "tj" ? `<span class="profile-menu-trail">${icon("check", "", 16)}</span>` : ""}
        </button>
      </div>
    `;
  }
  if (section === "about") return renderAbout();
  return `<div class="profile-content-empty">Выберите раздел в меню слева</div>`;
}

function renderProfile() {
  const profilePhone = (state.checkout && state.checkout.phone) ? state.checkout.phone : "";
  const displayPhone = profilePhone.trim() || "—";
  const displayId = profilePhone.replace(/\D/g, "").slice(-9) || "—";
  const me = state.profileMe;
  const supportWa = (me && me.support_whatsapp) ? me.support_whatsapp : "992872148008";
  const waLink = "https://wa.me/" + supportWa.replace(/\D/g, "");
  const darkOn = state.profileTheme === "dark";
  const section = state.profileSection;
  const mobilePanel = !isDesktopLayout() && (section === "language" || section === "projects");

  function menuRow(id, iconName, label, extra) {
    const active = section === id ? " active" : "";
    return `
      <button class="profile-menu-row${active}" data-act="profile-nav" data-section="${id}" type="button">
        <span class="profile-menu-ico">${icon(iconName, "", 18)}</span>
        <span>${label}</span>
        ${extra || `<span class="profile-menu-trail">${icon("chevronRight", "", 16)}</span>`}
      </button>
    `;
  }

  return `
    <div class="profile-block">
      <div class="profile-layout profile-container${mobilePanel ? " profile-layout--panel" : ""}">
        <aside class="profile-aside">
          ${state.profileLoading ? `<div class="profile-loading">Загрузка…</div>` : ""}
          <div class="profile-user">
            <div class="profile-avatar"></div>
            <div class="profile-user-info">
              <div class="profile-id">${escapeHtml(me && me.name ? me.name : displayId)}</div>
              <div class="profile-phone">+992 ${escapeHtml(displayPhone || (me && me.phone ? me.phone.replace(/\D/g, "").slice(-9) : "—"))}</div>
            </div>
          </div>

          ${isMasterUser() ? `
          <div class="profile-card">
            <div class="profile-master-badge">✓ Вы вошли</div>
            ${MASTER_BARCODE_ENABLED ? `
            <div class="profile-barcode-block">
              <div class="profile-barcode-label">Код мастера (QR)</div>
              ${renderMasterBarcode(me)}
            </div>
            ` : ""}
            ${MASTER_POINTS_ENABLED ? `
            <button class="profile-balance-btn" type="button">
              <span class="profile-balance-icon">◆</span>
              <span>Ваш баланс</span>
              <span class="profile-balance-value">${Number(me.points || 0)} баллов</span>
            </button>
            ` : ""}
            ${(me.debt && Number(me.debt) > 0) ? `<div class="profile-debt">Долг: ${formatPriceSmn(me.debt)}</div>` : ""}
          </div>
          ` : isClientUser() ? `
          <div class="profile-card profile-card--client">
            <div class="profile-client-badge">✓ Вы вошли</div>
            <p class="profile-guest-hint">Заказы и адреса сохраняются для вашего номера.</p>
          </div>
          ` : `
          <div class="profile-guest-hint">Войдите по номеру телефона — заказы и объявления в одном аккаунте.</div>
          <button class="btn btn-accent profile-login-btn" data-act="nav" data-screen="client_auth" data-auth-mode="master" type="button">Войти</button>
          `}

          <div class="profile-menu-block">
            ${menuRow("orders", "box", "Мои заказы")}
            ${menuRow("projects", "folder", "Мои проекты")}
            ${menuRow("addresses", "mapPin", "Адреса доставки")}
            ${menuRow("notifications", "bell", "Уведомления", state.profileUnreadCount > 0 ? `<span class="profile-badge">${state.profileUnreadCount}</span>` : `<span class="profile-menu-trail">${icon("chevronRight", "", 16)}</span>`)}
            ${menuRow("about", "globe", aboutI18n(state.profileLang).title)}
          </div>

          <div class="profile-menu-block">
            ${menuRow("language", "globe", "Язык приложения", `<span class="profile-menu-trail">${escapeHtml(profileLangLabel())} ${icon("chevronRight", "", 16)}</span>`)}
            <button class="profile-menu-row" data-act="toggle-theme" type="button">
              <span class="profile-menu-ico">${icon(darkOn ? "moon" : "sun", "", 18)}</span>
              <span>Тёмная тема</span>
              <span class="profile-theme-switch ${darkOn ? "on" : ""}" aria-hidden="true"></span>
            </button>
          </div>

          <div class="profile-menu-block">
            <a class="profile-menu-row" href="${escapeHtml(waLink)}" target="_blank" rel="noopener">
              <span class="profile-menu-ico">${icon("message", "", 18)}</span>
              <span>Поддержка в WhatsApp</span>
              <span class="profile-menu-trail">${icon("chevronRight", "", 16)}</span>
            </a>
          </div>

          <button class="btn profile-logout" data-act="profile-logout" type="button"${isLoggedIn() ? "" : " hidden"}>Выйти</button>
        </aside>

        <div class="profile-content">
          ${renderProfileContentPanel()}
        </div>
      </div>
    </div>
  `;
}

function renderOrders() {
  const orders = state.profileOrders || [];
  if (orders.length === 0) return `<div class="profile-orders-empty">Заказов пока нет.</div>`;
  return `
    <div class="profile-orders-list">
      ${orders.map(function (o) {
        const statusText = o.status === "completed" ? "Выполнен" : o.status === "new" ? "Новый" : o.status === "cancelled" ? "Отменён" : (o.status || "");
        return `
          <div class="profile-order-card">
            <div class="profile-order-head">
              <span class="profile-order-id">Заказ #${o.id}</span>
              <span class="profile-order-status">${escapeHtml(statusText)}</span>
            </div>
            <div class="profile-order-date">${escapeHtml(o.created_at || "")}</div>
            <div class="profile-order-total">${formatPriceSmn(o.total_price)}</div>
            ${(o.items && o.items.length) ? `<div class="profile-order-items">${o.items.slice(0, 3).map(function (i) { return escapeHtml(i.name || ""); }).join(", ")}${o.items.length > 3 ? "…" : ""}</div>` : ""}
          </div>
        `;
      }).join("")}
    </div>
  `;
}

function renderNotificationsScreen() {
  const list = state.profileNotifications || [];
  if (list.length === 0) return `<div class="profile-orders-empty">Нет уведомлений.</div>`;
  return `
    <div class="profile-notifications-list">
      ${list.map(function (n) {
        const unread = !n.read_at;
        return `
          <div class="profile-notif-card ${unread ? "profile-notif-unread" : ""}">
            <div class="profile-notif-type">${escapeHtml(n.type === "debt" ? "Долг" : n.title || n.type || "Уведомление")}</div>
            <div class="profile-notif-body">${escapeHtml(n.body || "")}</div>
            <div class="profile-notif-date">${escapeHtml(n.created_at || "")}</div>
          </div>
        `;
      }).join("")}
    </div>
  `;
}

function renderAbout() {
  const about = state.siteAbout || {};
  const txt = aboutI18n(state.profileLang);
  const socials = [
    { key: "instagram_url", label: "Instagram", icon: "📷" },
    { key: "tiktok_url", label: "TikTok", icon: "🎵" },
    { key: "whatsapp_url", label: "WhatsApp", icon: "💬" },
  ];

  return `
    <div class="about-block">
      ${state.siteAboutLoading ? `<div class="profile-loading">${txt.loading}</div>` : ""}
      <div class="about-card">
        <div class="about-company">${escapeHtml(txt.company)}</div>
        <p class="about-text">${escapeHtml(txt.desc)}</p>
        <div class="about-years">${txt.years(Number(about.years_experience || 20))}</div>
      </div>
      <div class="about-social-title">${txt.social}</div>
      <div class="about-social-list">
        ${socials.map(function (s) {
          const url = normalizeSocialUrl(about[s.key]);
          if (!url) return "";
          return `<a class="about-social-row" href="${escapeHtml(url)}" target="_blank" rel="noopener"><span>${s.icon}</span><span>${s.label}</span><span class="profile-arrow">›</span></a>`;
        }).join("") || `<div class="profile-orders-empty">${txt.socialEmpty}</div>`}
      </div>
    </div>
  `;
}

/* ===== RENDER ===== */
function renderAddressSheet() {
  if (!state.addressSheetOpen) return "";
  return `
    <div class="sheet-backdrop" data-act="close-address-sheet" aria-hidden="true"></div>
    <div class="bottom-sheet" role="dialog" aria-label="Адреса доставки">
      <h2 class="bottom-sheet-title">Адреса доставки</h2>
      <textarea placeholder="Введите адрес доставки..." data-check="address">${escapeHtml((state.checkout && state.checkout.address) || "")}</textarea>
      <div class="bottom-sheet-actions">
        <button class="btn btn-accent" type="button" data-act="save-address">Сохранить</button>
        <button class="btn btn-ghost" type="button" data-act="close-address-sheet">Закрыть</button>
      </div>
    </div>
  `;
}

function renderMasterAuth() {
  const step = state.authStep;
  const err = state.authError ? `<div class="auth-error">${escapeHtml(state.authError)}</div>` : "";
  const loading = state.authLoading ? " disabled" : "";

  if (step === "phone") {
    return `
      <div class="auth-panel">
        <h2 class="auth-title">Вход</h2>
        <p class="auth-desc">Введите номер телефона (+992)</p>
        ${err}
        <label class="field"><span>Телефон</span><input data-auth="phone" inputmode="numeric" placeholder="98XXXXXXX" value="${escapeHtml(state.authPhone)}"></label>
        <button class="btn btn-accent btn-block" data-act="auth-check-phone"${loading}>Продолжить</button>
      </div>`;
  }
  if (step === "password") {
    return `
      <div class="auth-panel">
        <h2 class="auth-title">Введите пароль</h2>
        ${err}
        <label class="field"><span>Пароль</span><input type="password" data-auth="password" minlength="4" autocomplete="current-password" value="${escapeHtml(state.authPassword)}"></label>
        <button class="btn btn-accent btn-block" data-act="auth-login"${loading}>Войти</button>
        <button class="btn btn-ghost btn-block" data-act="auth-back-phone" type="button">Другой номер</button>
      </div>`;
  }
  if (step === "register") {
    return `
      <div class="auth-panel">
        <h2 class="auth-title">Регистрация</h2>
        <p class="auth-desc">Заполните данные для регистрации.</p>
        ${err}
        <label class="field"><span>Имя</span><input data-auth="name" value="${escapeHtml(state.authName)}"></label>
        <label class="field"><span>Пароль</span><input type="password" data-auth="password" minlength="4" autocomplete="new-password" placeholder="мин. 4 символа" value="${escapeHtml(state.authPassword)}"></label>
        <label class="field"><span>Повтор пароля</span><input type="password" data-auth="confirm" minlength="4" autocomplete="new-password" value="${escapeHtml(state.authConfirm)}"></label>
        <button class="btn btn-accent btn-block" data-act="auth-register"${loading}>Зарегистрироваться</button>
        <button class="btn btn-ghost btn-block" data-act="auth-back-phone" type="button">Другой номер</button>
      </div>`;
  }
  return `
    <div class="auth-panel">
      <h2 class="auth-title">Новый пароль</h2>
      <p class="auth-desc">Администратор сбросил пароль. Задайте новый.</p>
      ${err}
      <label class="field"><span>Пароль</span><input type="password" data-auth="password" value="${escapeHtml(state.authPassword)}"></label>
      <label class="field"><span>Повтор пароля</span><input type="password" data-auth="confirm" value="${escapeHtml(state.authConfirm)}"></label>
      <button class="btn btn-accent btn-block" data-act="auth-set-password"${loading}>Сохранить</button>
      <button class="btn btn-ghost btn-block" data-act="auth-back-phone" type="button">Другой номер</button>
    </div>`;
}

function renderChatInvoice(draft) {
  const items = (draft && draft.items) || [];
  const total = draft && draft.total_price != null ? draft.total_price : items.reduce(function (s, i) { return s + Number(i.line_total || i.price * i.qty || 0); }, 0);
  return `
    <div class="chat-invoice">
      <div class="chat-invoice-title">Накладная</div>
      ${items.map(function (it, idx) {
        return `<div class="chat-invoice-row"><span>${escapeHtml(it.name)} × ${it.qty} ${escapeHtml(it.unit || "")}</span><span>${formatPriceSmn(it.line_total || it.price * it.qty)}</span></div>`;
      }).join("")}
      <div class="chat-invoice-total">Итого: ${formatPriceSmn(total)}</div>
      <div class="chat-invoice-actions">
        <button class="btn btn-outline btn-sm" data-act="chat-action" data-action="reset" type="button">Сбросить</button>
        <button class="btn btn-accent btn-sm" data-act="chat-checkout" type="button">Оформить заказ</button>
      </div>
    </div>`;
}

function renderChatPick(msg) {
  const opts = msg.options || [];
  if (!opts.length) return `<div class="chat-bubble chat-bubble--system">${escapeHtml(msg.prompt || "Товар не найден")}</div>`;
  return `
    <div class="chat-pick">
      <div class="chat-bubble chat-bubble--system">${escapeHtml(msg.prompt || "Выберите вариант")}</div>
      <div class="chat-pick-options">
        ${opts.map(function (o) {
          return `<button class="chat-pick-btn" data-act="chat-pick" data-id="${o.id}" data-idx="${msg.itemIndex}" type="button">${escapeHtml(o.label || o.name)}</button>`;
        }).join("")}
      </div>
    </div>`;
}

function renderChatOrder() {
  const chat = state.chat;
  const msgs = chat.messages || [];
  const checkoutBlock = chat.checkoutOpen ? `
    <div class="chat-checkout">
      <div class="chat-checkout-title">Оформление заказа</div>
      ${state.checkoutError ? `<div class="auth-error">${escapeHtml(state.checkoutError)}</div>` : ""}
      <label class="field"><span>Имя</span><input data-check="name" value="${escapeHtml(state.checkout.name || "")}"></label>
      <label class="field"><span>Телефон</span><input data-check="phone" inputmode="tel" value="${escapeHtml(state.checkout.phone || "")}"></label>
      <label class="field"><span>Адрес</span><input data-check="address" value="${escapeHtml(state.checkout.address || "")}"></label>
      <div class="seg-row">
        <button class="seg ${state.checkout.deliveryType === "delivery" ? "active" : ""}" data-act="set-delivery" data-val="delivery" type="button">Доставка</button>
        <button class="seg ${state.checkout.deliveryType === "pickup" ? "active" : ""}" data-act="set-delivery" data-val="pickup" type="button">Самовывоз</button>
      </div>
      <div class="seg-row">
        <button class="seg ${state.checkout.payment === "cash" ? "active" : ""}" data-act="set-pay" data-val="cash" type="button">Наличные</button>
        <button class="seg ${state.checkout.payment === "card" ? "active" : ""}" data-act="set-pay" data-val="card" type="button">Карта</button>
      </div>
      <button class="btn btn-accent btn-block" data-act="chat-submit" type="button"${chat.loading ? " disabled" : ""}>Подтвердить заказ</button>
      <button class="btn btn-ghost btn-block" data-act="chat-checkout-close" type="button">Отмена</button>
    </div>` : "";

  return `
    <div class="chat-order">
      <div class="chat-messages" id="chat-messages">
        ${msgs.map(function (m) {
          if (m.type === "invoice") return renderChatInvoice(m.draft);
          if (m.type === "pick") return renderChatPick(m);
          const cls = m.role === "user" ? "chat-bubble--user" : "chat-bubble--system";
          return `<div class="chat-bubble ${cls}">${escapeHtml(m.text || "")}</div>`;
        }).join("")}
        ${chat.loading ? `<div class="chat-bubble chat-bubble--system chat-loading">…</div>` : ""}
      </div>
      ${checkoutBlock}
      <div class="chat-input-row">
        <input class="chat-input" data-act="chat-text" placeholder="Список материалов…" ${chat.loading ? "disabled" : ""}>
        <button class="btn btn-accent chat-send" data-act="chat-send" type="button"${chat.loading ? " disabled" : ""}>→</button>
      </div>
    </div>`;
}

function renderScreen() {
  if (state.screen === "home") return renderHome();
  if (state.screen === "materials") return renderMaterialsTab();
  if (state.screen === "publish") return renderPublishWork();
  if (state.screen === "products") return renderMaterials();
  if (state.screen === "masters") return renderMasters();
  if (state.screen === "details") return renderDetails();
  if (state.screen === "master_details") return renderMasterDetails();
  if (state.screen === "cart") return renderCart();
  if (state.screen === "checkout") return renderCheckout();
  if (state.screen === "orders") return renderOrders();
  if (state.screen === "notifications") return renderNotificationsScreen();
  if (state.screen === "chat_order") return renderChatOrder();
  if (state.screen === "master_auth" || state.screen === "client_auth") return renderMasterAuth();
  if (state.screen === "about") return renderAbout();
  if (state.screen === "calculator") return renderCalculator();
  return renderProfile();
}

function applyTheme() {
  const dark = state.profileTheme === "dark";
  document.documentElement.classList.toggle("theme-light", !dark);
  document.documentElement.classList.toggle("theme-dark", dark);
  try {
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute("content", dark ? "#121212" : "#FFFFFF");
  } catch (_) {}
}

function render() {
  const root = document.getElementById("app");
  if (!root) return;
  applyTheme();

  const count = cartCount();
  const immersiveScreens = ["details", "master_details", "checkout", "orders", "notifications", "chat_order", "master_auth", "client_auth"];
  const immersive = immersiveScreens.indexOf(state.screen) !== -1;

  root.innerHTML = `
    <div class="site">
      ${renderDesktopHeader()}
      ${renderDesktopNav()}

      <div class="app${immersive ? " app--immersive" : ""} app--screen-${state.screen}">
        <div class="top-safe mobile-header">
          ${renderHeader()}
        </div>

        <div class="main">
          ${renderScreen()}
        </div>

        <div class="tabs bottom-navigation tabs--five" aria-label="Основное меню">
          ${renderBottomNav()}
        </div>
      </div>

      ${renderDesktopFooter()}
    </div>

    ${renderAddressSheet()}
    ${renderLightboxHTML()}
  `;
}

/* ===== EVENTS ===== */
document.addEventListener("click", (e) => {
  const t = e.target.closest("[data-act]");
  if (!t) return;

  const act = t.getAttribute("data-act");

  if (act === "nav") {
    const mode = t.getAttribute("data-auth-mode");
    if (mode) {
      state.authMode = mode;
      state.authStep = "phone";
      state.authError = "";
      state.authPassword = "";
      state.authConfirm = "";
    }
    const calcProduct = t.getAttribute("data-calc-product");
    if (calcProduct) state.calc.productId = calcProduct;
    setScreen(t.getAttribute("data-screen"));
    return;
  }
  if (act === "open") { openDetails(t.getAttribute("data-id"), t.getAttribute("data-from")); return; }
  if (act === "profile-back") {
    state.profileSection = null;
    state.addressSheetOpen = false;
    render();
    return;
  }
  if (act === "back") { setScreen(state.backScreen || "home"); return; }

  if (act === "add") { addToCart(t.getAttribute("data-id")); return; }
  if (act === "add-detail") { addToCart(t.getAttribute("data-id"), { fromDetail: true }); return; }
  if (act === "fav") {
    e.stopPropagation();
    toggleFav(t.getAttribute("data-id"));
    render();
    return;
  }
  if (act === "buy-now") { addToCart(t.getAttribute("data-id")); setScreen("cart"); return; }
  if (act === "buy-now-detail") { addToCart(t.getAttribute("data-id"), { fromDetail: true }); setScreen("cart"); return; }

  if (act === "select-detail-size") {
    state.detailsSizeIndex = Number(t.getAttribute("data-index") || 0);
    render();
    return;
  }
  if (act === "select-detail-color") {
    state.detailsColorIndex = Number(t.getAttribute("data-index") || 0);
    render();
    return;
  }

  if (act === "clear-cart") { clearCart(); return; }
  if (act === "checkout") { openCheckout(); return; }

  // cart controls
  if (act === "qty-plus") {
    const cKey = t.getAttribute("data-cart-key");
    const it = findCartItem(cKey);
    if (it) {
      it.qty = Number(it.qty || 0) + 1;
      saveCart();
      render();
    }
    return;
  }

  if (act === "qty-minus") {
    const cKey = t.getAttribute("data-cart-key");
    const it = findCartItem(cKey);
    if (it) {
      it.qty = Number(it.qty || 0) - 1;
      if (it.qty <= 0) {
        state.cart = state.cart.filter(function (x) { return cartItemKey(x) !== cKey; });
        if (state.cartSwipeOpenId === cKey) state.cartSwipeOpenId = null;
      }
      saveCart();
      render();
    }
    return;
  }

  if (act === "remove-item") {
    const cKey = t.getAttribute("data-cart-key");
    state.cart = state.cart.filter(function (x) { return cartItemKey(x) !== cKey; });
    if (state.cartSwipeOpenId === cKey) state.cartSwipeOpenId = null;
    saveCart();
    render();
    return;
  }

  if (act === "cart-open-swipe") {
    const cKey = t.getAttribute("data-cart-key");
    state.cartSwipeOpenId = (state.cartSwipeOpenId === cKey) ? null : cKey;
    render();
    return;
  }

  if (act === "cart-close-swipe") {
    state.cartSwipeOpenId = null;
    render();
    return;
  }

  // checkout controls
  if (act === "set-delivery") {
    state.checkout.deliveryType = t.getAttribute("data-val") || "delivery";
    saveCheckout();
    render();
    return;
  }
  if (act === "set-pay") {
    state.checkout.payment = t.getAttribute("data-val") || "cash";
    saveCheckout();
    render();
    return;
  }
  if (act === "set-home-cat" || act === "set-materials-cat") {
    state.homeCategoryFilter = t.getAttribute("data-val") || "Все";
    if ((state.qMaterials || "").trim().length >= 2) fetchProductSearch(state.qMaterials.trim(), "materials");
    else render();
    return;
  }
  if (act === "set-catalog-brand") {
    state.catalogBrandFilter = t.getAttribute("data-val") || "Все";
    render();
    return;
  }
  if (act === "submit-order") { submitOrder(); return; }

  if (act === "chat-send") {
    const inp = document.querySelector('[data-act="chat-text"]');
    if (inp && inp.value) {
      const v = inp.value;
      inp.value = "";
      chatSendMessage(v);
    }
    return;
  }
  if (act === "chat-pick") {
    chatPickOption(Number(t.getAttribute("data-id")), Number(t.getAttribute("data-idx")));
    return;
  }
  if (act === "chat-action") {
    chatAction(t.getAttribute("data-action"), {});
    return;
  }
  if (act === "chat-checkout") {
    state.chat.checkoutOpen = true;
    state.checkoutError = "";
    render();
    return;
  }
  if (act === "chat-checkout-close") {
    state.chat.checkoutOpen = false;
    render();
    return;
  }
  if (act === "chat-submit") { chatSubmitOrder(); return; }
  if (act === "chat-reset") {
    if (state.chat.sessionId) chatAction("reset", {});
    state.chat.sessionId = null;
    state.chat.messages = [];
    state.chat.checkoutOpen = false;
    ensureChatSession().then(function () { render(); });
    return;
  }

  if (act === "auth-back-phone") {
    state.authStep = "phone";
    state.authError = "";
    render();
    return;
  }
  if (act === "auth-switch-master") {
    state.authMode = "master";
    state.authStep = "phone";
    state.authError = "";
    render();
    return;
  }
  if (act === "auth-switch-client") {
    state.authMode = "client";
    state.authStep = "phone";
    state.authError = "";
    render();
    return;
  }
  if (act === "auth-check-phone") {
    state.authError = "";
    state.authLoading = true;
    render();
    const phone = normalizeAuthPhoneInput(state.authPhone);
    const prefix = authApiPrefix();
    apiPostJson(prefix + "/check-phone", { phone_number: phone }, false).then(function (body) {
      state.authPhone = phone;
      const st = (body.status || "").toUpperCase();
      if (st === "NOT_FOUND") state.authStep = "register";
      else if (st === "RESET_REQUIRED") state.authStep = "resetPassword";
      else state.authStep = "password";
      state.authLoading = false;
      render();
    }).catch(function (e) {
      state.authError = e.message;
      state.authLoading = false;
      render();
    });
    return;
  }
  if (act === "auth-login") {
    if ((state.authPassword || "").trim().length < 4) {
      state.authError = "Код должен быть не короче 4 символов";
      render();
      return;
    }
    state.authError = "";
    state.authLoading = true;
    render();
    const prefix = authApiPrefix();
    apiPostJson(prefix + "/login", { phone_number: state.authPhone, password: state.authPassword }, false).then(function (body) {
      applyLoginResponse(body);
      state.authLoading = false;
      fetchProfileData();
      setScreen("profile");
    }).catch(function (e) {
      state.authError = e.message;
      state.authLoading = false;
      render();
    });
    return;
  }
  if (act === "auth-register") {
    if ((state.authPassword || "").trim().length < 4) {
      state.authError = "Код должен быть не короче 4 символов";
      render();
      return;
    }
    if (state.authPassword !== state.authConfirm) {
      state.authError = state.authMode === "client" ? "Коды не совпадают" : "Пароли не совпадают";
      render();
      return;
    }
    state.authError = "";
    state.authLoading = true;
    render();
    const prefix = authApiPrefix();
    const payload = {
      phone_number: state.authPhone,
      password: state.authPassword,
    };
    if (state.authMode !== "client" && state.authName) payload.name = state.authName;
    apiPostJson(prefix + "/register", payload, false).then(function (body) {
      applyLoginResponse(body);
      state.authLoading = false;
      fetchProfileData();
      setScreen("profile");
    }).catch(function (e) {
      state.authError = e.message;
      state.authLoading = false;
      render();
    });
    return;
  }
  if (act === "auth-set-password") {
    if (state.authPassword !== state.authConfirm) {
      state.authError = "Пароли не совпадают";
      render();
      return;
    }
    state.authError = "";
    state.authLoading = true;
    render();
    apiPostJson("/auth/set-new-password", {
      phone_number: state.authPhone,
      password: state.authPassword,
    }, false).then(function (body) {
      applyLoginResponse(body);
      state.authLoading = false;
      fetchProfileData();
      setScreen("profile");
    }).catch(function (e) {
      state.authError = e.message;
      state.authLoading = false;
      render();
    });
    return;
  }

  if (act === "profile-logout") {
    if (state.refreshToken) {
      const logoutPath = isClientUser() ? "/auth/client/logout" : "/auth/logout";
      apiPostJson(logoutPath, { refresh_token: state.refreshToken }, false).catch(function () {});
    }
    clearAuth();
    setScreen("home");
    return;
  }
  if (act === "profile-nav") {
    const section = t.getAttribute("data-section") || null;
    if (isDesktopLayout()) {
      state.profileSection = section;
      state.addressSheetOpen = false;
      if (state.screen !== "profile") state.screen = "profile";
      render();
    } else {
      if (section === "orders") setScreen("orders");
      else if (section === "notifications") setScreen("notifications");
      else if (section === "addresses") {
        state.addressSheetOpen = true;
        if (state.screen !== "profile") setScreen("profile");
        else render();
      } else if (section === "projects") {
        state.profileSection = "projects";
        setScreen("profile");
      } else if (section === "language") {
        state.profileSection = "language";
        setScreen("profile");
      } else if (section === "about") {
        fetchSiteAbout();
        if (isDesktopLayout()) {
          state.profileSection = "about";
          setScreen("profile");
        } else {
          setScreen("about");
        }
      } else setScreen("profile");
    }
    return;
  }
  if (act === "close-address-sheet") {
    state.addressSheetOpen = false;
    render();
    return;
  }
  if (act === "toggle-theme") {
    state.profileTheme = state.profileTheme === "dark" ? "light" : "dark";
    try { localStorage.setItem(LS_PROFILE_THEME, state.profileTheme); } catch (_) {}
    applyTheme();
    render();
    return;
  }
  if (act === "save-address") {
    saveCheckout();
    state.addressSheetOpen = false;
    render();
    return;
  }
  if (act === "set-theme") {
    state.profileTheme = t.getAttribute("data-val") || "light";
    try { localStorage.setItem(LS_PROFILE_THEME, state.profileTheme); } catch (_) {}
    applyTheme();
    render();
    return;
  }
  if (act === "set-lang") {
    state.profileLang = t.getAttribute("data-val") || "ru";
    try { localStorage.setItem(LS_PROFILE_LANG, state.profileLang); } catch (_) {}
    render();
    return;
  }

  // call
  if (act === "call") {
    const phone = t.getAttribute("data-phone") || "";
    if (phone) window.location.href = `tel:${phone}`;
    return;
  }

  if (act === "q-submit") {
    applySearchQuery();
    return;
  }
  if (act === "q-clear") {
    clearSearchForScreen(state.screen);
    render();
    return;
  }

  // clear search (legacy)
  if (act === "clear-q") {
    clearSearchForScreen(state.screen);
    render();
    return;
  }

  // materials navigation
  if (act === "open-cat") {
    state.screen = "products";
    state.selectedCategory = t.getAttribute("data-cat");
    state.selectedSubcategory = null;
    state.materialsStep = "subcategories";
    clearSearchForScreen("products");
    render();
    return;
  }
  if (act === "desk-open-cat") {
    state.screen = "products";
    state.selectedCategory = t.getAttribute("data-cat");
    state.selectedSubcategory = null;
    state.materialsStep = "subcategories";
    clearSearchForScreen("products");
    render();
    return;
  }
  if (act === "mat-reset") {
    resetMaterialsToRoot();
    render();
    return;
  }
  if (act === "open-sub") {
    state.selectedSubcategory = t.getAttribute("data-sub");
    state.materialsStep = "items";
    clearSearchForScreen("products");
    render();
    return;
  }
  if (act === "mat-back") {
    if (state.materialsStep === "items") {
      state.materialsStep = "subcategories";
      state.selectedSubcategory = null;
    } else if (state.materialsStep === "subcategories") {
      resetMaterialsToRoot();
    }
    clearSearchForScreen("products");
    render();
    return;
  }

  // product details thumbs
  if (act === "set-detail-photo") {
    state.detailsPhotoIndex = Number(t.getAttribute("data-index") || 0);
    render();
    return;
  }

  // lightbox open (product)
  if (act === "open-photo") {
    var p = getProductById(state.selectedProductId);
    if (!p) return;
    var idx = Number(t.getAttribute("data-index") || 0);
    var photos = (p.photos || []).map(fullUrl);
    openLightbox(photos, idx);
    return;
  }

  // masters navigation
  if (act === "open-master-cat") {
    state.selectedMasterCategory = t.getAttribute("data-cat") || "ВСЕ МАСТЕРА";
    state.mastersStep = "list";
    clearSearchForScreen("masters");
    if (state.screen !== "masters") {
      setScreen("masters");
    } else {
      render();
    }
    return;
  }

  if (act === "masters-back") {
    state.mastersStep = "categories";
    state.selectedMasterCategory = null;
    clearSearchForScreen("masters");
    render();
    return;
  }

  if (act === "open-master") {
    // если нажали на кнопку/ссылку внутри карточки — не открываем экран мастера
    const insideButton = e.target.closest("a,button");
    if (insideButton) return;

    openMasterDetails(t.getAttribute("data-id"));
    return;
  }

  if (act === "master-back") {
    state.screen = "masters";
    state.mastersStep = state.masterBackStep || "list";
    render();
    return;
  }

  if (act === "set-master-photo") {
    state.masterPhotoIndex = Number(t.getAttribute("data-index") || 0);
    render();
    return;
  }

  if (act === "open-master-photo") {
    const m = getMasterById(state.selectedMasterId);
    if (!m) return;
    const works = getMasterWorks(m);
    const avatar = getMasterAvatar(m);
    const photos = works.length ? works : (avatar ? [avatar] : []);
    if (!photos.length) return;
    const idx = Number(t.getAttribute("data-index") || 0);
    openLightbox(photos, idx);
    return;
  }

  if (act === "open-works-lightbox") {
    const m = getMasterById(state.selectedMasterId);
    if (!m) return;
    const works = getMasterWorks(m);
    if (!works.length) return;
    const idx = Number(t.getAttribute("data-index") || 0);
    openLightbox(works, idx);
    return;
  }

  // calculator
  if (act === "calc-preset") {
    state.calc.length = calcClamp(t.getAttribute("data-length"), 1.0, 30);
    state.calc.width = calcClamp(t.getAttribute("data-width"), 1.0, 30);
    render();
    return;
  }
  if (act === "calc-step") {
    var field = t.getAttribute("data-field");
    var delta = calcSafeNumber(t.getAttribute("data-delta"), 0);
    if (field === "length") {
      state.calc.length = calcClamp(calcRoundStep(state.calc.length + delta, 0.5), 1.0, 30);
    } else if (field === "width") {
      state.calc.width = calcClamp(calcRoundStep(state.calc.width + delta, 0.5), 1.0, 30);
    } else if (field === "height") {
      state.calc.height = calcClamp(calcRoundStep(state.calc.height + delta, 0.1), 2.0, 5.0);
    } else if (field === "doors") {
      state.calc.doors = calcClamp(Math.round(state.calc.doors + delta), 1, 20);
    } else if (field === "windows") {
      state.calc.windows = calcClamp(Math.round(state.calc.windows + delta), 1, 20);
    }
    render();
    return;
  }
  if (act === "calc-toggle-labor") {
    // legacy: переключает первую услугу (покраска) / выкл
    state.calc.serviceId = state.calc.serviceId ? null : "painting";
    state.calc.productId = null;
    render();
    return;
  }
  if (act === "calc-service") {
    var sid = t.getAttribute("data-id") || "";
    state.calc.serviceId = sid || null;
    state.calc.productId = null; // сброс — список материалов меняется под услугу
    render();
    return;
  }
  if (act === "calc-detail-preset") {
    state.detailsCalcLength = calcClamp(t.getAttribute("data-length"), 1.0, 30);
    state.detailsCalcWidth = calcClamp(t.getAttribute("data-width"), 1.0, 30);
    render();
    return;
  }

  // lightbox
  if (act === "lb-close") { closeLightbox(); return; }
  if (act === "lb-prev") { nextPhoto(-1); return; }
  if (act === "lb-next") { nextPhoto(1); return; }
});

document.addEventListener("change", (e) => {
  const t = e.target;
  if (!t || !t.getAttribute) return;
  if (t.getAttribute("data-act") === "calc-product" || t.id === "calc-product-select") {
    state.calc.productId = t.value || null;
    render();
    return;
  }
  if (t.getAttribute("data-act") === "search-city") {
    state.searchCity = t.value || "";
    if (state.screen === "home" || state.screen === "masters") {
      applySearchQuery({ keepFocus: false });
    } else {
      render();
    }
  }
});

document.addEventListener("input", (e) => {
  const t = e.target;

  // search — живой поиск с debounce
  if (t && t.getAttribute && t.getAttribute("data-act") === "q") {
    setSearchDraftValue(t.value || "");
    syncSearchClearButton(t);
    if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
    searchDebounceTimer = setTimeout(function () {
      applySearchQuery({ keepFocus: true });
    }, 280);
    return;
  }

  if (t && t.getAttribute && t.getAttribute("data-auth")) {
    const k = t.getAttribute("data-auth");
    if (k === "phone") state.authPhone = t.value || "";
    else if (k === "name") state.authName = t.value || "";
    else if (k === "password") state.authPassword = t.value || "";
    else if (k === "confirm") state.authConfirm = t.value || "";
    return;
  }

  // checkout fields
  if (t && t.getAttribute) {
    const k = t.getAttribute("data-check");
    if (k) {
      state.checkout[k] = t.value || "";
      saveCheckout();
    }
  }
});

document.addEventListener("submit", (e) => {
  if (e.target && e.target.matches && e.target.matches("[data-search-form]")) {
    e.preventDefault();
    applySearchQuery();
  }
});

// keyboard for lightbox
document.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && e.target && e.target.getAttribute && e.target.getAttribute("data-act") === "q") {
    e.preventDefault();
    applySearchQuery();
    return;
  }
  if (!state.lbOpen && state.screen === "chat_order" && e.key === "Enter") {
    const inp = document.querySelector(".chat-input");
    if (inp && document.activeElement === inp && inp.value.trim()) {
      e.preventDefault();
      const v = inp.value;
      inp.value = "";
      chatSendMessage(v);
      return;
    }
  }
  if (!state.lbOpen) return;
  if (e.key === "Escape") closeLightbox();
  if (e.key === "ArrowLeft") nextPhoto(-1);
  if (e.key === "ArrowRight") nextPhoto(1);
});

// ===== Touch swipe (lightbox + product details + master details + cart) =====
let touchStartX = 0;
let touchStartY = 0;
let touchStartT = 0;

function isHorizontalSwipe(dx, dy) {
  return Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy) * 1.2;
}

document.addEventListener("touchstart", (e) => {
  if (!e.touches || e.touches.length !== 1) return;
  const t = e.touches[0];
  touchStartX = t.clientX;
  touchStartY = t.clientY;
  touchStartT = Date.now();
}, { passive: true });

document.addEventListener("touchend", (e) => {
  const endT = Date.now();
  if (endT - touchStartT > 700) return;

  const touch = e.changedTouches && e.changedTouches[0];
  if (!touch) return;

  const dx = touch.clientX - touchStartX;
  const dy = touch.clientY - touchStartY;

  if (!isHorizontalSwipe(dx, dy)) return;

  // left swipe => dir=1, right swipe => dir=-1
  const dir = dx < 0 ? 1 : -1;

  // 1) Lightbox swipe
  if (state.lbOpen) {
    nextPhoto(dir);
    return;
  }

  // 2) Product details hero swipe
  if (state.screen === "details") {
    var el = document.elementFromPoint(touch.clientX, touch.clientY);
    var hero = el && el.closest && el.closest('[data-swipe="details"]');
    if (!hero) return;

    var p = getProductById(state.selectedProductId);
    var photos = (p && p.photos) ? (p.photos || []).map(fullUrl) : [];
    if (photos.length <= 1) return;

    state.detailsPhotoIndex = (state.detailsPhotoIndex + dir + photos.length) % photos.length;
    render();
    return;
  }

  // 3) Master details hero swipe
  if (state.screen === "master_details") {
    const el = document.elementFromPoint(touch.clientX, touch.clientY);
    const hero = el && el.closest && el.closest('[data-swipe="master"]');
    if (!hero) return;

    const m = getMasterById(state.selectedMasterId);
    if (!m) return;

    const works = getMasterWorks(m);
    const avatar = getMasterAvatar(m);
    const photos = works.length ? works : (avatar ? [avatar] : []);
    if (photos.length <= 1) return;

    state.masterPhotoIndex = (state.masterPhotoIndex + dir + photos.length) % photos.length;
    render();
    return;
  }

  // 4) Cart swipe (open actions on left swipe, close on right swipe)
  if (state.screen === "cart") {
    const el = document.elementFromPoint(touch.clientX, touch.clientY);
    const card = el && el.closest && el.closest('[data-swipe="cart"]');
    if (!card) return;

    const cKey = card.getAttribute("data-cart-key");
    if (!cKey) return;

    if (dir === 1) { // swipe left open
      state.cartSwipeOpenId = cKey;
      render();
      return;
    }
    if (dir === -1) { // swipe right close
      if (state.cartSwipeOpenId === cKey) {
        state.cartSwipeOpenId = null;
        render();
      }
      return;
    }
  }
}, { passive: true });

function updateMobileViewportClass() {
  try {
    document.documentElement.classList.toggle(
      "is-mobile",
      window.matchMedia("(max-width: 768px)").matches
    );
    document.documentElement.classList.toggle(
      "is-desktop",
      window.matchMedia("(min-width: 1024px)").matches
    );
  } catch (_) {}
}

// start
document.addEventListener("DOMContentLoaded", () => {
  loadCart();
  loadCheckout();
  loadFav();
  loadAuth();
  updateMobileViewportClass();
  window.addEventListener("resize", updateMobileViewportClass);
  applyTheme();
  render();
  fetchProductsOnce();
  fetchMastersOnce();
  if (isLoggedIn()) fetchProfileData();
});
