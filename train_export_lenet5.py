import os
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.datasets import mnist
from PIL import Image, ImageDraw, ImageFont

# =========================
# CONFIG
# =========================

MEM_DIR = "mem"
os.makedirs(MEM_DIR, exist_ok=True)

SCALE = 256  # Q8.8
EPOCHS = 5
BATCH_SIZE = 128
TEST_SAMPLE_INDEX = 0


# =========================
# FIXED-POINT CONVERT
# =========================

def float_to_q88(x):
    value = int(np.round(float(x) * SCALE))

    if value > 32767:
        value = 32767
    if value < -32768:
        value = -32768

    return value


def int16_to_hex(value):
    if value < 0:
        value = (1 << 16) + value
    return f"{value & 0xFFFF:04x}"


def write_mem(filename, values):
    path = os.path.join(MEM_DIR, filename)
    with open(path, "w") as f:
        for v in values:
            q = float_to_q88(v)
            f.write(int16_to_hex(q) + "\n")

    print(f"Exported {filename}: {len(values)} values")


def write_image_mem(filename, image_32x32):
    path = os.path.join(MEM_DIR, filename)
    with open(path, "w") as f:
        for r in range(32):
            for c in range(32):
                q = float_to_q88(image_32x32[r, c])
                f.write(int16_to_hex(q) + "\n")

    print(f"Exported {filename}: 1024 pixels")


# =========================
# EXPORT PNG (28x28 goc + label + predicted)
# =========================

def export_sample_png(image_28, true_label, pred_label, index, output_dir=MEM_DIR):
    """
    Xuat file PNG cua anh MNIST goc (28x28) voi caption:
      - True label
      - Predicted label
      - Ket qua dung/sai
    Anh duoc scale len 280x280 (x10) de de nhin.
    """
    SCALE_FACTOR = 10
    IMG_SIZE     = 28 * SCALE_FACTOR   # 280
    CAPTION_H    = 60                  # chieu cao vung chu phia duoi
    BORDER       = 4

    # Chuyen float [0,1] -> uint8 [0,255]
    img_uint8 = (image_28 * 255).astype(np.uint8)

    # Tao anh PIL tu numpy, scale len
    pil_img = Image.fromarray(img_uint8, mode='L')
    pil_img = pil_img.resize((IMG_SIZE, IMG_SIZE), Image.NEAREST)

    # Tao canvas (RGB trang) lon hon de chen caption
    canvas_w = IMG_SIZE + BORDER * 2
    canvas_h = IMG_SIZE + CAPTION_H + BORDER * 2
    canvas = Image.new("RGB", (canvas_w, canvas_h), color=(245, 245, 245))

    # Dan anh MNIST (chuyen L -> RGB) vao canvas
    pil_rgb = pil_img.convert("RGB")
    canvas.paste(pil_rgb, (BORDER, BORDER))

    # Ve caption
    draw = ImageDraw.Draw(canvas)

    is_correct   = (true_label == pred_label)
    status_text  = "CORRECT" if is_correct else "WRONG"
    status_color = (0, 160, 0) if is_correct else (200, 0, 0)

    caption_y = IMG_SIZE + BORDER + 6

    # Dong 1: True label & Predicted label
    draw.text(
        (BORDER + 4, caption_y),
        f"True: {true_label}    Predicted: {pred_label}",
        fill=(30, 30, 30)
    )

    # Dong 2: CORRECT / WRONG
    draw.text(
        (BORDER + 4, caption_y + 22),
        f"Result: {status_text}  |  Sample index: {index}",
        fill=status_color
    )

    # Luu file
    filename = f"sample_{index}_true{true_label}_pred{pred_label}.png"
    out_path  = os.path.join(output_dir, filename)
    canvas.save(out_path)

    print(f"Exported PNG : {out_path}  [{status_text}]")
    return out_path


# =========================
# LOAD MNIST
# =========================

(x_train, y_train), (x_test, y_test) = mnist.load_data()

x_train = x_train.astype("float32") / 255.0
x_test  = x_test.astype("float32")  / 255.0

x_train = np.expand_dims(x_train, axis=-1)  # 28x28x1
x_test  = np.expand_dims(x_test,  axis=-1)

y_train_cat = tf.keras.utils.to_categorical(y_train, 10)
y_test_cat  = tf.keras.utils.to_categorical(y_test,  10)


# =========================
# BUILD LENET-5 MODEL (Modified)
# Input 28x28 -> ZeroPad 32x32
# C1: Conv 5x5, 6 filters, valid -> 28x28x6
# S2: AvgPool 2x2 -> 14x14x6
# C3: Conv 5x5, 16 filters, valid -> 10x10x16
# S4: AvgPool 2x2 -> 5x5x16
# Permute to channel-first before Flatten -> 400
# C5:  Dense 128  (changed from 120)
# FC1: Dense  64  (changed from  84)
# FC2: Dense  10
# =========================

