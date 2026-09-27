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

module BACommunity
  module MonsieurBezier

    # Перо. Ведёт себя как в векторных редакторах:
    #   клик              — угловой узел без ручек;
    #   клик с протяжкой  — гладкий узел, тянем ручку;
    #   Esc               — шаг назад: убрать последний узел (как у «Линии»);
    #   Enter / двойной клик — закончить;
    #   клик по первому узлу — замкнуть;
    #   число в поле ввода + Enter — сегментов на пролёт.
    #
    # Клавиши намеренно не перехватываются через onKeyDown: Enter и Backspace
    # нужны полю ввода. SketchUp сам разводит их — при пустом поле Enter
    # приходит в onReturn, при набранном числе — в onUserText.
    class BezierTool

      # Цвета — дизайн-код B&A: кривая и узлы акцентом #2B6CB0, ручки —
      # тёмным «железом» #3B3B38, как на иконке. На светлом фоне вьюпорта
      # SketchUp оба читаются.
      CURVE_COLOR  = Sketchup::Color.new(43, 108, 176)
      HANDLE_COLOR = Sketchup::Color.new(59, 59, 56)
      ANCHOR_SIZE  = 6
      CLOSE_PIXELS = 10

      def initialize
        @anchors  = []
        @segments = Settings.read('bezier_segments', 12).to_i
        @segments = 12 unless (1..200).cover?(@segments)
        @dragging = false
        @closing  = false
        @ip       = Sketchup::InputPoint.new
      end

      # --- жизненный цикл ----------------------------------------------------

      def activate
        @anchors.clear
        @dragging = false
        @closing = false
        Sketchup.active_model.active_view.invalidate
        update_status
      end

      def deactivate(view)
        Sketchup.status_text = ''
        view.invalidate
      end

      def resume(view)
        update_status
        view.invalidate
      end

      def suspend(view)
        view.invalidate
      end

      # Esc (reason 0) — шаг назад, по узлу за нажатие. Любая другая причина
      # (смена инструмента, отмена в модели) — бросаем всё.
      def onCancel(reason, view)
        if reason == 0 && !@anchors.empty?
          @anchors.pop
        else
          @anchors.clear
        end
        @dragging = false
        @closing = false
        update_status
        view.invalidate
      end

      # Enter при пустом поле ввода: закончить кривую.
      def onReturn(view)
        finish(view, false)
      end

      def enableVCB?
        true
      end

      # Неверное число — не модалка (она блокирует и SketchUp, и мост),
      # а звук и строка состояния: опечатка того не стоит.
      def onUserText(text, view)
        input = text.strip
        value = input.to_i
        if !input.match?(/\A[0-9]+\z/) || !(1..200).cover?(value)
          UI.beep
          Sketchup.status_text = MonsieurBezier.t(:bad_segments, text)
          return
        else
          @segments = value
          Settings.write('bezier_segments', value)
          view.invalidate
        end
        update_status
      end

      # --- мышь --------------------------------------------------------------

      def onMouseMove(_flags, x, y, view)
        if @dragging && !@anchors.empty?
          @ip.pick(view, x, y)
          @anchors.last.pull_to(@ip.position) if @ip.valid?
        else
          @ip.pick(view, x, y)
          @closing = @anchors.length > 2 && near_first?(view, x, y)
        end
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        @ip.pick(view, x, y)
        return unless @ip.valid?

        if near_first?(view, x, y) && @anchors.length > 2
          finish(view, true)
          return
        end

        @anchors << Bezier::Anchor.new(@ip.position, nil, nil)
        @dragging = true
        update_status
        view.invalidate
      end

      def onLButtonUp(_flags, _x, _y, view)
        @dragging = false
        view.invalidate
      end

      def onLButtonDoubleClick(_flags, _x, _y, view)
        # SketchUp delivers Down, Up, DoubleClick, Up: the double-click
        # replaces the second Down. The last anchor is the intended endpoint.
        finish(view, false)
      end

      # --- отрисовка ---------------------------------------------------------

      def draw(view)
        @ip.draw(view) if @ip.valid?
        draw_curve(view)
        draw_handles(view)
        draw_anchors(view)
      end

      def getExtents
        bounds = Geom::BoundingBox.new
        @anchors.each do |anchor|
          bounds.add(anchor.point)
          bounds.add(anchor.handle_in) if anchor.handle_in
          bounds.add(anchor.handle_out) if anchor.handle_out
        end
        bounds.add(@ip.position) if @ip.valid?
        bounds
      end

      private

      def draw_curve(view)
        points = preview_points
        return if points.length < 2
        view.line_width = 2
        view.drawing_color = CURVE_COLOR
        view.draw(GL_LINE_STRIP, points)
      end

      # То, что уже поставлено, плюс пролёт до курсора: пока тянем ручку,
      # курсор — это ручка, а не следующий узел, и лишнего пролёта нет.
      def preview_points
        return [] if @anchors.empty?
        return Bezier.polyline(@anchors, @segments, true) if @closing && !@dragging
        anchors = @anchors
        if !@dragging && @ip.valid? && !@anchors.empty?
          anchors = @anchors + [Bezier::Anchor.new(@ip.position, nil, nil)]
        end
        Bezier.polyline(anchors, @segments)
      end

      def draw_handles(view)
        view.line_width = 1
        view.drawing_color = HANDLE_COLOR
        @anchors.each do |anchor|
          next if anchor.corner?
          view.draw(GL_LINES, [anchor.handle_in, anchor.point, anchor.point, anchor.handle_out])
          view.draw_points([anchor.handle_in, anchor.handle_out], 5, 2, HANDLE_COLOR)
        end
      end

      def draw_anchors(view)
        return if @anchors.empty?
        style = @closing ? 4 : 2
        view.draw_points(@anchors.map(&:point), ANCHOR_SIZE, style, CURVE_COLOR)
      end

      def near_first?(view, x, y)
        return false if @anchors.empty?
        screen = view.screen_coords(@anchors.first.point)
        (screen.x - x).abs < CLOSE_PIXELS && (screen.y - y).abs < CLOSE_PIXELS
      end

      # --- результат ---------------------------------------------------------

      def finish(view, closed)
        spans = Bezier.spans(@anchors, @segments, closed)
        # SketchUp merges points within its geometric tolerance. Do not send
        # collapsed edges to add_curve (e.g. repeated clicks or tiny spans).
        spans = spans.filter_map do |points|
          clean = points.each_with_object([]) do |point, result|
            result << point if result.empty? || result.last.distance(point).to_f >= 0.001
          end
          clean if clean.length > 1
        end
        if spans.empty?
          @anchors.clear
          @dragging = false
          @closing = false
          update_status
          view.invalidate
          return
        end

        model = Sketchup.active_model
        model.start_operation(MonsieurBezier.t(:op_curve), true)
        begin
          # Каждый пролёт между узлами — своя кривая (add_curve), а не одна
          # на всю цепочку: так пролёт выделяется одним кликом и правится
          # отдельно, а вся цепочка по-прежнему берётся тройным кликом.
          # Прямой пролёт между двумя угловыми узлами — обычное ребро.
          entities = model.active_entities
          spans.each do |points|
            if points.length == 2
              entities.add_line(points[0], points[1])
            else
              entities.add_curve(points)
            end
          end
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end

        @anchors.clear
        @dragging = false
        @closing = false
        update_status
        view.invalidate
      end

      def update_status
        Sketchup.status_text = MonsieurBezier.t(:status, @segments)
        Sketchup.vcb_label = MonsieurBezier.t(:vcb_label)
        Sketchup.vcb_value = @segments.to_s
      end

    end # class BezierTool
  end # module MonsieurBezier
end # module BACommunity
