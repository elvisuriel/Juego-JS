class_name SeaMeshes
extends RefCounted
## Modelos 3D del fondo del mar generados por código (sin archivos externos),
## estilo "low poly" de caras planas. Todos usan colores por vértice y el
## shader shaders/world.gdshader:
##   UV.x = cuánto se mece con la corriente, UV.y = 1 si es pieza delgada.

static var _cache := {}


# --- Ayudas -----------------------------------------------------------------

## Triángulo con normal plana. Si se da `center`, la normal apunta hacia afuera.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color,
		center = null, sa := 0.0, sb := 0.0, sc := 0.0, thin := 0.0) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if center != null and n.dot((a + b + c) / 3.0 - center) < 0.0:
		n = -n
	elif center == null and n.y < 0.0 and thin < 0.5:
		n = -n
	for v in [[a, sa], [b, sb], [c, sc]]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(Vector2(v[1], thin))
		st.add_vertex(v[0])


static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color,
		center = null, sway_ab := 0.0, sway_cd := 0.0, thin := 0.0) -> void:
	tri(st, a, b, c, col, center, sway_ab, sway_ab, sway_cd, thin)
	tri(st, a, c, d, col, center, sway_ab, sway_cd, sway_cd, thin)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _shade(c: Color, rng: RandomNumberGenerator, amount := 0.12) -> Color:
	var k := rng.randf_range(-amount, amount)
	return Color(clampf(c.r + k, 0, 1), clampf(c.g + k, 0, 1), clampf(c.b + k, 0, 1))


## Icosfera: [vértices, caras]
static func _icosphere(sub: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = []
	for p in [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t],
			[0, -1, -t], [0, 1, -t], [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]]:
		verts.append(Vector3(p[0], p[1], p[2]).normalized())
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for s in sub:
		var mids := {}
		var nf := []
		for f in faces:
			var m := []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var key := "%d_%d" % [mini(e[0], e[1]), maxi(e[0], e[1])]
				if not mids.has(key):
					verts.append(((verts[e[0]] + verts[e[1]]) * 0.5).normalized())
					mids[key] = verts.size() - 1
				m.append(mids[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	return [verts, faces]


static func _blob(st: SurfaceTool, center: Vector3, radius: Vector3, sub: int, bump: float,
		rng: RandomNumberGenerator, col_fn: Callable, sway := 0.0, flat_bottom := -2.0) -> void:
	var ico := _icosphere(sub)
	var verts: Array[Vector3] = []
	for v: Vector3 in ico[0]:
		var p := v * (1.0 + rng.randf_range(-bump, bump))
		p.y = maxf(p.y, flat_bottom)
		verts.append(center + p * radius)
	for f in ico[1]:
		var a := verts[f[0]]
		var b := verts[f[1]]
		var c := verts[f[2]]
		var col: Color = col_fn.call((a + b + c) / 3.0 - center)
		var s := sway
		tri(st, a, b, c, col, center, s * maxf(a.y, 0.0), s * maxf(b.y, 0.0), s * maxf(c.y, 0.0))


static func _prism(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int,
		col_a: Color, col_b: Color, sway_a := 0.0, sway_b := 0.0) -> void:
	var dir := (b - a).normalized()
	var ref := Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var u := dir.cross(ref).normalized()
	var w := dir.cross(u).normalized()
	var center := (a + b) * 0.5
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var o0 := (u * cos(a0) + w * sin(a0))
		var o1 := (u * cos(a1) + w * sin(a1))
		var col := col_a.lerp(col_b, 0.5)
		tri(st, a + o0 * ra, a + o1 * ra, b + o1 * rb, col_a, center, sway_a, sway_a, sway_b)
		tri(st, a + o0 * ra, b + o1 * rb, b + o0 * rb, col, center, sway_a, sway_b, sway_b)


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, rng: RandomNumberGenerator = null) -> void:
	var h := s * 0.5
	var p := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(-h.x, -h.y, h.z),
		c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)]
	var faces := [[4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [0, 3, 2, 1]]
	for f in faces:
		var fc := col if rng == null else _shade(col, rng, 0.05)
		quad(st, p[f[0]], p[f[1]], p[f[2]], p[f[3]], fc, c)


static func _solid(c: Color) -> Callable:
	return func(_d: Vector3) -> Color: return c


static func _commit(key: String, st: SurfaceTool) -> ArrayMesh:
	var m := st.commit()
	_cache[key] = m
	return m


# --- Rocas y suelo ------------------------------------------------------------

static func rock(variant: int, base := Color("#6f8091")) -> ArrayMesh:
	var key := "rock%d_%s" % [variant, base.to_html()]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + variant * 77
	var st := _begin()
	var moss := Color("#5f8f6a")
	var paint := func(d: Vector3) -> Color:
		var c := _shade(base, rng, 0.07)
		if d.normalized().y > 0.6 and rng.randf() < 0.5:
			c = c.lerp(moss, 0.45)
		return c
	_blob(st, Vector3.ZERO, Vector3(1.0, 0.7, 0.9), 1, 0.25, rng, paint, 0.0, -0.35)
	return _commit(key, st)


# --- Corales -----------------------------------------------------------------

static func coral_branch(variant: int, color: Color) -> ArrayMesh:
	var key := "coral%d_%s" % [variant, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000 + variant * 31
	var st := _begin()
	_branch(st, Vector3.ZERO, Vector3.UP, 0.45, 0.09, 3, rng, color)
	return _commit(key, st)


static func _branch(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, radius: float,
		depth: int, rng: RandomNumberGenerator, color: Color) -> void:
	var tip := base + dir * length
	var dark := color.darkened(0.25)
	_prism(st, base, tip, radius, radius * 0.72, 5, dark.lerp(color, 0.3), color, base.y * 0.35, tip.y * 0.35)
	if depth <= 0:
		_blob(st, tip, Vector3.ONE * radius * 1.1, 0, 0.1, rng, _solid(color.lightened(0.35)), 0.35)
		return
	var n := 2 if rng.randf() < 0.5 else 3
	for k in n:
		var spread := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 0.9), rng.randf_range(-1, 1))
		var nd := (dir * 1.2 + spread).normalized()
		nd.y = maxf(nd.y, 0.25)
		_branch(st, tip, nd.normalized(), length * rng.randf_range(0.65, 0.85), radius * 0.72, depth - 1, rng, color)


