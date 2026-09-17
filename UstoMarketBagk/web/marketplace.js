/**
 * Ustobozor Web — marketplace layer (Avito-style) поверх app.js
 * Переопределяет главную, шапку, каталог мастеров и форму заявки.
 */
(function () {
  "use strict";

  var DISTRICTS = [];

  function cityOptionsList() {
    var fromDb = typeof getMasterCities === "function" ? getMasterCities() : [];
    var base = [
      "г. Душанбе",
      "г. Худжанд",
      "г. Истаравшан",
      "г. Бохтар",
      "г. Куляб",
      "г. Гулистон",
      "г. Бустон",
      "г. Исфара",
      "г. Канибадам",
      "г. Пенджикент",
      "г. Турсунзода",
      "г. Вахдат",
      "г. Хорог",
      "г. Истиклол",
    ];
    var map = {};
    base.concat(fromDb || []).forEach(function (c) {
      if (c && String(c).trim()) map[String(c).trim()] = true;
    });
    return Object.keys(map).sort(function (a, b) {
      return a.localeCompare(b, "ru");
    });
  }

  var SERVICE_CATS = [
    { id: "Сварщик", name: "Сварщики и металлоконструкции", ico: "🛠" },
    { id: "Плиточник", name: "Плиточники и отделочники", ico: "🧱" },
    { id: "Электрик", name: "Электрики и Сантехники", ico: "⚡" },
    { id: "Евроремонт", name: "Строительство и кровля", ico: "🏗" },
  ];

  function ensureMarketState() {
    if (!state.city) state.city = "";
    if (!state.district) state.district = "";
    if (!state.openRequests) state.openRequests = [];
    if (state.loadingOpenRequests == null) state.loadingOpenRequests = false;
    if (!state.mastersSort) state.mastersSort = "rating";
    if (state.mastersOnlyPhoto == null) state.mastersOnlyPhoto = false;
    if (!state.orderCreate) {
      state.orderCreate = {
        step: 1,
        title: "",
        category: SERVICE_CATS[0].id,
        description: "",
        address: "",
        city: "",
        budget: "",
        photos: [],
        error: "",
        saving: false,
      };
    }
    if (state.citySheetOpen == null) state.citySheetOpen = false;
  }

  function ratingOf(m) {
    var r = Number(m.rating);
    return isNaN(r) ? 5 : r;
  }

  function masterPriceLabel(m) {
    if (m.price_from != null && !isNaN(Number(m.price_from))) {
      return "от " + formatPriceSmn(m.price_from);
    }
    return "Договорная";
  }

  function masterLoc(m) {
    var city = (m.city || "").trim();
    return city || "Таджикистан";
  }

  function syncUrl() {
    try {
      var path = "/";
      if (state.screen === "masters") path = "/masters";
      else if (state.screen === "master_details" && state.selectedMasterId)
        path = "/master/" + state.selectedMasterId;
      else if (state.screen === "publish" || state.screen === "order_create")
        path = "/orders/create";
      else if (state.screen === "orders") path = "/orders/my";
      else if (state.screen === "profile") path = "/cabinet";
      else if (state.screen === "home") path = "/";
      if (location.pathname !== path) {
        history.pushState({ screen: state.screen }, "", path);
      }
    } catch (_) {}
  }

  function applyPathToScreen() {
    ensureMarketState();
    var p = (location.pathname || "/").replace(/\/+$/, "") || "/";
    if (p === "/" || p === "/index.html") {
      state.screen = "home";
      return;
    }
    if (p === "/masters" || p === "/search") {
      state.screen = "masters";
      state.mastersStep = "list";
      state.selectedMasterCategory = "ВСЕ МАСТЕРА";
      return;
    }
    var m = p.match(/^\/master\/([^/]+)$/);
    if (m) {
      state.selectedMasterId = normalizeMasterId(m[1]);
      state.screen = "master_details";
      return;
    }
    if (p === "/orders/create") {
      state.screen = "publish";
      return;
    }
    if (p === "/orders/my") {
      state.screen = "orders";
      return;
    }
    if (p === "/cabinet") {
      state.screen = "profile";
    }
  }

  async function fetchOpenRequests() {
    ensureMarketState();
    if (state.loadingOpenRequests) return;
    state.loadingOpenRequests = true;
    try {
      var cityQ = (state.searchCity || state.city || "").trim();
      var url = API + "/service-requests/open?limit=9";
      if (cityQ) url += "&city=" + encodeURIComponent(cityQ);
      var res = await fetch(url);
      if (!res.ok) throw new Error("feed");
      var data = await res.json();
      state.openRequests = (data && data.items) || [];
    } catch (e) {
      state.openRequests = [];
    } finally {
      state.loadingOpenRequests = false;
      render();
    }
  }

  function filteredMasters() {
    ensureMarketState();
    if (state.searchCity == null) state.searchCity = "";
    var q = (state.qMasters || state.qHome || "").trim().toLowerCase();
    var cat = state.selectedMasterCategory || "ВСЕ МАСТЕРА";
    var list = (state.masters || []).slice();
    if (cat && cat !== "ВСЕ МАСТЕРА") {
      list = list.filter(function (m) {
        return masterHasCategory(m, cat);
      });
    }
    if (q) {
      list = list.filter(function (m) {
        return masterMatches(m, q);
      });
    }
    if (state.searchCity) {
      list = list.filter(function (m) {
        return masterMatchesCity(m, state.searchCity);
      });
    }
    if (state.mastersOnlyPhoto) {
      list = list.filter(function (m) {
        return !!(getMasterAvatar(m) || (getMasterWorks(m) || []).length);
      });
    }
    if (state.mastersSort === "price_asc") {
      list.sort(function (a, b) {
        return (a.price_from == null ? 1e12 : a.price_from) - (b.price_from == null ? 1e12 : b.price_from);
      });
    } else if (state.mastersSort === "price_desc") {
      list.sort(function (a, b) {
        return (b.price_from == null ? -1 : b.price_from) - (a.price_from == null ? -1 : a.price_from);
      });
    } else if (state.mastersSort === "fresh") {
      list.sort(function (a, b) {
        return Number(b.id || 0) - Number(a.id || 0);
      });
    } else {
      list.sort(function (a, b) {
        return ratingOf(b) - ratingOf(a);
      });
    }
    return list;
  }

  function mkMasterCard(m) {
    var photo = getMasterHeroImage(m);
    var cats = getMasterCategoriesList(m);
    var title =
      (cats[0] ? cats[0] + " — " : "") + (m.name || "Мастер");
    var wa = (m.whatsapp || m.phone || "").replace(/\s+/g, "");
    var top = ratingOf(m) >= 4.8;
    return (
      '<article class="mk-master" data-act="open-master" data-id="' +
      m.id +
      '">' +
      '<div class="mk-master-img">' +
      (photo
        ? '<img src="' + photo + '" alt="' + escapeHtml(m.name || "") + '" loading="lazy">'
        : '<div class="mk-master-ph">' + icon("hammer", "", 36) + "</div>") +
      (top ? '<span class="mk-badge">Top Master</span>' : "") +
      "</div>" +
      '<div class="mk-master-body">' +
      '<div class="mk-master-title">' +
      escapeHtml(title) +
      "</div>" +
      '<div class="mk-master-rating"><span class="star">★</span> ' +
      ratingOf(m).toFixed(1) +
      "</div>" +
      '<div class="mk-master-price">' +
      escapeHtml(masterPriceLabel(m)) +
      "</div>" +
      '<div class="mk-master-loc">' +
      escapeHtml(masterLoc(m)) +
      "</div>" +
      (wa
        ? '<a class="mk-master-wa" href="https://wa.me/' +
          wa +
          '" target="_blank" rel="noopener" onclick="event.stopPropagation()">' +
          "WhatsApp / Показать телефон</a>"
        : "") +
      "</div></article>"
    );
  }

  function renderCitySheet() {
    ensureMarketState();
    if (!state.citySheetOpen) return "";
    var cities = cityOptionsList();
    return (
      '<div class="city-sheet" data-act="city-close">' +
      '<div class="city-sheet-panel" data-act="stop">' +
      "<h3>Город</h3>" +
      '<button type="button" class="city-opt' +
      (!state.searchCity ? " active" : "") +
      '" data-act="set-city" data-val="">Все города</button>' +
      cities
        .map(function (d) {
          var active = state.searchCity === d ? " active" : "";
          return (
            '<button type="button" class="city-opt' +
            active +
            '" data-act="set-city" data-val="' +
            escapeHtml(d) +
            '">' +
            escapeHtml(d) +
            "</button>"
          );
        })
        .join("") +
      "</div></div>"
    );
  }

  var _origRender = render;
  window.render = function () {
    ensureMarketState();
    _origRender();
    var root = document.getElementById("app");
    if (!root) return;
    if (state.citySheetOpen) {
      root.insertAdjacentHTML("beforeend", renderCitySheet());
    }
  };

  var _origSetScreen = setScreen;
  window.setScreen = function (screen) {
    ensureMarketState();
    if (screen === "order_create") screen = "publish";
    _origSetScreen(screen);
    if (screen === "home" || screen === "publish") fetchOpenRequests();
    if (screen === "home" || screen === "masters" || screen === "master_details")
      fetchMastersOnce();
    syncUrl();
  };

  window.renderDesktopHeader = function () {
    ensureMarketState();
    var count = cartCount();
    var showSearch = ["home", "masters", "materials", "products", "publish"].indexOf(state.screen) !== -1;
    var cityLabel = state.searchCity || state.city || "Все города";
    var authLabel = isLoggedIn()
      ? isMasterUser()
        ? "Мастер"
        : "Профиль"
      : "Вход";
    return (
      '<header class="desk-header desktop-header">' +
      '<div class="desk-header-inner">' +
      '<button type="button" class="desk-logo" data-act="nav" data-screen="home">' +
      '<span class="desk-logo-text"><span class="brand">Usto</span><span class="tj">bozor</span>.tj</span>' +
      "</button>" +
      '<button type="button" class="desk-city-btn" data-act="city-open" title="Город">' +
      icon("mapPin", "", 16) +
      "<span>" +
      escapeHtml(cityLabel) +
      "</span></button>" +
      (showSearch
        ? '<div class="desk-search-wrap">' + renderSearchBar("desk") + "</div>"
        : '<div class="desk-search-wrap desk-search-wrap--placeholder"></div>') +
      '<nav class="desk-actions" aria-label="Основная навигация">' +
      '<button type="button" class="desk-cta-order" data-act="nav" data-screen="publish">Разместить заказ</button>' +
      '<button type="button" class="desk-action ' +
      (state.screen === "masters" ? "active" : "") +
      '" data-act="nav" data-screen="masters">' +
      icon("users") +
      "<span>Мастера</span></button>" +
      '<button type="button" class="desk-action ' +
      (state.screen === "materials" ? "active" : "") +
      '" data-act="nav" data-screen="materials">' +
      icon("box") +
      "<span>Материалы</span></button>" +
      '<button type="button" class="desk-action desk-action-cart ' +
      (state.screen === "cart" ? "active" : "") +
      '" data-act="nav" data-screen="cart">' +
      icon("cart") +
      "<span>Корзина</span>" +
      (count ? '<span class="desk-badge">' + count + "</span>" : "") +
      "</button>" +
      '<button type="button" class="desk-action ' +
      (state.screen === "profile" || state.screen === "client_auth" || state.screen === "master_auth"
        ? "active"
        : "") +
      '" data-act="nav" data-screen="' +
      (isLoggedIn() ? "profile" : "client_auth") +
      '"' +
      (isLoggedIn() ? "" : ' data-auth-mode="client"') +
      ">" +
      icon("user") +
      "<span>" +
      authLabel +
      "</span></button>" +
      "</nav></div></header>"
    );
  };

  window.renderDesktopNav = function () {
    ensureMarketState();
    var cats = getAllMasterCategories().slice(0, 10);
    return (
      '<nav class="desk-nav" aria-label="Категории услуг">' +
      '<div class="desk-nav-inner">' +
      '<button type="button" class="desk-nav-all" data-act="nav" data-screen="masters">' +
      icon("menu", "", 18) +
      "<span>Все категории</span></button>" +
      '<div class="desk-nav-links">' +
      cats
        .map(function (c) {
          var active =
            state.screen === "masters" && state.selectedMasterCategory === c
              ? " active"
              : "";
          return (
            '<button type="button" class="desk-nav-link' +
            active +
            '" data-act="open-master-cat" data-cat="' +
            escapeHtml(c) +
            '">' +
            escapeHtml(c) +
            "</button>"
          );
        })
        .join("") +
      "</div></div></nav>"
    );
  };

  window.renderHome = function () {
    ensureMarketState();
    var list = filteredMasters().slice(0, 12);
    var orders = state.openRequests || [];
    return (
      '<div class="home-screen">' +
      '<div class="home-brand mobile-only">Ustobozor.tj</div>' +
      '<div class="home-search-mobile mobile-only">' +
      renderSearchBar() +
      "</div>" +
      '<section class="mk-hero">' +
      "<h1>Найдите проверенного мастера или закажите услугу в Таджикистане</h1>" +
      "<p>Сварка, плитка, электрика, сантехника и ремонт — объявления мастеров и свежие заказы по всей стране.</p>" +
      '<div class="mk-hero-actions">' +
      '<button type="button" class="btn btn-light" data-act="nav" data-screen="publish">Разместить заказ</button>' +
      '<button type="button" class="btn btn-ghost" data-act="nav" data-screen="masters">Каталог мастеров</button>' +
      "</div></section>" +
      '<div class="mk-cats">' +
      SERVICE_CATS.map(function (c) {
        return (
          '<button type="button" class="mk-cat" data-act="open-master-cat" data-cat="' +
          escapeHtml(c.id) +
          '"><span class="mk-cat-ico">' +
          c.ico +
          '</span><span class="mk-cat-name">' +
          escapeHtml(c.name) +
          "</span></button>"
        );
      }).join("") +
      "</div>" +
      '<div class="mk-section-head"><h2>Свежие заказы</h2>' +
      '<button type="button" class="mk-link" data-act="nav" data-screen="publish">Разместить свой</button></div>' +
      (state.loadingOpenRequests && !orders.length
        ? '<div class="empty-state">Загрузка заявок…</div>'
        : orders.length
          ? '<div class="mk-orders">' +
            orders
              .map(function (o) {
                var budget =
                  o.budget != null
                    ? Number(o.budget).toLocaleString("ru-RU") + " TJS"
                    : "Договорная";
                return (
                  '<div class="mk-order">' +
                  '<div class="mk-order-title">' +
                  escapeHtml(o.title || "Заявка") +
                  "</div>" +
                  '<div class="mk-order-meta"><span>' +
                  escapeHtml(o.category || "") +
                  "</span><span>" +
                  escapeHtml(o.city || "Таджикистан") +
                  "</span><span>" +
                  escapeHtml((o.created_at || "").slice(0, 10)) +
                  "</span></div>" +
                  '<div class="mk-order-budget">' +
                  escapeHtml(budget) +
                  "</div>" +
                  '<button type="button" class="btn btn-accent btn-block" data-act="nav" data-screen="master_auth" data-auth-mode="master">Откликнуться</button>' +
                  "</div>"
                );
              })
              .join("") +
            "</div>"
          : '<div class="empty-state" style="margin-bottom:18px">Пока нет открытых заявок — станьте первым.</div>') +
      '<div class="mk-section-head"><h2>Каталог мастеров</h2>' +
      '<button type="button" class="mk-link" data-act="nav" data-screen="masters">Все</button></div>' +
      (state.loadingMasters && !list.length
        ? '<div class="empty-state">Загрузка мастеров…</div>'
        : list.length
          ? '<div class="mk-masters-grid">' + list.map(mkMasterCard).join("") + "</div>"
          : '<div class="empty-state">Пока нет мастеров.</div>') +
      '<button type="button" class="home-materials-banner" data-act="nav" data-screen="materials" style="margin-top:8px">' +
      '<div class="home-materials-banner-icon">' +
      icon("box", "", 24) +
      "</div>" +
      '<div class="home-materials-banner-text"><div class="home-materials-banner-title">Стройматериалы</div>' +
      '<div class="home-materials-banner-desc">Каталог товаров с доставкой</div></div>' +
      '<div class="home-materials-banner-cta">' +
      icon("chevronRight", "", 18) +
      "</div></button></div>"
    );
  };

  window.renderMasters = function () {
    ensureMarketState();
    state.mastersStep = "list";
    if (!state.selectedMasterCategory) state.selectedMasterCategory = "ВСЕ МАСТЕРА";
    var list = filteredMasters();
    var cats = ["ВСЕ МАСТЕРА"].concat(getAllMasterCategories());
    return (
      '<div class="mk-layout">' +
      '<aside class="mk-filters">' +
      "<h3>Фильтры</h3>" +
      "<label>Город</label>" +
      '<select data-act="mk-filter-city">' +
      '<option value="">Все города</option>' +
      cityOptionsList()
        .map(function (c) {
          return (
            '<option value="' +
            escapeHtml(c) +
            '"' +
            (state.searchCity === c ? " selected" : "") +
            ">" +
            escapeHtml(c) +
            "</option>"
          );
        })
        .join("") +
      "</select>" +
      "<label>Категория</label>" +
      '<select data-act="mk-filter-cat">' +
      cats
        .map(function (c) {
          return (
            '<option value="' +
            escapeHtml(c) +
            '"' +
            (state.selectedMasterCategory === c ? " selected" : "") +
            ">" +
            escapeHtml(c) +
            "</option>"
          );
        })
        .join("") +
      "</select>" +
      "<label>Сортировка</label>" +
      '<select data-act="mk-filter-sort">' +
      '<option value="rating"' +
      (state.mastersSort === "rating" ? " selected" : "") +
      ">По рейтингу</option>" +
      '<option value="price_asc"' +
      (state.mastersSort === "price_asc" ? " selected" : "") +
      ">Цена ↑</option>" +
      '<option value="price_desc"' +
      (state.mastersSort === "price_desc" ? " selected" : "") +
      ">Цена ↓</option>" +
      '<option value="fresh"' +
      (state.mastersSort === "fresh" ? " selected" : "") +
      ">Сначала свежие</option>" +
      "</select>" +
      '<label><input type="checkbox" data-act="mk-filter-photo"' +
      (state.mastersOnlyPhoto ? " checked" : "") +
      "> Только с фото работ</label>" +
      '<button type="button" class="btn btn-accent btn-block" data-act="nav" data-screen="publish">Разместить заказ</button>' +
      "</aside>" +
      "<div>" +
      '<div class="section-title">Найдено: ' +
      list.length +
      "</div>" +
      (state.loadingMasters && !list.length
        ? '<div class="empty-state">Загрузка…</div>'
        : list.length
          ? '<div class="mk-masters-grid">' + list.map(mkMasterCard).join("") + "</div>"
          : '<div class="empty-state">Мастера не найдены.</div>') +
      "</div></div>"
    );
  };

  window.renderPublishWork = function () {
    ensureMarketState();
    var oc = state.orderCreate;
    var step = oc.step || 1;
    var stepsHtml = [1, 2, 3, 4]
      .map(function (s) {
        return '<div class="oc-step' + (s <= step ? " on" : "") + '"></div>';
      })
      .join("");

    var body = "";
    if (step === 1) {
      body =
        "<h2>Что нужно сделать?</h2>" +
        '<p class="hint">Шаг 1 из 4 — категория и короткое название</p>' +
        "<label>Категория</label>" +
        '<select data-act="oc-field" data-field="category">' +
        SERVICE_CATS.concat([
          { id: "Сантехник", name: "Сантехник" },
          { id: "Маляр", name: "Маляр" },
          { id: "Разнорабочий", name: "Разнорабочий" },
          { id: "Алюкобонд", name: "Алюкобонд" },
        ])
          .map(function (c) {
            return (
              '<option value="' +
              escapeHtml(c.id) +
              '"' +
              (oc.category === c.id ? " selected" : "") +
              ">" +
              escapeHtml(c.name || c.id) +
              "</option>"
            );
          })
          .join("") +
        "</select>" +
        "<label>Краткое название</label>" +
        '<input type="text" data-act="oc-field" data-field="title" value="' +
        escapeHtml(oc.title || "") +
        '" placeholder="Например: Укладка плитки в ванной">' +
        '<div class="oc-actions">' +
        '<button type="button" class="btn btn-accent" data-act="oc-next">Далее</button></div>';
    } else if (step === 2) {
      body =
        "<h2>Описание и фото</h2>" +
        '<p class="hint">Шаг 2 из 4 — детали объекта</p>' +
        "<label>Описание</label>" +
        '<textarea rows="4" data-act="oc-field" data-field="description" placeholder="Что именно нужно сделать…">' +
        escapeHtml(oc.description || "") +
        "</textarea>" +
        "<label>Фото объекта</label>" +
        '<div class="oc-photos">' +
        (oc.photos || [])
          .map(function (p, i) {
            return (
              '<img class="oc-photo" src="' +
              p.preview +
              '" alt="" data-act="oc-photo-del" data-index="' +
              i +
              '">'
            );
          })
          .join("") +
        '<label class="oc-add-photo">+<input type="file" accept="image/*" hidden data-act="oc-photo-add"></label>' +
        "</div>" +
        '<div class="oc-actions">' +
        '<button type="button" class="btn btn-outline" data-act="oc-prev">Назад</button>' +
        '<button type="button" class="btn btn-accent" data-act="oc-next">Далее</button></div>';
    } else if (step === 3) {
      var cityVal = oc.city || state.searchCity || "";
      body =
        "<h2>Город, адрес и бюджет</h2>" +
        '<p class="hint">Шаг 3 из 4 — где выполнить работу</p>' +
        "<label>Город</label>" +
        '<select data-act="oc-field" data-field="city">' +
        '<option value="">Выберите город</option>' +
        cityOptionsList()
          .map(function (c) {
            return (
              '<option value="' +
              escapeHtml(c) +
              '"' +
              (cityVal === c ? " selected" : "") +
              ">" +
              escapeHtml(c) +
              "</option>"
            );
          })
          .join("") +
        "</select>" +
        "<label>Район / адрес</label>" +
        '<input type="text" data-act="oc-field" data-field="address" value="' +
        escapeHtml(oc.address || "") +
        '" placeholder="Город, район, адрес…">' +
        "<label>Бюджет (TJS), необязательно</label>" +
        '<input type="number" data-act="oc-field" data-field="budget" value="' +
        escapeHtml(oc.budget || "") +
        '" placeholder="500">' +
        '<div class="oc-actions">' +
        '<button type="button" class="btn btn-outline" data-act="oc-prev">Назад</button>' +
        '<button type="button" class="btn btn-accent" data-act="oc-next">Далее</button></div>';
    } else {
      var logged = isLoggedIn() && isClientUser();
      body =
        "<h2>Контакт</h2>" +
        '<p class="hint">Шаг 4 из 4 — войдите как заказчик, чтобы опубликовать заявку</p>' +
        (logged
          ? '<div class="empty-state" style="text-align:left">Вы вошли: ' +
            escapeHtml((state.profileMe && (state.profileMe.phone || state.profileMe.name)) || "клиент") +
            "</div>" +
            (oc.error ? '<div style="color:#DC2626">' + escapeHtml(oc.error) + "</div>" : "") +
            '<div class="oc-actions">' +
            '<button type="button" class="btn btn-outline" data-act="oc-prev">Назад</button>' +
            '<button type="button" class="btn btn-accent" data-act="oc-submit"' +
            (oc.saving ? " disabled" : "") +
            ">" +
            (oc.saving ? "Отправка…" : "Опубликовать") +
            "</button></div>"
          : '<p class="hint">Нужен вход по номеру +992. После входа вернитесь сюда и нажмите «Опубликовать».</p>' +
            '<div class="oc-actions">' +
            '<button type="button" class="btn btn-outline" data-act="oc-prev">Назад</button>' +
            '<button type="button" class="btn btn-accent" data-act="nav" data-screen="client_auth" data-auth-mode="client">Вход / Регистрация</button></div>');
    }

    return (
      '<div class="oc-wrap"><div class="oc-steps">' +
      stepsHtml +
      '</div><div class="oc-card">' +
      body +
      "</div>" +
      (isMasterUser()
        ? '<p class="hint" style="margin-top:14px">Мастерам: лента заказов и CRM — в мобильном приложении Ustobozor. <a href="/download-apk">Скачать APK</a></p>'
        : "") +
      "</div>"
    );
  };

  async function submitServiceRequest() {
    ensureMarketState();
    var oc = state.orderCreate;
    oc.error = "";
    oc.saving = true;
    render();
    try {
      var photos = (oc.photos || []).map(function (p) {
        return p.base64;
      });
      var budget = parseFloat(String(oc.budget || "").replace(",", "."));
      await apiPostJson(
        "/service-requests",
        {
          title: (oc.title || "").trim(),
          category: oc.category,
          description: (oc.description || "").trim(),
          address: (oc.address || "").trim(),
          city: (oc.city || state.searchCity || state.city || "").trim(),
          budget: isNaN(budget) ? null : budget,
          photos_base64: photos,
        },
        true
      );
      state.orderCreate = {
        step: 1,
        title: "",
        category: SERVICE_CATS[0].id,
        description: "",
        address: "",
        city: "",
        budget: "",
        photos: [],
        error: "",
        saving: false,
      };
      alert("Заявка опубликована и ушла в ленту мастеров.");
      setScreen("orders");
    } catch (e) {
      oc.error = e.message || "Не удалось отправить";
      oc.saving = false;
      render();
    }
  }

  document.addEventListener(
    "click",
    function (e) {
      var t = e.target.closest("[data-act]");
      if (!t) return;
      var act = t.getAttribute("data-act");
      if (act === "stop") {
        e.stopPropagation();
        return;
      }
      if (act === "city-open") {
        ensureMarketState();
        state.citySheetOpen = true;
        render();
        return;
      }
      if (act === "city-close") {
        state.citySheetOpen = false;
        render();
        return;
      }
      if (act === "set-city") {
        var val = t.getAttribute("data-val") || "";
        state.searchCity = val;
        if (val) {
          state.city = val;
          state.district = val;
        } else {
          state.city = "";
          state.district = "";
        }
        state.citySheetOpen = false;
        fetchOpenRequests();
        render();
        return;
      }
      if (act === "oc-next") {
        ensureMarketState();
        var oc = state.orderCreate;
        if (oc.step === 1 && (oc.title || "").trim().length < 3) {
          alert("Укажите название (минимум 3 символа)");
          return;
        }
        oc.step = Math.min(4, (oc.step || 1) + 1);
        render();
        return;
      }
      if (act === "oc-prev") {
        ensureMarketState();
        state.orderCreate.step = Math.max(1, (state.orderCreate.step || 1) - 1);
        render();
        return;
      }
      if (act === "oc-submit") {
        submitServiceRequest();
        return;
      }
      if (act === "oc-photo-del") {
        var idx = parseInt(t.getAttribute("data-index"), 10);
        if (!isNaN(idx)) state.orderCreate.photos.splice(idx, 1);
        render();
        return;
      }
    },
    true
  );

  document.addEventListener("change", function (e) {
    var t = e.target;
    if (!t || !t.getAttribute) return;
    var act = t.getAttribute("data-act");
    if (act === "mk-filter-cat") {
      state.selectedMasterCategory = t.value;
      state.mastersStep = "list";
      render();
      return;
    }
    if (act === "mk-filter-city") {
      state.searchCity = t.value || "";
      if (state.searchCity) state.city = state.searchCity;
      render();
      return;
    }
    if (act === "mk-filter-sort") {
      state.mastersSort = t.value;
      render();
      return;
    }
    if (act === "mk-filter-photo") {
      state.mastersOnlyPhoto = !!t.checked;
      render();
      return;
    }
    if (act === "oc-field") {
      ensureMarketState();
      var field = t.getAttribute("data-field");
      if (field) state.orderCreate[field] = t.value;
      return;
    }
    if (act === "oc-photo-add" && t.files && t.files[0]) {
      ensureMarketState();
      if ((state.orderCreate.photos || []).length >= 5) return;
      var file = t.files[0];
      var reader = new FileReader();
      reader.onload = function () {
        var dataUrl = String(reader.result || "");
        var b64 = dataUrl.indexOf(",") >= 0 ? dataUrl.split(",")[1] : dataUrl;
        state.orderCreate.photos.push({ preview: dataUrl, base64: b64 });
        render();
      };
      reader.readAsDataURL(file);
    }
  });

  // Prefer master categories when opening from home chips
  var _origOpenMasterCat = null;
  document.addEventListener(
    "click",
    function (e) {
      var t = e.target.closest('[data-act="open-master-cat"]');
      if (!t) return;
      // after app.js handler sets category — force list view
      setTimeout(function () {
        state.mastersStep = "list";
        if (state.screen !== "masters") setScreen("masters");
        else render();
        syncUrl();
      }, 0);
    },
    false
  );

  var _origOpenMasterDetails = openMasterDetails;
  window.openMasterDetails = function (masterId) {
    _origOpenMasterDetails(masterId);
    syncUrl();
  };

  window.addEventListener("popstate", function () {
    applyPathToScreen();
    render();
    if (state.screen === "home") fetchOpenRequests();
    if (state.screen === "home" || state.screen === "masters" || state.screen === "master_details")
      fetchMastersOnce();
  });

  // Boot after app.js DOMContentLoaded may have already run — schedule after current stack
  function bootMarket() {
    ensureMarketState();
    applyPathToScreen();
    fetchOpenRequests();
    try {
      syncUrl();
    } catch (_) {}
    render();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      setTimeout(bootMarket, 0);
    });
  } else {
    setTimeout(bootMarket, 0);
  }
})();
