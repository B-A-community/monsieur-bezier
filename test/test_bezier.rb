# Прогон пера без SketchUp: математика цепочки + то, что finish кладёт в модель.
$LOAD_PATH.unshift(__dir__)
require 'minitest/autorun'
require 'sketchup'

SRC = File.expand_path('../src/monsieur_bezier', __dir__)
%w[lang settings bezier bezier_tool].each { |f| require "#{SRC}/#{f}" }

M = BACommunity::MonsieurBezier
P = Geom::Point3d

def smooth(x, y, hx, hy)
  a = M::Bezier::Anchor.new(P.new(x, y, 0), nil, nil)
  a.pull_to(P.new(hx, hy, 0))
  a
end

def corner(x, y) = M::Bezier::Anchor.new(P.new(x, y, 0), nil, nil)

class BezierSpansTest < Minitest::Test
  def setup
    # гладкий, гладкий, угловой, угловой: два кривых пролёта и один прямой
    @chain = [smooth(0, 0, 30, 40), smooth(90, 0, 120, -40), corner(180, 30), corner(240, 30)]
  end

  def test_one_span_per_pair_of_anchors
    spans = M::Bezier.spans(@chain, 12)
    assert_equal 3, spans.length
  end

  def test_curved_spans_have_segments_plus_one_points_and_straight_has_two
    assert_equal [13, 13, 2], M::Bezier.spans(@chain, 12).map(&:length)
  end

  def test_spans_start_and_end_exactly_on_anchors
    M::Bezier.spans(@chain, 12).each_with_index do |span, i|
      assert_equal 0.0, span.first.distance(@chain[i].point).to_f
      assert_equal 0.0, span.last.distance(@chain[i + 1].point).to_f
    end
  end

  def test_adjacent_spans_share_their_joint_point
    spans = M::Bezier.spans(@chain, 12)
    spans.each_cons(2) do |a, b|
      assert_equal 0.0, a.last.distance(b.first).to_f, 'стык пролётов обязан совпасть точка в точку'
    end
  end

  def test_polyline_is_spans_glued_without_duplicates
    spans = M::Bezier.spans(@chain, 12)
    poly  = M::Bezier.polyline(@chain, 12)
    assert_equal 13 + 12 + 1, poly.length
    assert_equal spans.flatten(1).map(&:to_a).uniq.length, poly.length
  end

  def test_closed_chain_adds_a_span_back_to_the_first_anchor
    spans = M::Bezier.spans(@chain, 12, true)
    assert_equal 4, spans.length
    assert_equal 0.0, spans.last.last.distance(@chain.first.point).to_f
  end

  def test_single_anchor_gives_nothing
    assert_empty M::Bezier.spans([corner(0, 0)], 12)
    assert_empty M::Bezier.polyline([corner(0, 0)], 12)
  end

  def test_smooth_handles_are_mirrored
    a = smooth(10, 10, 40, 50)
    assert_in_delta 0.0, (a.point.distance(a.handle_in).to_f - a.point.distance(a.handle_out).to_f), 1e-9
    mid = M::Bezier.lerp(a.handle_in, a.handle_out, 0.5)
    assert_equal 0.0, mid.distance(a.point).to_f
  end
end

