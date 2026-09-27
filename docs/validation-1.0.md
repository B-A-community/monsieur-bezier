# Monsieur Bézier 1.0 — проверка / validation

Дата / Date: 2026-09-27. Windows, Ruby 3.2.2.

| SketchUp | Русская сборка / Russian | English build |
|---|---|---|
| 2024 — 24.0.484 | 21/21 | 21/21 |
| 2025 — 25.0.660 | 21/21 | 21/21 |
| 2026 — 26.1.256 | 21/21 | 21/21 |

Проверки выполнены через локальный MCP (`/ruby/execute`). Из каждого RBZ
извлечены и загружены Ruby-файлы. `test/live_sketchup.rb` создаёт временную
группу в текущем контексте модели и удаляет её после проверки, восстанавливая
выделение, контекст редактирования и настройку сегментов.

Tests used the local MCP bridge with Ruby files extracted from each RBZ.
The live test creates and removes a temporary group, restoring the edit
context, selection and segment preference. It adds test operations to undo history.

Проверено / Checked:

- Два отдельных криволинейных пролёта по 12 рёбер и один прямой; общие вершины,
  единая связная цепочка / two separate 12-edge curves and a straight span,
  shared vertices and one connected chain.
- Замкнутый контур и отмена всей кривой одним шагом / closed loop and single-step undo.
- Двойной клик сохраняет конечный узел / double-click preserves the endpoint.
- Повторные точки, границы 1/200 сегментов и неверный ввод / coincident points,
  segment limits and invalid input.
- Esc, предпросмотр замыкания, зарегистрированная версия / Escape, closing
  preview and registered version.
- Окно «О плагине» во всех шести сочетаниях версии и языка: 420×300 пикселей
  содержимого, версия 1.0, правильный язык, отсутствие переполнения,
  кнопка закрытия в видимой области / About dialog in all six combinations:
  correct language/version, no overflow, visible close button.
- 31 локальный тест, 133 утверждения / 31 unit tests, 133 assertions.
- Обе одностраничные PDF-инструкции просмотрены после рендеринга / both
  one-page PDF guides rendered and visually inspected.

Последовательность реальных событий двойного клика дополнительно записана
мышью в SketchUp 2025: `Down → Up → DoubleClick → Up` для двойного клика.
Прежнее удаление последнего узла было ошибкой. Остальные прогоны использовали
API и прямые вызовы обработчиков, а не автоматизацию мыши.

The native double-click sequence was additionally observed with mouse input
in SketchUp 2025. The remaining runs used the API and direct tool callbacks.

Границы проверки / Scope: работающие сессии, без перезапуска SketchUp.
Чистая установка через Extension Manager в этом прогоне не подтверждена:
вызов `install_from_archive` через MCP завершился тайм-аутом; для проверки
использована загрузка файлов пакета через Ruby API. macOS не проверялась.

Live sessions were used without restarting SketchUp. A fresh Extension Manager
installation was not verified in this run: `install_from_archive` timed out over
MCP, so package files were loaded through the Ruby API. macOS was not tested.
