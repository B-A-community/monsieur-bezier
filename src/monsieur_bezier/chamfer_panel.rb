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
require 'json'

module BACommunity
  module MonsieurBezier

    # Окно фаски: что выделено, каким размером резать, сколько сегментов.
    # Считать умеет chamfer.rb, здесь только разговор с человеком.
    module ChamferPanel

      HTML_FILE = File.join(File.dirname(__FILE__), 'html', 'chamfer.html').freeze

      @dialog = nil

      def self.show
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          push
          return @dialog
        end

        @dialog = UI::HtmlDialog.new(
          dialog_title:    'Фаска и скругление',
          preferences_key: 'BACommunity_MonsieurBezier_Chamfer',
          scrollable:      false,
          resizable:       true,
          width:           500,
          height:          510,
          min_width:       460,
          min_height:      480,
          style:           UI::HtmlDialog::STYLE_DIALOG
        )
        @dialog.set_file(HTML_FILE)
        attach(@dialog)
        @dialog.show
        @dialog
      end

      def self.attach(dialog)
        dialog.add_action_callback('ready') { |_ctx| push }
        dialog.add_action_callback('close') { |_ctx| dialog.close }
        dialog.add_action_callback('refresh') { |_ctx| push }
        dialog.add_action_callback('preview') do |_ctx, size, segments, mode|
          run_preview(size.to_f, segments.to_i, mode.to_s.to_sym)
        end
        dialog.add_action_callback('apply') do |_ctx, size, segments, mode|
          run_apply(size.to_f, segments.to_i, mode.to_s.to_sym)
        end
      end

      # --- что выделено ------------------------------------------------------

      # Рёбра берём из выделения. Выделили группу или компонент — берём все
      # рёбра внутри: так «скруглить всю коробку» делается одним кликом.
      # Негодные рёбра здесь не отсеиваем: это работа движка, он же объяснит.
      def self.selected_edges
        selection = Sketchup.active_model.selection
        edges = selection.grep(Sketchup::Edge)
        selection.each do |entity|
          case entity
          when Sketchup::Group             then edges.concat(entity.entities.grep(Sketchup::Edge))
          when Sketchup::ComponentInstance then edges.concat(entity.definition.entities.grep(Sketchup::Edge))
          end
        end
        edges.uniq.select { |edge| edge.faces.length == 2 }
      end

      def self.push
        edges = selected_edges
        @dialog&.execute_script("app.state(#{JSON.generate(
          edges: edges.length,
          units: unit_name
        )})")
      end

      def self.say(text, kind = 'info')
        @dialog&.execute_script("app.say(#{JSON.generate(text)}, #{JSON.generate(kind)})")
      end

      def self.unit_name
        'мм'
      end

      # --- действия ----------------------------------------------------------

      def self.gather(size, segments)
        edges = selected_edges
        if edges.empty?
          say('Выделите рёбра, группу или компонент — и нажмите «Обновить».', 'warn')
          return nil
        end
        if size <= 0
          say('Размер должен быть больше нуля.', 'warn')
          return nil
        end
        if segments < 1 || segments > 200
          say('Сегментов: от 1 до 200.', 'warn')
          return nil
        end
        parents = edges.map { |edge| edge.parent }.uniq
        if parents.length > 1
          say('Рёбра из разных групп сразу не обработать — выделите что-то одно.', 'warn')
          return nil
        end
        edges
      end

      def self.run_preview(size, segments, mode)
        edges = gather(size, segments)
        return if edges.nil?
        plan = Chamfer.plan(edges, size.mm, segments, mode)
        ChamferPreview.start(Chamfer.preview_lines(plan))
        say("Показано: рёбер #{plan.infos.length}, узлов со сшивкой #{plan.patches.length}. " \
            "#{notes_text(plan.notes)}Esc — убрать превью.")
      rescue Chamfer::Error => e
        say(e.message, 'warn')
      end

      def self.run_apply(size, segments, mode)
        edges = gather(size, segments)
        return if edges.nil?
        ChamferPreview.stop
        result = Chamfer.apply(edges, size.mm, segments, mode: mode)
        say("Готово: рёбер #{result.edges}, новых граней #{result.faces}. " \
            "#{notes_text(result.notes)}Отменяется через Ctrl+Z.", 'ok')
        push
      rescue Chamfer::Error => e
        say(e.message, 'warn')
      end

      def self.notes_text(notes)
        return '' if notes.nil? || notes.empty?
        notes.map { |message, count| "Пропущено #{count}: #{message}." }.join(' ') + ' '
      end

    end # module ChamferPanel

    # Превью во вьюпорте. Ничего не строит — только рисует то, что посчитал
    # план, поэтому его можно гонять сколько угодно и без отмены.
    class ChamferPreview

      # Тот же изумруд, что в панели: инструмент узнаётся по цвету.
      COLOR = Sketchup::Color.new(63, 224, 160)

      def self.start(lines)
        Sketchup.active_model.select_tool(new(lines))
      end

      def self.stop
        Sketchup.active_model.select_tool(nil)
      end

      def initialize(lines)
        @lines = lines
      end

      def activate
        Sketchup.status_text = 'Превью фаски. Esc — убрать.'
        Sketchup.active_model.active_view.invalidate
      end

      def deactivate(view)
        Sketchup.status_text = ''
        view.invalidate
      end

      def resume(view)
        view.invalidate
      end

      def onCancel(_reason, _view)
        Sketchup.active_model.select_tool(nil)
      end

      def draw(view)
        view.line_width = 2
        view.drawing_color = COLOR
        @lines.each { |line| view.draw(GL_LINE_STRIP, line) if line.length > 1 }
      end

      def getExtents
        bounds = Geom::BoundingBox.new
        @lines.each { |line| line.each { |point| bounds.add(point) } }
        bounds
      end

    end # class ChamferPreview
  end # module MonsieurBezier
end # module BACommunity
