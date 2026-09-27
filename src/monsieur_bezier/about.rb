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

    # Окно «О плагине»: авторы, версия, ссылка на репозиторий.
    # Разметка и поведение — как в RALNCS, чтобы плагины B&A были роднёй.
    module About

      REPO_URL  = 'https://github.com/B-A-community/monsieur-bezier'.freeze
      HTML_FILE = File.join(File.dirname(__FILE__), 'html', 'about.html').freeze

      module_function

      def show
        @dialog&.close
        @dialog = UI::HtmlDialog.new(
          dialog_title:    MonsieurBezier.t(:title_about),
          preferences_key: 'BACommunity_MonsieurBezier_About',
          width:           420,
          height:          300,
          use_content_size: true,
          resizable:       false,
          style:           UI::HtmlDialog::STYLE_DIALOG
        )
        # Override dimensions saved by older builds that included the title bar.
        @dialog.set_content_size(420, 300)
        @dialog.set_file(HTML_FILE)
        @dialog.add_action_callback('ready') do |_ctx|
          @dialog.execute_script("init(#{JSON.generate(version: version)})")
        end
        # Открываем только свой репозиторий: адрес приходит из JS, а окно —
        # не место, откуда можно открыть произвольную ссылку.
        @dialog.add_action_callback('open_url') { |_ctx, url| UI.openURL(url) if url == REPO_URL }
        @dialog.add_action_callback('close') { |_ctx| @dialog.close }
        @dialog.show
        @dialog
      end

      # Версию берём у самого загрузчика, а не из списка расширений: так она
      # верна и при загрузке из папки разработки, где расширение не
      # регистрировалось через Менеджер расширений.
      def version
        defined?(MonsieurBezier::VERSION) ? MonsieurBezier::VERSION : ''
      end

    end # module About
  end # module MonsieurBezier
end # module BACommunity