static func brain_coral(color: Color) -> ArrayMesh:
	var key := "brain_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3000
	var st := _begin()
	var dark := color.darkened(0.3)
	var paint := func(d: Vector3) -> Color:
		return color if sin(d.x * 22.0 + sin(d.z * 14.0) * 2.0) > 0.0 else dark
	_blob(st, Vector3.ZERO, Vector3(0.55, 0.42, 0.55), 2, 0.06, rng, paint, 0.0, -0.1)
	return _commit(key, st)


static func fan_coral(color: Color) -> ArrayMesh:
	var key := "fan_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4000
	var st := _begin()
	var dark := color.darkened(0.35)
	_prism(st, Vector3.ZERO, Vector3(0, 0.25, 0), 0.05, 0.035, 4, dark, dark)
	var c := Vector3(0, 0.25, 0)
	var steps := 10
	var prev := Vector3.ZERO
	for i in steps + 1:
		var a := lerpf(-1.2, 1.2, float(i) / steps)
		var r := 0.75 * rng.randf_range(0.85, 1.05)
		var p := c + Vector3(sin(a) * r, cos(a) * r * 0.9, rng.randf_range(-0.04, 0.04))
		if i > 0:
			var col := color if i % 2 == 0 else color.lerp(dark, 0.4)
			tri(st, c, prev, p, col, null, 0.08, prev.y * 0.4, p.y * 0.4, 1.0)
		prev = p
	return _commit(key, st)


static func anemone(color: Color) -> ArrayMesh:
	var key := "anem_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4500
	var st := _begin()
	_prism(st, Vector3.ZERO, Vector3(0, 0.18, 0), 0.16, 0.13, 7, color.darkened(0.3), color.darkened(0.1))
	var tip_col := color.lightened(0.4)
	for i in 14:
		var a := TAU * i / 14.0 + rng.randf() * 0.3
		var base := Vector3(cos(a) * 0.1, 0.18, sin(a) * 0.1)
		var tip := base + Vector3(cos(a) * 0.18, rng.randf_range(0.2, 0.32), sin(a) * 0.18)
		_prism(st, base, tip, 0.03, 0.012, 3, color, tip_col, 0.1, 0.6)
	return _commit(key, st)


