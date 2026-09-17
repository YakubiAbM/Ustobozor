(() => {
  const API = "/admin/api";
  const $ = (id) => document.getElementById(id);
  const state = {
    me: null,
    page: "dashboard",
    cache: {},
  };

  const PAGES = [
    { id: "dashboard", title: "Дашборд", scope: "dashboard" },
    { id: "orders", title: "Заказы магазина", scope: "orders" },
    { id: "products", title: "Товары", scope: "products" },
    { id: "masters", title: "Мастера", scope: "masters" },
    { id: "services", title: "Услуги", scope: "masters" },
    { id: "serviceOrders", title: "Заказы услуг", scope: "masters" },
    { id: "balances", title: "Балансы", scope: "cashier" },
    { id: "cashier", title: "Касса / должники", scope: "cashier" },
    { id: "admins", title: "Админы", scope: "admins", superOnly: true },
  ];

  function esc(s) {
    return String(s ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;");
  }

  function flash(msg, isErr = false) {
    const el = $("flash");
    el.textContent = msg;
    el.classList.toggle("err", !!isErr);
    el.classList.remove("hidden");
    clearTimeout(flash._t);
    flash._t = setTimeout(() => el.classList.add("hidden"), 3500);
  }

  async function api(path, opts = {}) {
    const res = await fetch(API + path, {
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
        ...(opts.headers || {}),
      },
      ...opts,
    });
    let data = null;
    const text = await res.text();
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = { detail: text };
    }
    if (res.status === 401) {
      showLogin();
      throw new Error("Нужен вход");
    }
    if (!res.ok) {
      const detail = data?.detail;
      const msg = typeof detail === "string"
        ? detail
        : Array.isArray(detail)
          ? detail.map((d) => d.msg || JSON.stringify(d)).join("; ")
          : `Ошибка ${res.status}`;
      throw new Error(msg);
    }
    return data;
  }

  function can(scope) {
    if (!state.me) return false;
    if (state.me.is_superadmin) return true;
    const perms = state.me.permissions || [];
    return perms.includes(scope);
  }

  function showLogin() {
    $("app-view").classList.add("hidden");
    $("login-view").classList.remove("hidden");
  }

  function showApp() {
    $("login-view").classList.add("hidden");
    $("app-view").classList.remove("hidden");
    renderNav();
    $("user-chip").textContent = state.me?.name
      ? `${state.me.name}${state.me.is_superadmin ? " · супер" : ""}`
      : "Админ";
    go(state.page);
  }

  function renderNav() {
    const nav = $("nav");
    nav.innerHTML = "";
    PAGES.forEach((p) => {
      if (p.superOnly && !state.me?.is_superadmin) return;
      if (p.scope && !can(p.scope)) return;
      const b = document.createElement("button");
      b.type = "button";
      b.className = "nav-btn" + (state.page === p.id ? " active" : "");
      b.textContent = p.title;
      b.onclick = () => go(p.id);
      nav.appendChild(b);
    });
  }

  async function go(pageId) {
    const meta = PAGES.find((p) => p.id === pageId) || PAGES[0];
    if (meta.scope && !can(meta.scope)) {
      const first = PAGES.find((p) => (!p.superOnly || state.me?.is_superadmin) && can(p.scope));
      pageId = first?.id || "dashboard";
    }
    state.page = pageId;
    if (location.hash.replace(/^#/, "") !== pageId) {
      history.replaceState(null, "", `#${pageId}`);
    }
    renderNav();
    $("page-title").textContent = (PAGES.find((p) => p.id === pageId) || {}).title || "Админка";
    const content = $("content");
    content.innerHTML = `<div class="muted">Загрузка…</div>`;
    try {
      if (pageId === "dashboard") await renderDashboard(content);
      else if (pageId === "orders") await renderOrders(content);
      else if (pageId === "products") await renderProducts(content);
      else if (pageId === "masters") await renderMasters(content);
      else if (pageId === "services") await renderServices(content);
      else if (pageId === "serviceOrders") await renderServiceOrders(content);
      else if (pageId === "balances") await renderBalances(content);
      else if (pageId === "cashier") await renderCashier(content);
      else if (pageId === "admins") await renderAdmins(content);
    } catch (e) {
      content.innerHTML = `<div class="error">${esc(e.message)}</div>`;
    }
  }

  async function renderDashboard(el) {
    const d = await api("/dashboard");
    el.innerHTML = `
      <div class="cards">
        <div class="card"><div class="label">Новые заказы</div><div class="value">${d.new_orders_count}</div></div>
        <div class="card"><div class="label">Заказы сегодня</div><div class="value">${d.orders_today_count}</div></div>
        <div class="card"><div class="label">Выручка online</div><div class="value">${Math.round(d.online_revenue)}</div></div>
        <div class="card"><div class="label">Мастера</div><div class="value">${d.total_masters}</div></div>
        <div class="card"><div class="label">Товары</div><div class="value">${d.products_count}</div></div>
      </div>
      <h3>Последние заказы</h3>
      <div class="table-wrap">${ordersTable(d.recent_orders || [])}</div>
    `;
  }

  function ordersTable(rows, withActions = false) {
    if (!rows.length) return `<div style="padding:16px" class="muted">Пусто</div>`;
    return `<table>
      <thead><tr><th>ID</th><th>Клиент</th><th>Сумма</th><th>Статус</th><th>Дата</th>${withActions ? "<th></th>" : ""}</tr></thead>
      <tbody>
        ${rows.map((o) => `<tr>
          <td>#${o.id}</td>
          <td>${esc(o.client_name)}<br><span class="muted">${esc(o.client_phone)}</span></td>
          <td>${esc(o.total_price)}</td>
          <td><span class="badge ${esc(o.status)}">${esc(o.status)}</span></td>
          <td>${esc(o.created_at)}</td>
          ${withActions ? `<td class="row-actions">
            <button class="btn secondary" data-st="completed" data-id="${o.id}">Готово</button>
            <button class="btn secondary" data-st="cancelled" data-id="${o.id}">Отмена</button>
          </td>` : ""}
        </tr>`).join("")}
      </tbody></table>`;
  }

  async function renderOrders(el) {
    const rows = await api("/orders");
    el.innerHTML = `
      <div class="toolbar">
        <button class="btn secondary" id="reload-orders">Обновить</button>
      </div>
      <div class="table-wrap">${ordersTable(rows, true)}</div>
    `;
    $("reload-orders").onclick = () => go("orders");
    el.querySelectorAll("[data-st]").forEach((btn) => {
      btn.onclick = async () => {
        try {
          await api(`/orders/${btn.dataset.id}/status`, {
            method: "POST",
            body: JSON.stringify({ new_status: btn.dataset.st }),
          });
          flash("Статус обновлён");
          go("orders");
        } catch (e) {
          flash(e.message, true);
        }
      };
    });
  }

  async function renderProducts(el) {
    const rows = await api("/products");
    el.innerHTML = `
      <div class="toolbar"><span class="muted">${rows.length} товаров</span>
        <button class="btn secondary" id="reload-products">Обновить</button>
      </div>
      <div class="table-wrap"><table>
        <thead><tr><th>ID</th><th>Название</th><th>Цена</th><th>Категория</th><th>Бренд</th><th></th></tr></thead>
        <tbody>
          ${rows.slice(0, 200).map((p) => `<tr>
            <td>${p.id}</td>
            <td>${esc(p.name)}</td>
            <td>${esc(p.price)}</td>
            <td>${esc(p.category)}</td>
            <td>${esc(p.brand || "")}</td>
            <td><button class="btn danger" data-del="${p.id}">Удалить</button></td>
          </tr>`).join("")}
        </tbody>
      </table></div>
    `;
    $("reload-products").onclick = () => go("products");
    el.querySelectorAll("[data-del]").forEach((btn) => {
      btn.onclick = async () => {
        if (!confirm("Удалить товар #" + btn.dataset.del + "?")) return;
        try {
          await api(`/products/${btn.dataset.del}`, { method: "DELETE" });
          flash("Удалено");
          go("products");
        } catch (e) {
          flash(e.message, true);
        }
      };
    });
  }

  async function renderMasters(el) {
    const rows = await api("/masters");
    el.innerHTML = `
      <div class="toolbar">
        <button class="btn" id="add-master">+ Мастер</button>
        <button class="btn secondary" id="reload-masters">Обновить</button>
      </div>
      <div class="table-wrap"><table>
        <thead><tr><th>ID</th><th>Имя</th><th>Телефон</th><th>Город</th><th>★</th><th>Модерация</th><th></th></tr></thead>
        <tbody>
          ${rows.map((m) => `<tr>
            <td>${m.id}</td>
            <td>${esc(m.name)}</td>
            <td>${esc(m.phone)}</td>
            <td>${esc(m.city || "")}</td>
            <td>${esc(m.rating)} (${esc(m.reviews_count ?? 0)})</td>
            <td>${esc(m.moderation_status || "")}</td>
            <td class="row-actions">
              <button class="btn secondary" data-approve="${m.id}">Одобрить</button>
              <button class="btn danger" data-delm="${m.id}">Удалить</button>
            </td>
          </tr>`).join("")}
        </tbody>
      </table></div>
    `;
    $("reload-masters").onclick = () => go("masters");
    $("add-master").onclick = () => openMasterModal();
    el.querySelectorAll("[data-approve]").forEach((btn) => {
      btn.onclick = async () => {
        try {
          await api(`/masters/${btn.dataset.approve}/approve`, { method: "POST", body: "{}" });
          flash("Одобрен");
          go("masters");
        } catch (e) { flash(e.message, true); }
      };
    });
    el.querySelectorAll("[data-delm]").forEach((btn) => {
      btn.onclick = async () => {
        if (!confirm("Удалить мастера #" + btn.dataset.delm + "?")) return;
        try {
          await api(`/masters/${btn.dataset.delm}`, { method: "DELETE" });
          flash("Удалён");
          go("masters");
        } catch (e) { flash(e.message, true); }
      };
    });
  }

  function openMasterModal() {
    const back = document.createElement("div");
    back.className = "modal-back";
    back.innerHTML = `
      <form class="modal" id="master-form">
        <h3>Новый мастер</h3>
        <input name="name" placeholder="Имя" required />
        <input name="phone" placeholder="Телефон" required />
        <input name="city" placeholder="Город" />
        <textarea name="description" placeholder="Описание" rows="3"></textarea>
        <div class="row-actions">
          <button class="btn" type="submit">Сохранить</button>
          <button class="btn secondary" type="button" id="m-cancel">Отмена</button>
        </div>
      </form>`;
    document.body.appendChild(back);
    back.querySelector("#m-cancel").onclick = () => back.remove();
    back.querySelector("#master-form").onsubmit = async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const body = Object.fromEntries(fd.entries());
      body.categories = [];
      body.services = [];
      body.portfolio = [];
      try {
        await api("/masters", { method: "POST", body: JSON.stringify(body) });
        flash("Мастер создан");
        back.remove();
        go("masters");
      } catch (err) {
        flash(err.message, true);
      }
    };
  }

  async function renderServices(el) {
    const [cats, services] = await Promise.all([
      api("/service-categories"),
      api("/service-catalog"),
    ]);
    el.innerHTML = `
      <div class="toolbar">
        <button class="btn" id="add-service">+ Услуга</button>
        <button class="btn secondary" id="reload-services">Обновить</button>
      </div>
      <div class="table-wrap"><table>
        <thead><tr><th>ID</th><th>Категория</th><th>Услуга</th><th>Цена</th><th>Активна</th><th></th></tr></thead>
        <tbody>
          ${services.map((s) => `<tr>
            <td>${s.id}</td>
            <td>${esc(s.category_name)}</td>
            <td>${esc(s.title)}</td>
            <td>${esc(s.price_client)}</td>
            <td>${s.is_active ? "да" : "нет"}</td>
            <td><button class="btn danger" data-dels="${s.id}">Выкл</button></td>
          </tr>`).join("")}
        </tbody>
      </table></div>
    `;
    $("reload-services").onclick = () => go("services");
    $("add-service").onclick = () => {
      const back = document.createElement("div");
      back.className = "modal-back";
      back.innerHTML = `
        <form class="modal" id="svc-form">
          <h3>Новая услуга</h3>
          <select name="category_id" required>
            ${cats.map((c) => `<option value="${c.id}">${esc(c.name)}</option>`).join("")}
          </select>
          <input name="title" placeholder="Название" required />
          <input name="price_client" type="number" step="0.01" placeholder="Цена клиенту" required />
          <div class="row-actions">
            <button class="btn" type="submit">Сохранить</button>
            <button class="btn secondary" type="button" id="s-cancel">Отмена</button>
          </div>
        </form>`;
      document.body.appendChild(back);
      back.querySelector("#s-cancel").onclick = () => back.remove();
      back.querySelector("#svc-form").onsubmit = async (e) => {
        e.preventDefault();
        const fd = new FormData(e.target);
        const body = {
          category_id: Number(fd.get("category_id")),
          title: fd.get("title"),
          price_client: Number(fd.get("price_client")),
          commission_fee: 0,
          is_active: true,
        };
        try {
          await api("/service-catalog", { method: "POST", body: JSON.stringify(body) });
          flash("Услуга добавлена");
          back.remove();
          go("services");
        } catch (err) { flash(err.message, true); }
      };
    };
    el.querySelectorAll("[data-dels]").forEach((btn) => {
      btn.onclick = async () => {
        try {
          await api(`/service-catalog/${btn.dataset.dels}`, { method: "DELETE" });
          flash("Отключено");
          go("services");
        } catch (e) { flash(e.message, true); }
      };
    });
  }

  async function renderServiceOrders(el) {
    const rows = await api("/service-orders");
    el.innerHTML = `
      <div class="toolbar"><button class="btn secondary" id="reload-so">Обновить</button></div>
      <div class="table-wrap"><table>
        <thead><tr><th>ID</th><th>Услуга</th><th>Клиент</th><th>Мастер</th><th>Статус</th><th>Когда</th><th>Адрес</th></tr></thead>
        <tbody>
          ${rows.map((o) => `<tr>
            <td>${o.id}</td>
            <td>${esc(o.service_title)} · ${esc(o.price_client)} с</td>
            <td>${esc(o.client_name)}<br><span class="muted">${esc(o.client_phone)}</span></td>
            <td>${esc(o.master_name || o.master_id || "—")}</td>
            <td><span class="badge ${esc(o.status)}">${esc(o.status)}</span></td>
            <td>${esc(o.scheduled_date)} ${esc(o.scheduled_time)}</td>
            <td>${esc(o.address_text || o.address)}</td>
          </tr>`).join("")}
        </tbody>
      </table></div>
    `;
    $("reload-so").onclick = () => go("serviceOrders");
  }

  async function renderBalances(el) {
    const rows = await api("/master-balances");
    el.innerHTML = `
      <div class="toolbar">
        <button class="btn" id="topup-btn">Пополнить</button>
        <button class="btn secondary" id="reload-bal">Обновить</button>
      </div>
      <div class="table-wrap"><table>
        <thead><tr><th>Мастер</th><th>Телефон</th><th>Баланс</th></tr></thead>
        <tbody>
          ${rows.map((r) => `<tr>
            <td>#${r.master_id} ${esc(r.name || "")}</td>
            <td>${esc(r.phone || "")}</td>
            <td><b>${r.balance == null ? "—" : esc(r.balance)}</b></td>
          </tr>`).join("")}
        </tbody>
      </table></div>
    `;
    $("reload-bal").onclick = () => go("balances");
    $("topup-btn").onclick = () => {
      const back = document.createElement("div");
      back.className = "modal-back";
      back.innerHTML = `
        <form class="modal" id="topup-form">
          <h3>Пополнение баланса</h3>
          <input name="master_id" type="number" placeholder="ID мастера" required />
          <input name="amount" type="number" step="0.01" placeholder="Сумма" required />
          <input name="note" placeholder="Комментарий" />
          <div class="row-actions">
            <button class="btn" type="submit">Пополнить</button>
            <button class="btn secondary" type="button" id="t-cancel">Отмена</button>
          </div>
        </form>`;
      document.body.appendChild(back);
      back.querySelector("#t-cancel").onclick = () => back.remove();
      back.querySelector("#topup-form").onsubmit = async (e) => {
        e.preventDefault();
        const fd = new FormData(e.target);
        try {
          await api("/master-balances/topup", {
            method: "POST",
            body: JSON.stringify({
              master_id: Number(fd.get("master_id")),
              amount: Number(fd.get("amount")),
              note: fd.get("note") || "",
            }),
          });
          flash("Баланс пополнен");
          back.remove();
          go("balances");
        } catch (err) { flash(err.message, true); }
      };
    };
  }

  async function renderCashier(el) {
    const [summary, debtors] = await Promise.all([
      api("/cashier/summary"),
      api("/cashier/debtors"),
    ]);
    el.innerHTML = `
      <div class="cards">
        <div class="card"><div class="label">Транзакций сегодня</div><div class="value">${summary.operations_today ?? "—"}</div></div>
        <div class="card"><div class="label">Сумма сегодня</div><div class="value">${summary.revenue_today ?? "—"}</div></div>
      </div>
      <h3>Должники</h3>
      <div class="table-wrap"><table>
        <thead><tr><th>Мастер</th><th>Телефон</th><th>Долг</th></tr></thead>
        <tbody>
          ${(debtors || []).map((d) => `<tr>
            <td>${esc(d.name || d.master_name || d.id)}</td>
            <td>${esc(d.phone || "")}</td>
            <td><b>${esc(d.debt)}</b></td>
          </tr>`).join("") || `<tr><td colspan="3" class="muted">Нет должников</td></tr>`}
        </tbody>
      </table></div>
    `;
  }

  async function renderAdmins(el) {
    const rows = await api("/admins");
    el.innerHTML = `
      <div class="toolbar">
        <button class="btn" id="add-admin">+ Админ</button>
        <button class="btn secondary" id="reload-admins">Обновить</button>
      </div>
      <div class="table-wrap"><table>
        <thead><tr><th>ID</th><th>Имя</th><th>Телефон</th><th>Права</th><th></th></tr></thead>
        <tbody>
          ${rows.map((a) => `<tr>
            <td>${a.id}</td>
            <td>${esc(a.name)}</td>
            <td>${esc(a.phone)}</td>
            <td>${esc((a.permissions || []).join(", "))}</td>
            <td><button class="btn danger" data-dela="${a.id}">Удалить</button></td>
          </tr>`).join("")}
        </tbody>
      </table></div>
    `;
    $("reload-admins").onclick = () => go("admins");
    $("add-admin").onclick = () => {
      const back = document.createElement("div");
      back.className = "modal-back";
      back.innerHTML = `
        <form class="modal" id="admin-form">
          <h3>Новый админ</h3>
          <input name="name" placeholder="Имя" required />
          <input name="phone" placeholder="Телефон" required />
          <input name="pin" placeholder="PIN (4+)" required />
          <div class="muted">Права: dashboard, orders, products, masters, cashier</div>
          <input name="permissions" placeholder="dashboard,orders,products,masters,cashier" />
          <div class="row-actions">
            <button class="btn" type="submit">Создать</button>
            <button class="btn secondary" type="button" id="a-cancel">Отмена</button>
          </div>
        </form>`;
      document.body.appendChild(back);
      back.querySelector("#a-cancel").onclick = () => back.remove();
      back.querySelector("#admin-form").onsubmit = async (e) => {
        e.preventDefault();
        const fd = new FormData(e.target);
        const perms = String(fd.get("permissions") || "")
          .split(",")
          .map((x) => x.trim())
          .filter(Boolean);
        try {
          await api("/admins", {
            method: "POST",
            body: JSON.stringify({
              name: fd.get("name"),
              phone: fd.get("phone"),
              pin: fd.get("pin"),
              permissions: perms,
            }),
          });
          flash("Админ создан");
          back.remove();
          go("admins");
        } catch (err) { flash(err.message, true); }
      };
    };
    el.querySelectorAll("[data-dela]").forEach((btn) => {
      btn.onclick = async () => {
        if (!confirm("Удалить админа?")) return;
        try {
          await api(`/admins/${btn.dataset.dela}`, { method: "DELETE" });
          flash("Удалён");
          go("admins");
        } catch (e) { flash(e.message, true); }
      };
    });
  }

  $("login-form").onsubmit = async (e) => {
    e.preventDefault();
    $("login-error").textContent = "";
    $("login-btn").disabled = true;
    try {
      const res = await fetch("/admin/login", {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          phone: $("login-phone").value.trim(),
          password: $("login-pass").value,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.detail || "Ошибка входа");
      state.me = await api("/me");
      showApp();
    } catch (err) {
      $("login-error").textContent = err.message || "Ошибка";
    } finally {
      $("login-btn").disabled = false;
    }
  };

  $("logout-btn").onclick = async () => {
    try { await fetch("/admin/logout", { credentials: "include" }); } catch (_) {}
    state.me = null;
    showLogin();
  };

  async function boot() {
    const hash = (location.hash || "").replace(/^#/, "");
    if (hash && PAGES.some((p) => p.id === hash)) state.page = hash;
    try {
      state.me = await api("/me");
      showApp();
    } catch {
      showLogin();
    }
  }

  boot();
})();
