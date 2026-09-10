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
    #   клик              — угловой узел, пролёт до него прямой;
    #   клик с протяжкой  — гладкий узел, тянем ручку;
    #   Backspace         — убрать последний узел;
    #   Enter / двойной клик — закончить;
    #   клик по первому узлу — замкнуть;
    #   Esc               — бросить незаконченное;
    #   число в поле ввода — сегментов на пролёт.
    class BezierTool

      CURVE_COLOR  = Sketchup::Color.new(63, 224, 160)
      HANDLE_COLOR = Sketchup::Color.new(180, 60, 60)
      ANCHOR_SIZE  = 6
      CLOSE_PIXELS = 10

      def initialize
        @anchors  = []
        @segments = Settings.read('bezier_segments', 12).to_i
        @dragging = false
        @closing  = false
        @ip       = Sketchup::InputPoint.new
      end

      # --- жизненный цикл ----------------------------------------------------

      def activate
        @anchors.clear
        @dragging = false
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

      def onCancel(_reason, view)
        @anchors.clear
        @dragging = false
        update_status
        view.invalidate
      end

      def enableVCB?
        true
      end

      def onUserText(text, view)
        value = text.to_i
        if value < 1 || value > 200
          UI.messagebox('Сегментов на пролёт: от 1 до 200.')
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
          @closing = near_first?(view, x, y)
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
        # Второй клик двойного уже добавил лишний узел — убираем его.
        @anchors.pop if @anchors.length > 1
        finish(view, false)
      end

      def onKeyDown(key, _repeat, _flags, view)
        case key
        when 13 # Enter
          finish(view, false)
          true
        when 8 # Backspace
          @anchors.pop
          update_status
          view.invalidate
          true
        else
          false
        end
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
        points = Bezier.polyline(@anchors, @segments, closed)
        if points.length < 2
          @anchors.clear
          view.invalidate
          return
        end

        model = Sketchup.active_model
        model.start_operation('Кривая Безье', true)
        begin
          # add_curve делает связную кривую, а не россыпь рёбер: её можно
          # выделить одним кликом и скормить Follow Me.
          model.active_entities.add_curve(points)
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end

        @anchors.clear
        @dragging = false
        update_status
        view.invalidate
      end

      def update_status
        Sketchup.status_text =
          "Безье: клик — угол, клик с протяжкой — гладкий узел, Enter — закончить, " \
          "Backspace — назад. Сегментов на пролёт: #{@segments} (введите число, чтобы изменить)."
        Sketchup.vcb_label = 'Сегментов'
        Sketchup.vcb_value = @segments.to_s
      end

    end # class BezierTool
  end # module MonsieurBezier
end # module BACommunity
