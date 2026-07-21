(function (global) {
  var stroke =
    'stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" fill="none"';

  var paths = {
    search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
    home: '<path d="M4 10.5L12 4l8 6.5V19a1 1 0 01-1 1h-5v-6H10v6H5a1 1 0 01-1-1V10.5z"/>',
    grid: '<rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/>',
    menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 19.5c0-3.6 2.9-6.5 6.5-6.5s6.5 2.9 6.5 6.5"/><circle cx="17.5" cy="9" r="2.5"/><path d="M14.5 19.5c.4-2.4 2.5-4 5-4"/>',
    cart: '<circle cx="9" cy="20" r="1.5"/><circle cx="18" cy="20" r="1.5"/><path d="M2 3h2.2l1.8 9.2H18l2.2-8H6"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M5 21c0-4.4 3.1-8 7-8s7 3.6 7 8"/>',
    phone: '<path d="M7 4h2.5l1.2 4.5-1.8 1.3a12 12 0 005 5L15 13l4.5 1.2V19a2 2 0 01-2 2A15 15 0 013 7 2 2 0 015 5z"/>',
    message: '<path d="M21 14.5a4.5 4.5 0 01-4.5 4.5H8l-5 3V7.5A4.5 4.5 0 017.5 3h11A4.5 4.5 0 0121 7.5v7z"/>',
    heart: '<path d="M12 20.5l-1.2-1.1C5.4 14.8 2 11.9 2 8.5A4.5 4.5 0 017.5 4 5.5 5.5 0 0112 6.2 5.5 5.5 0 0116.5 4 4.5 4.5 0 0122 8.5c0 3.4-3.4 6.3-8.8 10.9L12 20.5z"/>',
    close: '<path d="M6 6l12 12M18 6L6 18"/>',
    chevronLeft: '<path d="M14 7l-6 5 6 5"/>',
    chevronRight: '<path d="M10 7l6 5-6 5"/>',
    package: '<path d="M12 3l9 5v8l-9 5-9-5V8z"/><path d="M12 12l9-5M12 12v10M12 12L3 7"/>',
    hammer: '<path d="M14.5 3.5l6 6-3.5 3.5-2-2-5.5 5.5-3-3 5.5-5.5-2-2 3.5-3.5z"/>',
    truck: '<path d="M3 7h11v8H3z"/><path d="M14 10h4l2 3v2h-6V10z"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/>',
    layers: '<path d="M12 3l9 5-9 5-9-5 9-5z"/><path d="M3 12l9 5 9-5"/><path d="M3 17l9 5 9-5"/>',
    box: '<path d="M4 8l8-4 8 4v8l-8 4-8-4V8z"/><path d="M12 4v16M4 8l8 4 8-4"/>',
    bell: '<path d="M18 16H6l-1-2v-5a7 7 0 0114 0v5l-1 2z"/><path d="M10 20a2 2 0 004 0"/>',
    megaphone: '<path d="M4 10v4l8 4V6L4 10z"/><path d="M16 8a4 4 0 010 8"/><path d="M18 6v12"/>',
    mapPin: '<path d="M12 21s7-4.5 7-11a7 7 0 10-14 0c0 6.5 7 11 7 11z"/><circle cx="12" cy="10" r="2.5"/>',
    globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"/>',
    moon: '<path d="M21 14.5A8.5 8.5 0 1111.5 3a7 7 0 109.5 11.5z"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M2 12h2M20 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4"/>',
    check: '<path d="M5 12l4 4L19 6"/>',
    folder: '<path d="M4 7h5l2 2h9v10H4V7z"/>',
    lock: '<rect x="6" y="10" width="12" height="10" rx="2"/><path d="M8 10V8a4 4 0 018 0v2"/>',
  };

  global.icon = function icon(name, className, size) {
    var body = paths[name] || paths.grid;
    var sz = size || 20;
    var cls = "ico" + (className ? " " + className : "");
    return (
      '<svg class="' +
      cls +
      '" viewBox="0 0 24 24" width="' +
      sz +
      '" height="' +
      sz +
      '" aria-hidden="true" ' +
      stroke +
      ">" +
      body +
      "</svg>"
    );
  };
})(window);