# --- Algas y plantas -----------------------------------------------------------

## Alga alta (1 unidad de alto; se estira al colocarla).
static func kelp(variant: int) -> ArrayMesh:
	var key := "kelp%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + variant
	var st := _begin()
	var stem := Color("#2f9a63").lerp(Color("#6b8f2a"), rng.randf() * 0.5)
	var leaf := stem.lightened(0.25)
	var segs := 8
	var twist := rng.randf_range(-0.8, 0.8)
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var w0 := 0.09 * (1.0 - t0 * 0.6)
		var w1 := 0.09 * (1.0 - t1 * 0.6)
		var d0 := Vector3(cos(twist * t0), 0, sin(twist * t0))
		var d1 := Vector3(cos(twist * t1), 0, sin(twist * t1))
		var a := Vector3(0, t0, 0) - d0 * w0
		var b := Vector3(0, t0, 0) + d0 * w0
		var c := Vector3(0, t1, 0) + d1 * w1
		var d := Vector3(0, t1, 0) - d1 * w1
		var s0 := t0 * t0 * 1.4
		var s1 := t1 * t1 * 1.4
		tri(st, a, b, c, stem, null, s0, s0, s1, 1.0)
		tri(st, a, c, d, stem, null, s0, s1, s1, 1.0)
		if i % 2 == 1:
			var side := 1.0 if i % 4 == 1 else -1.0
			var root := Vector3(0, t0 + 0.04, 0)
			var tip := root + d0 * side * 0.32 + Vector3(0, 0.1, 0)
			var mid := root + d0 * side * 0.16 + Vector3(0, 0.1, 0.05)
			tri(st, root, tip, mid + Vector3(0, -0.06, 0), leaf, null, s0, s1 * 1.2, s0, 1.0)
	return _commit(key, st)


static func grass(color := Color("#4aa86c")) -> ArrayMesh:
	var key := "grass_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 6000
	var st := _begin()
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.5
		var base := Vector3(cos(a) * 0.08, 0, sin(a) * 0.08)
		var h := rng.randf_range(0.3, 0.55)
		var lean := Vector3(cos(a), 0, sin(a)) * 0.12
		var side := Vector3(-sin(a), 0, cos(a)) * 0.04
		var col := _shade(color, rng, 0.08)
		tri(st, base - side, base + side, base + lean + Vector3(0, h, 0), col, null, 0.0, 0.0, h * 1.5, 1.0)
	return _commit(key, st)


# --- Animalitos del fondo -----------------------------------------------------

static func starfish(color: Color) -> ArrayMesh:
	var key := "star_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	var top := Vector3(0, 0.07, 0)
	var dark := color.darkened(0.25)
	var pts: Array[Vector3] = []
	for i in 10:
		var a := TAU * i / 10.0
		var r := 0.32 if i % 2 == 0 else 0.12
		pts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for i in 10:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % 10]
		tri(st, top, p0 + Vector3(0, 0.02, 0), p1 + Vector3(0, 0.02, 0), color if i % 2 == 0 else dark, Vector3(0, -0.1, 0))
	return _commit(key, st)


static func shell() -> ArrayMesh:
	if _cache.has("shell"):
		return _cache["shell"]
	var st := _begin()
	var a := Color("#f6d7c3")
	var b := Color("#e3a98c")
	var center := Vector3(0, 0.0, 0)
	for i in 9:
		var a0 := lerpf(-1.1, 1.1, i / 9.0)
		var a1 := lerpf(-1.1, 1.1, (i + 1) / 9.0)
		var p0 := Vector3(sin(a0) * 0.28, 0.02, -cos(a0) * 0.28 + 0.12)
		var p1 := Vector3(sin(a1) * 0.28, 0.02, -cos(a1) * 0.28 + 0.12)
		var top := Vector3(0, 0.1, 0.0)
		tri(st, Vector3(0, 0.02, 0.14), p0, p1, a if i % 2 == 0 else b, Vector3(0, -0.2, 0))
		tri(st, top, p0, p1, a if i % 2 == 0 else b, Vector3(0, -0.2, 0))
	return _commit("shell", st)


