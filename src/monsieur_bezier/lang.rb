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

# Язык Ruby-части (меню, подсказки, строка состояния, операции). build.ps1
# подменяет строку LANG в копии исходника; окно «О плагине» берёт язык из
# html/i18n.js — там та же подмена.

module BACommunity
  module MonsieurBezier

    LANG = 'ru'

    STRINGS = {
      'ru' => {
        ext_description: 'Перо для кривых Безье: гладкие и угловые узлы, ' \
                         'каждый пролёт — отдельная кривая.',
        cmd_bezier:      'Кривая Безье',
        tip_bezier:      'Нарисовать кривую Безье',
        bar_bezier:      'Клик — угловой узел, клик с протяжкой — гладкий; ' \
                         'Enter — закончить, Esc — шаг назад',
        menu_about:      'О плагине…',
        title_about:     'О плагине Monsieur Bézier',
        status:          'Безье: клик — угол, клик с протяжкой — гладкий узел, ' \
                         'Enter — закончить, Esc — шаг назад. ' \
                         'Сегментов на пролёт: %d (наберите число и Enter).',
        vcb_label:       'Сегментов',
        bad_segments:    'Сегментов на пролёт: от 1 до 200, а не «%s».',
        op_curve:        'Кривая Безье'
      },
      'en' => {
        ext_description: 'Bézier pen: smooth and corner nodes, ' \
                         'every span is a separate curve.',
        cmd_bezier:      'Bézier curve',
        tip_bezier:      'Draw a Bézier curve',
        bar_bezier:      'Click — corner node, click and drag — smooth; ' \
                         'Enter — finish, Esc — step back',
        menu_about:      'About…',
        title_about:     'About Monsieur Bézier',
        status:          'Bézier: click — corner, click and drag — smooth node, ' \
                         'Enter — finish, Esc — step back. ' \
                         'Segments per span: %d (type a number and press Enter).',
        vcb_label:       'Segments',
        bad_segments:    'Segments per span: 1 to 200, not “%s”.',
        op_curve:        'Bézier curve'
      }
    }.freeze

    # Ключ не нашёлся в выбранном языке — берём русский, а не пустоту:
    # недопереведённая строка лучше пропавшей надписи на кнопке.
    def self.t(key, *args)
      s = (STRINGS[LANG] || STRINGS['ru'])[key] || STRINGS['ru'][key] || key.to_s
      args.empty? ? s : format(s, *args)
    end

  end # module MonsieurBezier
end # module BACommunity
