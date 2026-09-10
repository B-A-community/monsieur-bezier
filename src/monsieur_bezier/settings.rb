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

    # Настройки живут в реестре SketchUp, а не в модели: это предпочтения
    # человека за компьютером, а не свойство файла.
    module Settings

      KEY = 'BACommunity_MonsieurBezier'.freeze

      module_function

      def read(name, fallback)
        Sketchup.read_default(KEY, name, fallback)
      end

      def write(name, value)
        Sketchup.write_default(KEY, name, value)
      end

    end # module Settings
  end # module MonsieurBezier
end # module BACommunity
