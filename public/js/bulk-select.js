// Seleccion multiple de registros: casilla "todos", contador y boton habilitado solo con seleccion.
(function () {
  document.querySelectorAll('[data-bulk]').forEach(function (form) {
    var all = form.querySelector('[data-bulk-all]');
    var boxes = Array.prototype.slice.call(form.querySelectorAll('[data-bulk-item]'));
    var btn = form.querySelector('[data-bulk-submit]');
    var counter = form.querySelector('[data-bulk-count]');

    function update() {
      var n = boxes.filter(function (b) { return b.checked; }).length;
      if (btn) btn.disabled = n === 0;
      if (counter) counter.textContent = n ? n + (n === 1 ? ' seleccionado' : ' seleccionados') : '';
      if (all) {
        all.checked = n > 0 && n === boxes.length;
        all.indeterminate = n > 0 && n < boxes.length;
      }
    }

    if (all) {
      all.addEventListener('change', function () {
        boxes.forEach(function (b) { b.checked = all.checked; });
        update();
      });
    }
    boxes.forEach(function (b) { b.addEventListener('change', update); });
    update();
  });
})();