class BezierToolFinishTest < Minitest::Test
  def setup
    @model = Sketchup.model
    @model.active_entities.log.clear
    @model.ops.clear
    @tool = M::BezierTool.new
    @tool.instance_variable_set(:@segments, 12)
  end

  def run_finish(anchors, closed = false)
    @tool.instance_variable_set(:@anchors, anchors)
    @tool.send(:finish, Sketchup::FakeView.new, closed)
    @model.active_entities.log
  end

  def test_each_curved_span_becomes_its_own_curve_and_straight_becomes_a_line
    log = run_finish([smooth(0, 0, 30, 40), smooth(90, 0, 120, -40), corner(180, 30), corner(240, 30)])
    assert_equal [:curve, :curve, :line], log.map(&:first)
    assert_equal [13, 13, 2], log.map { |_, pts| pts.length }
  end

  def test_all_in_one_undo_step
    run_finish([corner(0, 0), smooth(50, 50, 80, 80), corner(100, 0)])
    assert_equal [[:start, M.t(:op_curve)], [:commit]], @model.ops
  end

  def test_closed_chain_adds_closing_span
    log = run_finish([smooth(0, 0, 20, 30), smooth(60, 0, 80, -30), smooth(30, 60, 0, 60)], true)
    assert_equal 3, log.length
    assert_equal 0.0, log.last[1].last.distance(log.first[1].first).to_f
  end

  def test_finish_resets_the_tool
    run_finish([corner(0, 0), corner(10, 10)])
    assert_empty @tool.instance_variable_get(:@anchors)
    refute @tool.instance_variable_get(:@dragging)
  end

  def test_nothing_built_from_a_single_anchor
    log = run_finish([corner(0, 0)])
    assert_empty log
    assert_empty @model.ops, 'без пролётов операция даже не открывается'
  end

  def test_repeated_corner_does_not_create_an_empty_operation
    assert_empty run_finish([corner(10, 10), corner(10, 10)])
    assert_empty @model.ops
  end

  def test_tiny_span_does_not_send_coincident_points_to_sketchup
    assert_empty run_finish([corner(0, 0), corner(0.0001, 0)])
    assert_empty @model.ops
  end

  def test_empty_finish_resets_drag_and_close_state
    @tool.instance_variable_set(:@dragging, true)
    @tool.instance_variable_set(:@closing, true)
    run_finish([corner(0, 0)])
    refute @tool.instance_variable_get(:@dragging)
    refute @tool.instance_variable_get(:@closing)
  end

  def test_segment_input_rejects_partial_numbers_and_preserves_preference
    view = Sketchup::FakeView.new
    @tool.onUserText('24', view)
    %w[12abc 1.5 1e2 -1 0 201].push('').each do |text|
      @tool.onUserText(text, view)
      assert_equal 24, @tool.instance_variable_get(:@segments), text
      assert_equal 24, M::Settings.read('bezier_segments', 12), text
    end
  ensure
    M::Settings.write('bezier_segments', 12)
  end

  def test_segment_limits_and_whitespace
    ['1', '200', ' 12 '].each do |text|
      @tool.onUserText(text, Sketchup::FakeView.new)
      assert_equal text.to_i, @tool.instance_variable_get(:@segments)
    end
  end

  def test_invalid_saved_segment_count_uses_default
    [0, -10, 201].each do |value|
      M::Settings.write('bezier_segments', value)
      assert_equal 12, M::BezierTool.new.instance_variable_get(:@segments)
    end
  ensure
    M::Settings.write('bezier_segments', 12)
  end

  def test_closing_preview_uses_the_first_nodes_incoming_handle
    chain = [smooth(0, 0, 30, 40), corner(90, 0), corner(90, 90)]
    @tool.instance_variable_set(:@anchors, chain)
    @tool.instance_variable_set(:@closing, true)
    assert_equal M::Bezier.polyline(chain, 12, true).map(&:to_a),
                 @tool.send(:preview_points).map(&:to_a)
  end

  def test_escape_removes_one_node_and_clears_closing_state
    @tool.instance_variable_set(:@anchors, [corner(0, 0), corner(20, 20)])
    @tool.instance_variable_set(:@closing, true)
    @tool.onCancel(0, Sketchup::FakeView.new)
    assert_equal 1, @tool.instance_variable_get(:@anchors).length
    refute @tool.instance_variable_get(:@closing)
  end

  def test_double_click_keeps_the_endpoint_from_the_first_mouse_down
    view = Sketchup::FakeView.new
    # Native Windows SketchUp sequence: Down, Up, Down, Up, DoubleClick, Up.
    @tool.onLButtonDown(0, 0, 0, view)
    @tool.onLButtonUp(0, 0, 0, view)
    @tool.onLButtonDown(0, 100, 0, view)
    @tool.onLButtonUp(0, 100, 0, view)
    @tool.onLButtonDoubleClick(0, 100, 0, view)
    @tool.onLButtonUp(0, 100, 0, view)
    assert_equal 1, @model.active_entities.log.length
    assert_equal [100.0, 0.0, 0.0], @model.active_entities.log.first.last.last.to_a
  end
end
