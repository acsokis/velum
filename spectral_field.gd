extends RefCounted
## Deterministic periodic wave spectrum, evolved in frequency space, then 2D inverse FFT.
const SIZE = 32
var coefficients = PackedVector2Array()
var texture: ImageTexture
var image: Image
var revision = 0
var last_energy = 0.0
var previous_texture: ImageTexture
var plans: Dictionary = {}
var omega = PackedFloat32Array()
var work = PackedVector2Array()
var pixels = PackedByteArray()
var busy = false
var stage = 0
var cursor = 0
var job_clock = 0.0
var last_slice_us = 0
var peak_slice_us = 0

func setup(seed_value: int):
	var rng = RandomNumberGenerator.new();rng.seed = seed_value ^ 0xFF7
	coefficients.resize(SIZE*SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var k = Vector2(x if x <= SIZE/2 else x-SIZE,y if y <= SIZE/2 else y-SIZE)
			var phase = rng.randf()*TAU
			coefficients[y*SIZE+x] = Vector2(cos(phase),sin(phase))*90.0/(1.0+k.length_squared())
	coefficients[0] = Vector2.ZERO
	omega.resize(SIZE*SIZE);work.resize(SIZE*SIZE);pixels.resize(SIZE*SIZE*4)
	for y in range(SIZE):
		for x in range(SIZE):
			var k = Vector2(x if x <= SIZE/2 else x-SIZE,y if y <= SIZE/2 else y-SIZE)
			omega[y*SIZE+x] = sqrt(k.length()*0.9)
	for i in range(SIZE*SIZE): pixels[i*4+3] = 255
	image = Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	previous_texture = ImageTexture.create_from_image(image)
	update(0)

func inverse_fft(input: PackedVector2Array) -> PackedVector2Array:
	var n = input.size()
	if not plans.has(n):
		var reverse = PackedInt32Array();reverse.resize(n);var j = 0
		for i in range(1,n):
			var bit = n >> 1
			while j & bit: j ^= bit;bit >>= 1
			j ^= bit;reverse[i] = j
		var first = PackedInt32Array();var second = PackedInt32Array();var twiddle = PackedVector2Array();var length = 2
		while length <= n:
			for start in range(0,n,length):
				for i in range(length/2):
					first.append(start+i);second.append(start+i+length/2)
					twiddle.append(Vector2(cos(TAU*i/length),sin(TAU*i/length)))
			length *= 2
		plans[n] = {"reverse":reverse,"first":first,"second":second,"twiddle":twiddle}
	var plan: Dictionary = plans[n]
	var first: PackedInt32Array = plan.first;var second: PackedInt32Array = plan.second;var twiddle: PackedVector2Array = plan.twiddle
	var reverse: PackedInt32Array = plan.reverse
	var result = PackedVector2Array();result.resize(n)
	for i in range(n): result[i] = input[reverse[i]]
	for i in range(first.size()):
		var a = result[first[i]];var b = result[second[i]];var w = twiddle[i]
		var product = Vector2(b.x*w.x-b.y*w.y,b.x*w.y+b.y*w.x)
		result[first[i]] = a+product;result[second[i]] = a-product
	for i in range(n): result[i] *= 1.0/n
	return result

func update(clock: float):
	begin_update(clock)
	while busy: work_unit()

func begin_update(clock: float):
	if busy: return
	job_clock = clock;stage = 0;cursor = 0;last_energy = 0;busy = true

func process_budget(budget_us: int = 500):
	var start = Time.get_ticks_usec()
	while busy and Time.get_ticks_usec()-start < budget_us: work_unit()
	last_slice_us = Time.get_ticks_usec()-start;peak_slice_us = maxi(peak_slice_us,last_slice_us)

func work_unit():
	if stage == 0:
		for index in range(cursor,mini(cursor+64,SIZE*SIZE)):
			var x = index%SIZE;var y = index/SIZE;var opposite = posmod(-y,SIZE)*SIZE+posmod(-x,SIZE)
			if index > opposite: continue
			var angle = omega[index]*job_clock;var h = coefficients[index]
			var c = cos(angle);var s = sin(angle);var value = Vector2(h.x*c-h.y*s,h.x*s+h.y*c)
			if index == opposite: value.y = 0
			work[index] = value;work[opposite] = Vector2(value.x,-value.y)
		cursor += 64
		if cursor >= SIZE*SIZE: stage = 1;cursor = 0
	elif stage == 1:
		var row = inverse_fft(work.slice(cursor*SIZE,(cursor+1)*SIZE))
		for x in range(SIZE): work[cursor*SIZE+x] = row[x]
		cursor += 1
		if cursor >= SIZE: stage = 2;cursor = 0
	elif stage == 2:
		var column = PackedVector2Array();column.resize(SIZE)
		for y in range(SIZE): column[y] = work[y*SIZE+cursor]
		column = inverse_fft(column)
		for y in range(SIZE): work[y*SIZE+cursor] = column[y]
		cursor += 1
		if cursor >= SIZE: stage = 3;cursor = 0
	elif stage == 3:
		for i in range(cursor,mini(cursor+128,SIZE*SIZE)):
			var height = work[i].x;last_energy += height*height
			pixels[i*4] = int(clampf(0.5+height*1.8,0,1)*255.0+0.5)
		cursor += 128
		if cursor >= SIZE*SIZE: stage = 4
	else:
		previous_texture.update(image)
		image.set_data(SIZE,SIZE,false,Image.FORMAT_RGBA8,pixels);texture.update(image)
		if revision == 0: previous_texture.update(image)
		revision += 1;busy = false