static func fish(color: Color) -> ArrayMesh:
	var key := "fish_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	var nose := Vector3(0.22, 0, 0)
	var back := Vector3(-0.12, 0, 0)
	var top := Vector3(0.02, 0.09, 0)
	var bot := Vector3(0.02, -0.07, 0)
	var l := Vector3(0.02, 0, 0.05)
	var r := Vector3(0.02, 0, -0.05)
	var c := Vector3.ZERO
	var belly := color.lightened(0.45)
	for pair in [[top, l], [l, bot], [bot, r], [r, top]]:
		var col := color if pair[0] == top or pair[1] == top else belly
		tri(st, nose, pair[0], pair[1], col, c)
		tri(st, back, pair[0], pair[1], col, c)
	tri(st, back, Vector3(-0.24, 0.08, 0), Vector3(-0.24, -0.08, 0), color.darkened(0.2), null, 0, 0, 0, 1.0)
	return _commit(key, st)


# --- Ruinas de Atlantis --------------------------------------------------------

const STONE := Color("#d8cfb6")


static func column(broken: bool, variant := 0) -> ArrayMesh:
	var key := "col%s%d" % [broken, variant]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + variant
	var st := _begin()
	var h := rng.randf_range(0.5, 1.1) if broken else 1.55
	_box(st, Vector3(0, 0.08, 0), Vector3(0.75, 0.16, 0.75), STONE.darkened(0.08), rng)
	var sides := 10
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var r := 0.26
		var y1a := h + (rng.randf_range(-0.15, 0.15) if broken else 0.0)
		var y1b := h + (rng.randf_range(-0.15, 0.15) if broken else 0.0)
		var col := STONE if i % 2 == 0 else STONE.darkened(0.1)
		quad(st, Vector3(cos(a0) * r, 0.16, sin(a0) * r), Vector3(cos(a1) * r, 0.16, sin(a1) * r),
			Vector3(cos(a1) * r * 0.92, y1b, sin(a1) * r * 0.92), Vector3(cos(a0) * r * 0.92, y1a, sin(a0) * r * 0.92),
			col, Vector3(0, h * 0.5, 0))
	if broken:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			tri(st, Vector3(0, h + 0.05, 0), Vector3(cos(a0) * 0.24, h, sin(a0) * 0.24), Vector3(cos(a1) * 0.24, h, sin(a1) * 0.24), STONE.darkened(0.15), Vector3(0, 0, 0))
	else:
		_box(st, Vector3(0, h + 0.08, 0), Vector3(0.7, 0.16, 0.7), STONE.lightened(0.05), rng)
		# Un poco de alga trepando
		_prism(st, Vector3(0.27, 0.16, 0), Vector3(0.3, 0.9, 0.05), 0.04, 0.02, 3, Color("#3e9a5f"), Color("#5cc07f"), 0.0, 0.3)
	return _commit(key, st)


static func tile(variant: int) -> ArrayMesh:
	var key := "tile%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8000 + variant
	var st := _begin()
	_box(st, Vector3(0, 0.05, 0), Vector3(1.9, 0.1, 1.9), STONE.lerp(Color("#bfc7c9"), rng.randf() * 0.5).darkened(rng.randf() * 0.1), rng)
	return _commit(key, st)


