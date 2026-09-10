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

    # Кубическая кривая Безье и цепочка из них.
    #
    # Узел (anchor) хранит саму точку и две ручки. Ручки всегда симметричны
    # относительно узла, пока пользователь не сломает узел явно: так кривая
    # остаётся гладкой, а перо ведёт себя как в векторных редакторах.
    module Bezier

      # Узел цепочки. handle_out — та, которую тянут мышью; handle_in — её
      # зеркало. Обе лежат в мировых координатах, а не смещениями: так проще
      # рисовать превью и не терять точность на длинных кривых.
      Anchor = Struct.new(:point, :handle_in, :handle_out) do
        def corner?
          handle_out.nil? || handle_out.distance(point).to_f < 1.0e-6
        end

        # Ставит обе ручки по одной вытянутой: узел остаётся гладким.
        def pull_to(target)
          self.handle_out = target
          vec = point - target
          self.handle_in = point.offset(vec)
        end
      end

      module_function

      # Точка на кубической кривой по алгоритму де Кастельжо. Он чуть дороже
      # разложения по многочленам Бернштейна, зато численно устойчив и его
      # видно глазами: это просто три последовательные линейные интерполяции.
      def cubic_point(p0, p1, p2, p3, t)
        a = lerp(p0, p1, t)
        b = lerp(p1, p2, t)
        c = lerp(p2, p3, t)
        lerp(lerp(a, b, t), lerp(b, c, t), t)
      end

      def lerp(a, b, t)
        Geom::Point3d.new(a.x + (b.x - a.x) * t,
                          a.y + (b.y - a.y) * t,
                          a.z + (b.z - a.z) * t)
      end

      # Один пролёт: segments отрезков, обе крайние точки включительно.
      def span_points(p0, p1, p2, p3, segments)
        (0..segments).map { |i| cubic_point(p0, p1, p2, p3, i.to_f / segments) }
      end

      # Управляющие точки пролёта между двумя узлами. Если у узла ручки нет,
      # он угловой: контрольная точка садится на сам узел и пролёт становится
      # прямым — так одним инструментом рисуются и кривые, и ломаные.
      def span_controls(from, to)
        c1 = from.handle_out || from.point
        c2 = to.handle_in || to.point
        [from.point, c1, c2, to.point]
      end

      # Пролёт между двумя угловыми узлами — это отрезок, и дробить его не на
      # что. Формально кубика с обеими контрольными точками в концах тоже даёт
      # прямую, но раскладывает вершины неравномерно, со сгущением к концам:
      # в модель попал бы десяток лишних точек на ровном месте.
      def straight_span?(from, to)
        from.corner? && to.corner?
      end

      # Вся цепочка одной ломаной. Стыки не дублируются.
      def polyline(anchors, segments, closed = false)
        return [] if anchors.length < 2
        list = closed ? anchors + [anchors.first] : anchors
        points = [list.first.point]
        list.each_cons(2) do |from, to|
          if straight_span?(from, to)
            points << to.point
          else
            p0, p1, p2, p3 = span_controls(from, to)
            points.concat(span_points(p0, p1, p2, p3, segments).drop(1))
          end
        end
        points
      end

    end # module Bezier
  end # module MonsieurBezier
end # module BACommunity
