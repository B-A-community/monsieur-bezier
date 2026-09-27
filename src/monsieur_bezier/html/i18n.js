// Язык интерфейса окон. build.ps1 подменяет первую строку.
var LANG = 'ru';

var I18N = {
  ru: {
    about_title: 'О плагине Monsieur Bézier',
    about_desc: 'Перо для кривых Безье в SketchUp: гладкие и угловые узлы, как в векторных редакторах. Каждый пролёт — отдельная кривая.',
    about_authors: 'Авторы',
    about_names: 'Ruslan Tkachenko и Maksar Sanjeev',
    about_ver: 'версия ',
    about_lic: 'Apache 2.0 · B&A community',
    btn_close: 'Закрыть'
  },

  en: {
    about_title: 'About Monsieur Bézier',
    about_desc: 'A Bézier pen for SketchUp: smooth and corner nodes, just like in vector editors. Every span is a separate curve.',
    about_authors: 'Authors',
    about_names: 'Ruslan Tkachenko and Maksar Sanjeev',
    about_ver: 'version ',
    about_lic: 'Apache 2.0 · B&A community',
    btn_close: 'Close'
  }
};

var T = I18N[LANG] || I18N.ru;
function t(key) { var s = T[key]; return s === undefined ? key : s; }
// Разметка держит русский текст как запасной; data-t переводит на месте.
function applyLang() {
  document.documentElement.lang = LANG;
  document.querySelectorAll('[data-t]').forEach(function (el) { el.textContent = t(el.getAttribute('data-t')); });
  var title = document.querySelector('title[data-t]');
  if (title) document.title = t(title.getAttribute('data-t'));
}
