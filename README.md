# Monsieur Bézier — перо для кривых Безье в SketchUp 2024 / 2025 / 2026

**Русский** · [English](README.en.md)

Панель инструментов «Monsieur Bézier» (одна кнопка, показывается при первом
запуске, дальше запоминает состояние) + то же в меню
`Extensions → Monsieur Bézier` (плюс «О плагине…» — авторы, версия, ссылка на
репозиторий).

Сделано по заявке из чата архитекторов: «сплайнов Безье тоже не хватает».

## Скачать

[Релиз 1.0](https://github.com/B-A-community/monsieur-bezier/releases/tag/v1.0) —
два архива, отличаются только языком интерфейса:

| Русский интерфейс | Английский интерфейс |
|---|---|
| `monsieur_bezier-1.0-rus.zip` | `monsieur_bezier-1.0-eng.zip` |

В архиве — плагин `.rbz` и краткая инструкция (PDF).

**Установка:** SketchUp → `Window → Extension Manager → Install Extension` →
выбрать `.rbz` → перезапустить SketchUp. Если панель пропала —
`View → Toolbars → Monsieur Bézier`.

## Перо

Кнопка на панели или `Extensions → Monsieur Bézier → Кривая Безье`. Ведёт себя
как перо в векторных редакторах:

| Действие | Что происходит |
|---|---|
| клик | угловой узел, пролёт до него прямой |
| клик с протяжкой | гладкий узел, тянется ручка (вторая зеркалится сама) |
| клик по первому узлу | замкнуть кривую |
| Enter или двойной клик | закончить |
| Esc | шаг назад: убрать последний узел (как у «Линии») |
| число в поле ввода + Enter | сегментов на пролёт (1–200, по умолчанию 12) |

Клавиши намеренно не перехватываются: Enter и Backspace нужны полю ввода.
SketchUp сам разводит их — при пустом поле Enter заканчивает кривую, при
набранном числе применяет число.

Результат — по кривой (`add_curve`) на каждый пролёт между узлами, а не одна
на всю цепочку: пролёт выделяется одним кликом и правится отдельно, вся
цепочка — тройным кликом. Прямой пролёт между двумя угловыми узлами остаётся
одним ребром, лишних вершин на прямой не появляется. Стыки SketchUp склеивает
в общую вершину, так что для Follow Me это по-прежнему один путь. Вся кривая —
одна операция, Ctrl+Z снимает её целиком.

## Совместимость

Проверено в живых SketchUp: 2024 (24.0.484), 2025 (25.0.660) и 2026 (26.1.256) — Windows,
Ruby 3.2. Подробности — в [CHANGELOG.md](CHANGELOG.md).

## Сборка

```bash
powershell -ExecutionPolicy Bypass -File tools\build_guides.ps1
powershell -ExecutionPolicy Bypass -File build.ps1
```

`tools\build_guides.ps1` печатает `docs\guide-rus.html` / `guide-eng.html` в PDF
(Edge или Chrome без окна). `build.ps1` собирает в `dist\` оба пакета
`monsieur_bezier-<версия>-rus.rbz` / `-eng.rbz` и архивы для релиза
`monsieur_bezier-<версия>-rus.zip` / `-eng.zip` (плагин + PDF). Языковой пакет —
тот же исходник: в копии подменяется строка `LANG` в `lang.rb` и
`html/i18n.js`. Ключи: `-Lang ru|en` — один язык, `-NoZip` — только `.rbz`.

Для разработки: `dev_install.ps1` копирует `src\` в Plugins SketchUp 2024
(`-Version 2025|2026` — в 2025/2026); `tools\su_exec.ps1` выполняет Ruby в
работающем SketchUp через мост `sketchup-mcp` (`-Port` — для второго и
третьего открытого SketchUp: 8080 занимает первый, остальные берут свободный
порт и записывают его в `%LOCALAPPDATA%\complex\instances\`).

## Тесты

Без SketchUp, обычным Ruby 3.2 — на заглушке API:

```bash
ruby test/test_bezier.rb
ruby test/test_lang.rb
```

`test_bezier.rb` — перо: пролёты, стыки, что кладётся в модель, поле ввода.
`test_lang.rb` — словари: одинаковые ключи в обоих языках, совпадающие
плейсхолдеры, у каждого `data-t` окна есть строка, сборка находит `LANG`.

## Структура

```
src/
  monsieur_bezier.rb               регистрация расширения
  monsieur_bezier/
    main.rb                        точка сборки
    lang.rb                        строки Ruby-части (ru/en)
    settings.rb                    предпочтения в реестре SketchUp
    bezier.rb                      кубическая кривая и цепочка пролётов
    bezier_tool.rb                 перо
    about.rb                       окно «О плагине»
    toolbar.rb                     панель инструментов и меню
    html/about.html                разметка окна «О плагине»
    html/i18n.js                   строки окон (ru/en)
    icons/bezier.svg               иконка кнопки
docs/
  guide-rus.html, guide-eng.html   исходники инструкций
  monsieur_bezier-1.0-guide-*.pdf  готовые инструкции (идут в релиз)
test/                              тесты без SketchUp
tools/
  build_guides.ps1                 HTML → PDF
  su_exec.ps1                      Ruby в работающем SketchUp
build.ps1                          сборка .rbz и архивов
dev_install.ps1                    копия в Plugins для разработки
```

Пространство имён — `BACommunity::MonsieurBezier`. Оформление окон и иконки —
по дизайн-коду B&A (`design/designcode.md` в
[RALNCS](https://github.com/B-A-community/ralncs)): светлая тема, акцент
`#2B6CB0`, иконка 24×24 flat. Окно «О плагине» устроено так же, как в RALNCS.

## Грабли

- `Point3d#distance`, `Vector3d#length` и всё, что возвращает `Length`,
  сравнивается **с допуском 0.001"**: `0 < 0.001` даёт `false`. Где длина
  сравнивается с малым порогом — обязателен `.to_f`.
- Инструмент, перехватывающий Enter в `onKeyDown`, ломает поле ввода: SketchUp
  не успевает применить набранное число. Для Enter есть штатный `onReturn`.
- `UI.messagebox` в инструменте — модальное окно: блокирует SketchUp и мост для
  тестов. Для мелких ошибок ввода — `UI.beep` и строка состояния.
- `UI.toolbar_names` перечисляет только встроенные панели SketchUp, Ruby-панелей
  там нет. Искать свою — через `ObjectSpace.each_object(UI::Toolbar)`.
- `main.rb` подключает файлы через `require`: при разработке повторный
  `load main.rb` старый код не заменит, файлы надо `load`-ить по одному.
- `.rbz` — обычный ZIP, загрузчик — **в корне** архива, пути через прямой слэш.
- Скрипты PowerShell с кириллицей — только UTF-8 **с BOM**: без него PS 5.1
  читает их в ANSI. Браузер при печати PDF пишет в stderr — в PS 5.1 при
  `ErrorActionPreference=Stop` это ошибка, поэтому `Start-Process`.
- Папка с «é» в имени ломает `ruby` из консоли с кодировкой 866 — перед
  тестами `chcp 65001`.

## История

Фаска и скругление рёбер были в плагине с 0.1 по 0.3 и в 0.4 вынесены в
отдельный плагин — код в истории репозитория (коммит `010a355`), см.
[CHANGELOG.md](CHANGELOG.md).

## Лицензия

Apache 2.0, правообладатель — организация B&A community (см. `LICENSE` и
`AUTHORS`).
