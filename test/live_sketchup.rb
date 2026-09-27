# Run through tools/su_exec.ps1 after loading the packaged Ruby files.
# Tests real SketchUp geometry in a temporary group, then removes that group.
require 'json'
module MonsieurBezierLiveTest
  def self.run
    plugin = BACommunity::MonsieurBezier
    model = Sketchup.active_model
    original_path = model.active_path
    original_selection = model.selection.to_a
    preference = plugin::Settings.read('bezier_segments', 12)
    checks = []
    check = ->(name, condition) { raise "FAIL: #{name}" unless condition; checks << name }
    point = ->(x, y) { Geom::Point3d.new(x, y, 0) }
    corner = ->(x, y) { plugin::Bezier::Anchor.new(point.call(x, y), nil, nil) }
    smooth = lambda do |x, y, hx, hy|
      a = corner.call(x, y)
      a.pull_to(point.call(hx, hy))
      a
    end
    group = nil
    begin
      model.start_operation('Monsieur Bezier QA fixture', true)
      group = model.active_entities.add_group
      group.name = 'Monsieur Bezier temporary QA'
      # Keep the group alive while entering its editing context.
      group.entities.add_cpoint(point.call(-100, -100))
      model.commit_operation
      model.active_path = Array(original_path) + [group]
      view = model.active_view
      tool = plugin::BezierTool.new
      tool.onUserText('12', view)
      tool.instance_variable_set(:@anchors, [smooth.call(0, 0, 30, 40),
        smooth.call(90, 0, 120, -40), corner.call(180, 30), corner.call(240, 30)])
      tool.send(:finish, view, false)
      edges = group.entities.grep(Sketchup::Edge)
      check.call('mixed chain: 25 edges', edges.length == 25)
      curves = edges.map(&:curve).compact.uniq
      check.call('two separate 12-edge curves', curves.map { |c| c.edges.length }.sort == [12, 12])
      vertices = edges.flat_map(&:vertices).uniq
      check.call('shared span vertices', vertices.length == 26)
      check.call('one connected path', edges.first.all_connected.grep(Sketchup::Edge).length == 25)
      Sketchup.undo
      check.call('single undo removes whole curve', group.entities.grep(Sketchup::Edge).empty?)

      tool.instance_variable_set(:@anchors, [corner.call(0, 0), corner.call(80, 0), corner.call(40, 80)])
      tool.send(:finish, view, true)
      edges = group.entities.grep(Sketchup::Edge)
      check.call('closed loop: three edges and three vertices', edges.length == 3 && edges.flat_map(&:vertices).uniq.length == 3)
      Sketchup.undo
      check.call('closed loop undo', group.entities.grep(Sketchup::Edge).empty?)

      tool.instance_variable_set(:@anchors, [corner.call(0, 0), corner.call(100, 0)])
      tool.onLButtonDoubleClick(0, 0, 0, view)
      edges = group.entities.grep(Sketchup::Edge)
      check.call('double click preserves final anchor', edges.length == 1 &&
        edges.first.vertices.any? { |v| v.position.distance(point.call(100, 0)).to_f < 1.0e-6 })
      Sketchup.undo
      check.call('double click result undo', group.entities.grep(Sketchup::Edge).empty?)

      tool.instance_variable_set(:@anchors, [corner.call(10, 10), corner.call(10, 10)])
      tool.send(:finish, view, false)
      check.call('coincident points are ignored', group.entities.grep(Sketchup::Edge).empty?)
      [1, 200, 24].each { |n| tool.onUserText(n.to_s, view); check.call("segments #{n}", tool.instance_variable_get(:@segments) == n) }
      ['12abc', '1.5', '0', '201', ''].each do |s|
        tool.onUserText(s, view)
        check.call("reject #{s.inspect}", tool.instance_variable_get(:@segments) == 24)
      end
      tool.instance_variable_set(:@anchors, [corner.call(0, 0), corner.call(30, 30)])
      tool.onCancel(0, view)
      check.call('Escape removes one anchor', tool.instance_variable_get(:@anchors).length == 1)
      chain = [smooth.call(0, 0, 30, 40), corner.call(90, 0), corner.call(90, 90)]
      tool.instance_variable_set(:@anchors, chain)
      tool.instance_variable_set(:@closing, true)
      check.call('closed preview matches output', tool.send(:preview_points).map(&:to_a) == plugin::Bezier.polyline(chain, 24, true).map(&:to_a))
      check.call('registered version 1.0', Sketchup.extensions.any? { |e| e.name == 'Monsieur Bézier' && e.version == '1.0' })
      {sketchup: Sketchup.version, ruby: RUBY_VERSION, language: plugin::LANG,
       source: plugin::BezierTool.instance_method(:finish).source_location.first,
       passed: checks.length, checks: checks}
    ensure
      model.active_path = original_path
      if group && group.valid?
        model.start_operation('Remove Monsieur Bezier QA fixture', true)
        group.erase!
        model.commit_operation
      end
      model.selection.clear
      model.selection.add(original_selection.select(&:valid?))
      plugin::Settings.write('bezier_segments', preference)
      Sketchup.status_text = ''
      Sketchup.vcb_value = ''
      Sketchup.vcb_label = ''
    end
  end
end
puts JSON.generate(MonsieurBezierLiveTest.run)
