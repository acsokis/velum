extends RefCounted
## Deterministic periodic wave spectrum, evolved in frequency space, then 2D inverse FFT.
const SIZE = 32
var coefficients = PackedVector2Array()
var texture: ImageTexture
var image: Image
var revision = 0
var last_energy = 0.0

func setup(seed_value: int):
	var rng = RandomNumberGenerator.new();rng.seed = seed_value ^ 0xFF7
	coefficients.resize(SIZE*SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var k = Vector2(x if x <= SIZE/2 else x-SIZE,y if y <= SIZE/2 else y-SIZE)
			var phase = rng.randf()*TAU
			coefficients[y*SIZE+x] = Vector2(cos(phase),sin(phase))*90.0/(1.0+k.length_squared())
	coefficients[0] = Vector2.ZERO
	image = Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	update(0)

func inverse_fft(input: PackedVector2Array) -> PackedVector2Array:
	var result = input.duplicate();var n = result.size();var j = 0
	for i in range(1,n):
		var bit = n >> 1
		while j & bit: j ^= bit;bit >>= 1
		j ^= bit
		if i < j:
			var swap = result[i];result[i] = result[j];result[j] = swap
	var length = 2
	while length <= n:
		var angle = TAU/length;var increment = Vector2(cos(angle),sin(angle))
		for start in range(0,n,length):
			var w = Vector2(1,0)
			for i in range(length/2):
				var a = result[start+i];var b = result[start+i+length/2]
				var product = Vector2(b.x*w.x-b.y*w.y,b.x*w.y+b.y*w.x)
				result[start+i] = a+product;result[start+i+length/2] = a-product
				w = Vector2(w.x*increment.x-w.y*increment.y,w.x*increment.y+w.y*increment.x)
		length *= 2
	for i in range(n): result[i] /= float(n)
	return result

func update(clock: float):
	var field = PackedVector2Array();field.resize(SIZE*SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var index = y*SIZE+x;var opposite = posmod(-y,SIZE)*SIZE+posmod(-x,SIZE)
			if index > opposite: continue
			var k = Vector2(x if x <= SIZE/2 else x-SIZE,y if y <= SIZE/2 else y-SIZE)
			var angle = sqrt(k.length()*0.9)*clock
			var h = coefficients[index];var value = Vector2(h.x*cos(angle)-h.y*sin(angle),h.x*sin(angle)+h.y*cos(angle))
			if index == opposite: value.y = 0
			field[index] = value;field[opposite] = Vector2(value.x,-value.y)
	for y in range(SIZE):
		var row = inverse_fft(field.slice(y*SIZE,(y+1)*SIZE))
		for x in range(SIZE): field[y*SIZE+x] = row[x]
	for x in range(SIZE):
		var column = PackedVector2Array();column.resize(SIZE)
		for y in range(SIZE): column[y] = field[y*SIZE+x]
		column = inverse_fft(column)
		for y in range(SIZE): field[y*SIZE+x] = column[y]
	last_energy = 0
	for y in range(SIZE):
		for x in range(SIZE):
			var height = field[y*SIZE+x].x;last_energy += height*height
			image.set_pixel(x,y,Color(clampf(0.5+height*1.8,0,1),0,0,1))
	texture.update(image);revision += 1
