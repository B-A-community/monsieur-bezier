# Заглушка SketchUp API: даёт прогнать перо обычным ruby, без SketchUp.
# Реализовано ровно то, что дёргают bezier.rb, bezier_tool.rb и settings.rb;
# движок фаски сюда не влезает — ему нужны настоящие Face/Edge/Loop, он
# проверяется только в живом SketchUp (см. README, «Чем проверено»).
# Запуск:  ruby test/test_bezier.rb
# Point3d/Vector3d повторяют семантику оригинала: + - offset distance clone,
# distance возвращает Length с допуском при сравнении — как в SketchUp.

class Length < Numeric
  TOL = 0.001
  def initialize(v) = @v = v.to_f
  def to_f = @v
  def to_s = @v.to_s
  def coerce(o) = [o.to_f, @v]
  def <=>(o)
    d = @v - o.to_f
    d.abs < TOL ? 0 : (d <=> 0)
  end
  def ==(o) = (self <=> o).zero?
  def <(o)  = (self <=> o).negative?
  def >(o)  = (self <=> o).positive?
  def <=(o) = !(self > o)
  def >=(o) = !(self < o)
  def *(o) = @v * o.to_f
  def /(o) = @v / o.to_f
  def +(o) = @v + o.to_f
  def -(o) = @v - o.to_f
  def abs  = @v.abs
  def round(n = 0) = @v.round(n)
end

class Numeric
  def mm = self / 25.4
  def to_l = Length.new(self)
end

module Geom
  class Vector3d
    attr_accessor :x, :y, :z
    def initialize(x = 0, y = 0, z = 0) = (@x, @y, @z = x.to_f, y.to_f, z.to_f)
    def length = Length.new(Math.sqrt(@x * @x + @y * @y + @z * @z))
    def length=(l)
      k = l.to_f / length.to_f
      @x *= k; @y *= k; @z *= k
    end
    def normalize! = (self.length = 1.0; self)
    def normalize = clone.normalize!
    def clone = Vector3d.new(@x, @y, @z)
    def reverse = Vector3d.new(-@x, -@y, -@z)
    def dot(v) = @x * v.x + @y * v.y + @z * v.z
    def cross(v) = Vector3d.new(@y * v.z - @z * v.y, @z * v.x - @x * v.z, @x * v.y - @y * v.x)
    def angle_between(v)
      c = dot(v) / (length.to_f * v.length.to_f)
      Math.acos([[c, -1.0].max, 1.0].min)
    end
    def *(k) = Vector3d.new(@x * k, @y * k, @z * k)
    def to_s = "Vector3d(#{@x}, #{@y}, #{@z})"
  end

  class Point3d
    attr_accessor :x, :y, :z
    def initialize(x = 0, y = 0, z = 0) = (@x, @y, @z = x.to_f, y.to_f, z.to_f)
    def clone = Point3d.new(@x, @y, @z)
    def -(o)
      o.is_a?(Vector3d) ? Point3d.new(@x - o.x, @y - o.y, @z - o.z) : Vector3d.new(@x - o.x, @y - o.y, @z - o.z)
    end
    def +(v) = Point3d.new(@x + v.x, @y + v.y, @z + v.z)
    def offset(v, d = nil)
      u = v.clone
      u.length = d if d
      self + u
    end
    def distance(p) = Length.new(Math.sqrt((@x - p.x)**2 + (@y - p.y)**2 + (@z - p.z)**2))
    def ==(p) = distance(p) == 0
    def to_a = [@x, @y, @z]
    def to_s = "Point3d(#{@x.round(4)}, #{@y.round(4)}, #{@z.round(4)})"
    alias inspect to_s
  end

  class BoundingBox
    def initialize = @pts = []
    def add(p) = @pts << p
    def empty? = @pts.empty?
  end
end

module Sketchup
  class Color
    def initialize(*rgb) = @rgb = rgb
  end

  class InputPoint
    attr_reader :position
    def initialize = @position = nil
    def pick(_view, x, y) = @position = Geom::Point3d.new(x, y, 0)
    def valid? = !@position.nil?
    def draw(_view) = nil
  end

  # Журнал того, что перо построило: ровно то, что нам и нужно проверить.
  class FakeEntities
    attr_reader :log
    def initialize = @log = []
    def add_curve(points) = @log << [:curve, points]
    def add_line(a, b)    = @log << [:line, [a, b]]
  end

  class FakeView
    def invalidate = nil
    def screen_coords(p) = Geom::Point3d.new(p.x, p.y, 0)
  end

  class FakeModel
    attr_reader :active_entities, :ops
    def initialize
      @active_entities = FakeEntities.new
      @ops = []
    end
    def start_operation(name, *_) = @ops << [:start, name]
    def commit_operation = @ops << [:commit]
    def abort_operation  = @ops << [:abort]
    def active_view = FakeView.new
  end

  @defaults = {}
  @model = FakeModel.new
  class << self
    attr_reader :model
    def active_model = @model
    def read_default(_k, name, fb) = @defaults.fetch(name, fb)
    def write_default(_k, name, v) = @defaults[name] = v
    def status_text=(_t); end
    def vcb_label=(_t); end
    def vcb_value=(_t); end
  end
end

GL_LINES = 1
GL_LINE_STRIP = 3

module UI
  def self.messagebox(*_) = nil
end