static func statue_head() -> ArrayMesh:
	if _cache.has("head"):
		return _cache["head"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8500
	var st := _begin()
	var stone := STONE.darkened(0.05)
	var paint := func(_d: Vector3) -> Color:
		return _shade(stone, rng, 0.04)
	_blob(st, Vector3(0, 0.55, 0), Vector3(0.5, 0.62, 0.48), 1, 0.05, rng, paint, 0.0, -0.8)
	# Corona de Atlantis
	for i in 5:
		var a := -0.9 + i * 0.45
		var base := Vector3(sin(a) * 0.42, 1.05, cos(a) * 0.3)
		_prism(st, base, base + Vector3(0, 0.3, 0), 0.07, 0.01, 4, Color("#d9b24a"), Color("#f3d77a"))
	_box(st, Vector3(0.16, 0.62, 0.42), Vector3(0.12, 0.06, 0.06), Color("#3a3a3a"))
	_box(st, Vector3(-0.16, 0.62, 0.42), Vector3(0.12, 0.06, 0.06), Color("#3a3a3a"))
	return _commit("head", st)


# --- Barco hundido -----------------------------------------------------------

const WOOD := Color("#8f5a2e")


static func ship() -> ArrayMesh:
	if _cache.has("ship"):
		return _cache["ship"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000
	var st := _begin()
	var L := 7.0
	var rings := 14
	var sides := 8
	var prev: Array[Vector3] = []
	for i in rings + 1:
		var t := float(i) / rings
		var x := lerpf(-L * 0.5, L * 0.5, t)
		# Proa en punta (+x), popa ancha
		var w := 1.35 * sin(clampf(t * 1.15, 0.0, 1.0) * PI * 0.5 + 0.6) * (1.0 - smoothstep(0.75, 1.0, t) * 0.92)
		var depth := 1.0 * (1.0 - smoothstep(0.8, 1.0, t) * 0.5)
		var ring: Array[Vector3] = []
		for j in sides + 1:
			var a := PI * j / sides
			ring.append(Vector3(x, 1.0 - sin(a) * depth, cos(a) * w))
		if i > 0:
			for j in sides:
				# Agujeros en el casco (se hundió por algo)
				if i in [5, 6] and j in [5, 6]:
					continue
				var plank := WOOD if j % 2 == 0 else WOOD.darkened(0.15)
				quad(st, prev[j], ring[j], ring[j + 1], prev[j + 1], _shade(plank, rng, 0.04), null, 0.0, 0.0, 1.0)
		prev = ring
	# Cubierta rota
	for i in range(1, rings - 2):
		if i % 3 == 0:
			continue
		var x0 := lerpf(-L * 0.5, L * 0.5, float(i) / rings)
		var x1 := lerpf(-L * 0.5, L * 0.5, float(i + 1) / rings) - 0.05
		quad(st, Vector3(x0, 0.95, -1.1), Vector3(x1, 0.95, -1.1), Vector3(x1, 0.95, 1.1), Vector3(x0, 0.95, 1.1), WOOD.lightened(0.1), null)
	# Cabina en la popa
	_box(st, Vector3(-2.6, 1.35, 0), Vector3(1.4, 0.8, 1.9), WOOD.darkened(0.1), rng)
	_box(st, Vector3(-2.6, 1.8, 0), Vector3(1.6, 0.1, 2.1), WOOD.darkened(0.25), rng)
	# Mástil partido
	_prism(st, Vector3(0.6, 0.9, 0), Vector3(0.8, 2.4, 0.15), 0.12, 0.1, 6, WOOD.darkened(0.3), WOOD.darkened(0.2))
	_prism(st, Vector3(1.2, 1.0, 0.5), Vector3(3.6, 0.35, 1.4), 0.1, 0.09, 6, WOOD.darkened(0.3), WOOD.darkened(0.25))
	# Vela rota, meciéndose
	var sail := Color("#d9ccb0")
	tri(st, Vector3(0.75, 2.3, 0.12), Vector3(0.7, 1.3, 0.1), Vector3(1.6, 1.5, 0.9), sail, null, 0.2, 0.1, 0.8, 1.0)
	return _commit("ship", st)


static func barrel() -> ArrayMesh:
	if _cache.has("barrel"):
		return _cache["barrel"]
	var st := _begin()
	var sides := 10
	var ys := [0.0, 0.2, 0.5, 0.7]
	var rs := [0.24, 0.3, 0.3, 0.24]
	for k in 3:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var col := WOOD if i % 2 == 0 else WOOD.darkened(0.12)
			if k != 1:
				col = Color("#4a4d50")    # aros de metal
			quad(st, Vector3(cos(a0) * rs[k], ys[k], sin(a0) * rs[k]), Vector3(cos(a1) * rs[k], ys[k], sin(a1) * rs[k]),
				Vector3(cos(a1) * rs[k + 1], ys[k + 1], sin(a1) * rs[k + 1]), Vector3(cos(a0) * rs[k + 1], ys[k + 1], sin(a0) * rs[k + 1]),
				col, Vector3(0, 0.35, 0))
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		tri(st, Vector3(0, 0.7, 0), Vector3(cos(a0) * 0.24, 0.7, sin(a0) * 0.24), Vector3(cos(a1) * 0.24, 0.7, sin(a1) * 0.24), WOOD.lightened(0.1), Vector3(0, 0, 0))
	return _commit("barrel", st)


static func chest() -> ArrayMesh:
	if _cache.has("chest"):
		return _cache["chest"]
	var st := _begin()
	var gold := Color("#e8be4a")
	_box(st, Vector3(0, 0.2, 0), Vector3(0.75, 0.4, 0.5), WOOD.darkened(0.1))
	# Tapa abierta con monedas
	_box(st, Vector3(0, 0.55, -0.3), Vector3(0.75, 0.4, 0.08), WOOD.darkened(0.2))
	_box(st, Vector3(0, 0.41, 0), Vector3(0.68, 0.04, 0.44), gold)
	_box(st, Vector3(0, 0.2, 0.26), Vector3(0.12, 0.14, 0.03), gold)
	_box(st, Vector3(0.38, 0.2, 0), Vector3(0.03, 0.42, 0.52), gold.darkened(0.2))
	_box(st, Vector3(-0.38, 0.2, 0), Vector3(0.03, 0.42, 0.52), gold.darkened(0.2))
	return _commit("chest", st)


# --- Diamante, pulpo, burbujas ----------------------------------------------------

## Diamante tallado (girdle a 0, mide ~1 de alto).
static func gem() -> ArrayMesh:
	if _cache.has("gem"):
		return _cache["gem"]
	var st := _begin()
	var n := 8
	var c := Vector3(0, 0.05, 0)
	var top := Vector3(0, 0.3, 0)
	var bottom := Vector3(0, -0.6, 0)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var am := (a0 + a1) * 0.5
		var g0 := Vector3(cos(a0) * 0.5, 0, sin(a0) * 0.5)
		var g1 := Vector3(cos(a1) * 0.5, 0, sin(a1) * 0.5)
		var t0 := Vector3(cos(am) * 0.28, 0.3, sin(am) * 0.28)
		var t_prev := Vector3(cos(am - TAU / n) * 0.28, 0.3, sin(am - TAU / n) * 0.28)
		var w := Color.WHITE
		tri(st, g0, g1, t0, w, c)
		tri(st, g0, t0, t_prev, Color(0.92, 0.92, 0.92), c)
		tri(st, top, t_prev, t0, Color(0.97, 0.97, 0.97), c)
		tri(st, bottom, g0, g1, Color(0.8, 0.8, 0.8) if i % 2 == 0 else Color(0.7, 0.7, 0.7), c)
	return _commit("gem", st)


static func octopus() -> ArrayMesh:
	if _cache.has("octopus"):
		return _cache["octopus"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9500
	var st := _begin()
	var col := Color("#b35bd6")
	var dark := Color("#7a3596")
	var spots := col.lightened(0.25)
	var paint := func(_d: Vector3) -> Color:
		return spots if rng.randf() < 0.12 else col
	_blob(st, Vector3(0, 0.55, 0), Vector3(0.48, 0.56, 0.44), 1, 0.04, rng, paint, 0.0)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var dir := Vector3(cos(a), 0, sin(a))
		var prev_p := dir * 0.25 + Vector3(0, 0.2, 0)
		var segs := 6
		for k in segs:
			var t := float(k + 1) / segs
			var p := dir * (0.25 + t * 0.85) + Vector3(0, 0.2 - sin(t * PI * 0.6) * 0.28 + t * t * 0.25, 0)
			var r0 := 0.1 * (1.0 - float(k) / segs) + 0.015
			var r1 := 0.1 * (1.0 - t) + 0.015
			_prism(st, prev_p, p, r0, r1, 4, dark, col, float(k) / segs * 0.9, t * 0.9)
			prev_p = p
	# Ojos mirando a +z (el juego lo gira hacia la cámara)
	for side: float in [-1.0, 1.0]:
		var e := Vector3(0.17 * side, 0.55, 0.38)
		_blob(st, e, Vector3.ONE * 0.11, 0, 0.0, rng, _solid(Color.WHITE))
		_blob(st, e + Vector3(0.01 * side, -0.01, 0.07), Vector3.ONE * 0.06, 0, 0.0, rng, _solid(Color(0.05, 0.05, 0.08)))
	return _commit("octopus", st)


static func sphere(radius := 0.5, segs := 16) -> SphereMesh:
	var key := "sphere%.2f_%d" % [radius, segs]
	if _cache.has(key):
		return _cache[key]
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segs
	m.rings = segs / 2
	_cache[key] = m
	return m
