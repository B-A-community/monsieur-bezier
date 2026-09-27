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
end
