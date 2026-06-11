class_name IntNoiseUtil
extends RefCounted

## 整数哈希噪声工具（设计稿 §5）：squirrel3 式 32 位掩码哈希 + 定点双线性值噪声。
## 全部运算落在 32 位掩码整数上，跨平台逐位一致；不用 FastNoiseLite（浮点位差风险）。
## headless 测试经 preload 使用，勿依赖 class_name 注册。

const MASK_32 := 0xFFFFFFFF
const NOISE_1 := 0xB5297A4D
const NOISE_2 := 0x68E31DA4
const NOISE_3 := 0x1B56C4E9
const PRIME_Y := 198491317


## squirrel3 单值哈希：输入任意 int，输出 [0, 2^32) 掩码整数。
## 乘法用 16 位分拆避免 GDScript 64 位有符号溢出。
static func squirrel3(position: int, seed_value: int) -> int:
	var mangled: int = position & MASK_32
	# 16-bit lane multiply: (lo + hi<<16) * k  avoiding >2^63 intermediate
	mangled = _mul32(mangled, NOISE_1)
	mangled = (mangled + (seed_value & MASK_32)) & MASK_32
	mangled ^= (mangled >> 8)
	mangled = (mangled + NOISE_2) & MASK_32
	mangled ^= (mangled << 8) & MASK_32
	mangled = _mul32(mangled, NOISE_3)
	mangled ^= (mangled >> 8)
	return mangled & MASK_32


## 32×32 位掩码乘法，不溢出 GDScript 的 int64。
static func _mul32(a: int, b: int) -> int:
	# Split a into low 16 bits and high 16 bits.
	var lo: int = a & 0xFFFF
	var hi: int = (a >> 16) & 0xFFFF
	# lo * b fits in 2^16 * 2^32 = 2^48 — safe.
	# hi * b fits in 2^16 * 2^32 = 2^48, shifted << 16 = 2^64 — would overflow!
	# 取 hi*b 的低 16 位（高位在 <<16 后超出 mod 2^32 范围自然消失）
	return ((lo * b) + (((hi * b) & 0xFFFF) << 16)) & MASK_32


## 种子派生链：run_seed → attempt → stage，三层 squirrel3 嵌套（设计稿 S0）。
static func derive_seed(run_seed: int, attempt: int, stage_id: int) -> int:
	var mixed: int = squirrel3(run_seed, 0)
	mixed = squirrel3(attempt, mixed)
	mixed = squirrel3(stage_id, mixed)
	return mixed


## 二维格点哈希：输出 [0, 65536) 的 16 位整数（双线性用）。
static func cell_hash(x: int, y: int, seed_value: int) -> int:
	var yx: int = _mul32(y, PRIME_Y)
	return squirrel3((x + yx) & MASK_32, seed_value) >> 16


## 定点双线性值噪声：输出 [0.0, 1.0)。scale = 噪声网格边长（格数，>=1）。
## 权重用 1/256 定点，整数插值后才除以 65536.0——同输入逐位一致。
static func value_noise(x: int, y: int, seed_value: int, scale: int) -> float:
	var safe_scale: int = maxi(scale, 1)
	var gx: int = x / safe_scale if x >= 0 else (x - safe_scale + 1) / safe_scale
	var gy: int = y / safe_scale if y >= 0 else (y - safe_scale + 1) / safe_scale
	var fx: int = (x - gx * safe_scale) * 256 / safe_scale
	var fy: int = (y - gy * safe_scale) * 256 / safe_scale
	var h00: int = cell_hash(gx, gy, seed_value)
	var h10: int = cell_hash(gx + 1, gy, seed_value)
	var h01: int = cell_hash(gx, gy + 1, seed_value)
	var h11: int = cell_hash(gx + 1, gy + 1, seed_value)
	var top: int = h00 * (256 - fx) + h10 * fx
	var bottom: int = h01 * (256 - fx) + h11 * fx
	var blended: int = (top * (256 - fy) + bottom * fy) >> 16
	return float(blended) / 65536.0
