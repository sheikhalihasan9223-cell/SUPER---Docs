# Bundled offline super-resolution model

ESRGAN TensorFlow Lite model, downloaded from the official TensorFlow Android super-resolution sample:
https://storage.googleapis.com/download.tensorflow.org/models/tflite/esrgan/ESRGAN.tflite

Model SHA-256: 1a380d3744103e11ef343534aaff54815cae40769dcd00c023652a7e5bc47f4b
Model size: 4,993,712 bytes.
Input: float32 RGB values 0..255, [1,50,50,3]. Output: float32 RGB [1,200,200,3].

Sample and model overview: https://blog.tensorflow.org/2020/12/how-to-generate-super-resolution-images-using-tensorflow-lite-on-android.html
Original TensorFlow Hub model: captain-pool/esrgan-tf2/1.
Runtime: tflite_flutter 0.12.1, Apache-2.0.

Inference uses overlapping tiles with edge replication. Large input photos are first resized to a maximum 512-pixel longest edge. The 4x model output is retained for 4x export, or area-resized to 2x. Basic enhancement retains the original image resolution.

No API key, login, server or download is needed at runtime. Completed results follow the same auto-save, view, download and share flow as other tools. Account cloud backup remains a separate user feature.

Upstream model implementation notice: MIT, copyright 2020 Adrish Dey (`MODEL_LICENSE.txt`). TensorFlow example/runtime notices are included in `TENSORFLOW_LICENSE.txt`.
