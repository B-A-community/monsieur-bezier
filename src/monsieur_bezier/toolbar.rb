# Copyright 2026 B&A community
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'sketchup.rb'

# Оформление плагина: панель инструментов и меню.
# Математика кривой — в bezier.rb, само перо — в bezier_tool.rb.
module BACommunity
  module MonsieurBezier

    TOOLBAR_NAME = 'Monsieur Bézier'.freeze
    MENU_NAME    = 'Monsieur Bézier'.freeze
    ICONS_DIR    = File.join(File.dirname(__FILE__), 'icons').freeze

    # Подписи — из lang.rb: сборка подменяет язык, код кнопок один на оба.
    BUTTONS = [
      {
        icon:    'bezier',
        title:   MonsieurBezier.t(:cmd_bezier),
        tooltip: MonsieurBezier.t(:tip_bezier),
        status:  MonsieurBezier.t(:bar_bezier),
        action:  -> { Sketchup.active_model.select_tool(BezierTool.new) }
      }
    ].freeze

    # Пара путей [большая иконка, маленькая]. SVG понимает только
    # Windows-версия SketchUp (2016+), macOS вместо него требует PDF —
    # поэтому там откатываемся на PNG.
    def self.icon_paths(name)
      svg = File.join(ICONS_DIR, "#{name}.svg")
      if Sketchup.platform == :platform_win && File.exist?(svg)
        [svg, svg]
      else
        [File.join(ICONS_DIR, "#{name}_24.png"), File.join(ICONS_DIR, "#{name}_16.png")]
      end
    end

    def self.build_command(spec)
      cmd = UI::Command.new(spec[:title]) { spec[:action].call }

      large_icon, small_icon = icon_paths(spec[:icon])
      # Иконку ставим только если файл на месте: иначе SketchUp ругается,
      # а кнопка и без картинки останется рабочей.
      cmd.large_icon = large_icon if File.exist?(large_icon)
      cmd.small_icon = small_icon if File.exist?(small_icon)

      cmd.tooltip         = spec[:tooltip]
      cmd.status_bar_text = spec[:status]
      cmd
    end

    def self.create_toolbar
      toolbar = UI::Toolbar.new(TOOLBAR_NAME)
      BUTTONS.each { |spec| toolbar.add_item(build_command(spec)) }

      # Первый запуск — показываем панель, дальше уважаем выбор пользователя.
      if toolbar.get_last_state == TB_NEVER_SHOWN
        toolbar.show
      else
        toolbar.restore
      end
      toolbar
    end

    # «О плагине…» — только в меню, под разделителем, как в RALNCS:
    # на панели инструментов место для того, чем рисуют.
    def self.create_menu
      menu = UI.menu('Extensions').add_submenu(MENU_NAME)
      BUTTONS.each { |spec| menu.add_item(spec[:title]) { spec[:action].call } }
      menu.add_separator
      menu.add_item(MonsieurBezier.t(:menu_about)) { About.show }
      menu
    end

  end # module MonsieurBezier
end # module BACommunity