model = models.Sequential([
    layers.Input(shape=(28, 28, 1)),

    layers.ZeroPadding2D(padding=(2, 2), name="pad_32x32"),

    layers.Conv2D(
        filters=6,
        kernel_size=(5, 5),
        activation="relu",
        padding="valid",
        name="c1"
    ),

    layers.AveragePooling2D(pool_size=(2, 2), name="s2"),

    layers.Conv2D(
        filters=16,
        kernel_size=(5, 5),
        activation="relu",
        padding="valid",
        name="c3"
    ),

    layers.AveragePooling2D(pool_size=(2, 2), name="s4"),

    # Keras default Flatten order is row-col-channel.
    # Verilog expects channel-row-col.
    # So we permute from (5,5,16) to (16,5,5).
    layers.Flatten(name="flatten"),

    layers.Dense(128, activation="relu", name="c5"),   # changed: 120 -> 128
    layers.Dense(64,  activation="relu", name="fc1"),  # changed:  84 ->  64
    layers.Dense(10,  activation=None,   name="fc2")
])

model.compile(
    optimizer="adam",
    loss=tf.keras.losses.CategoricalCrossentropy(from_logits=True),
    metrics=["accuracy"]
)

model.summary()


# =========================
# TRAIN
# =========================

print("\nTraining LeNet-5 (modified 128/64) on MNIST...\n")

model.fit(
    x_train,
    y_train_cat,
    epochs=EPOCHS,
    batch_size=BATCH_SIZE,
    validation_split=0.1,
    verbose=1
)

loss, acc = model.evaluate(x_test, y_test_cat, verbose=0)

print("\n==============================")
print(f"Test Accuracy: {acc * 100:.2f}%")
print(f"Test Loss: {loss:.4f}")
print("==============================\n")


# =========================
# EXPORT WEIGHTS TO .MEM
# =========================

# ----- C1 -----
# Keras c1 weight shape: (5, 5, 1, 6)
# Verilog expects: filter -> kr -> kc
c1_w, c1_b = model.get_layer("c1").get_weights()

c1_weight_list = []
for f in range(6):
    for kr in range(5):
        for kc in range(5):
            c1_weight_list.append(c1_w[kr, kc, 0, f])

write_mem("c1_weight.mem", c1_weight_list)
write_mem("c1_bias.mem", c1_b)


# ----- C3 -----
# Keras c3 weight shape: (5, 5, 6, 16)
# Verilog expects: filter -> channel -> kr -> kc
c3_w, c3_b = model.get_layer("c3").get_weights()

c3_weight_list = []
for f in range(16):
    for ch in range(6):
        for kr in range(5):
            for kc in range(5):
                c3_weight_list.append(c3_w[kr, kc, ch, f])

write_mem("c3_weight.mem", c3_weight_list)
write_mem("c3_bias.mem", c3_b)


# ----- C5 -----
# Keras dense weight shape: (400, 128)
# Verilog expects: neuron -> input_index
c5_w, c5_b = model.get_layer("c5").get_weights()

c5_weight_list = []
for n in range(128):
    for i in range(400):
        c5_weight_list.append(c5_w[i, n])

write_mem("c5_weight.mem", c5_weight_list)
write_mem("c5_bias.mem", c5_b)


# ----- FC1 -----
# Keras dense weight shape: (128, 64)
# Verilog expects: neuron -> input_index
fc1_w, fc1_b = model.get_layer("fc1").get_weights()

fc1_weight_list = []
for n in range(64):
    for i in range(128):
        fc1_weight_list.append(fc1_w[i, n])

write_mem("fc1_weight.mem", fc1_weight_list)
write_mem("fc1_bias.mem", fc1_b)


# ----- FC2 -----
# Keras dense weight shape: (64, 10)
# Verilog expects: neuron/class -> input_index
fc2_w, fc2_b = model.get_layer("fc2").get_weights()

fc2_weight_list = []
for n in range(10):
    for i in range(64):
        fc2_weight_list.append(fc2_w[i, n])

write_mem("fc2_weight.mem", fc2_weight_list)
write_mem("fc2_bias.mem", fc2_b)


# =========================
# EXPORT TEST IMAGE (.mem + .png)
# =========================

test_img_28 = x_test[TEST_SAMPLE_INDEX, :, :, 0]   # 28x28 float
true_label  = y_test[TEST_SAMPLE_INDEX]

# Pad 28x28 -> 32x32 cho Verilog
test_img_32 = np.pad(test_img_28, ((2, 2), (2, 2)), mode="constant", constant_values=0)
write_image_mem("image.mem", test_img_32)

# Prediction bang Python model
logits = model.predict(x_test[TEST_SAMPLE_INDEX:TEST_SAMPLE_INDEX + 1], verbose=0)
pred   = int(np.argmax(logits[0]))

# Xuat PNG bang chung visual
export_sample_png(test_img_28, int(true_label), pred, TEST_SAMPLE_INDEX)

print("\n==============================")
print("Export finished.")
print(f"Test sample index : {TEST_SAMPLE_INDEX}")
print(f"True label        : {true_label}")
print(f"Python predicted  : {pred}")
print(f"Match             : {'YES ✓' if true_label == pred else 'NO ✗'}")
print("Now run ModelSim again.")
print("==============================\n")