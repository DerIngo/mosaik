# Mosaik+

A professional Flutter-based image redaction and editing application designed to easily obscure sensitive areas of pictures (such as faces, license plates, documents, or personal data) using a variety of pixelation, blur, and creative filters.

---

## 🚀 Overview

**Mosaik+** allows users to load an image, select from 17 advanced filters, and paint the effect precisely onto the areas they wish to obscure. The application is built using Flutter and Riverpod, ensuring high performance, clean state management, and seamless support across mobile, desktop, and web platforms (fully optimized as a Progressive Web App (PWA)).

---

## ✨ Features

### 🖌️ Interactive Canvas Tools
- **Zeichnen (Draw Mode):** Brush the selected filter effect directly onto specific regions of the image.
- **Radieren (Erase Mode):** Cleanly erase applied filters to reveal the original image beneath.
- **Feinabstimmung (Fine-tuning):** 
  - **Intensität (Intensity):** Adjust the strength/scale of the filter in real-time.
  - **Pinselgröße (Brush Size):** Dynamically resize the brush to cover tiny details or large regions.

### 🎭 17 Advanced Redaction Filters
The app categorizes its filters to provide the perfect type of obfuscation:

1. **Verpixelung & Raster (Pixelation & Grids)**
   - **Mosaik (Block Pixelate):** Standard classic pixel block effect.
   - **Hexagon:** Honeycomb-patterned pixelation.
   - **Dreiecke (Triangles):** Triangulated mosaic grid.
   - **Voronoi (Polygons):** Organic cellular Voronoi tessellation.
   - **Punkte (Dot Matrix):** Uniform circles arranged in a grid.
   - **Retro Dot (Halftone):** Halftone retro dot pattern styled by luminance.

2. **Unschärfe (Blur Effects)**
   - **Gauß Leicht (Gaussian Light):** Smooth, soft Gaussian blur.
   - **Gauß Stark (Gaussian Strong):** High-radius Gaussian blur for total redaction.
   - **Weichzeichner (Box Blur):** Fast multi-pass box blur.
   - **Motion Horiz. / Diag. / Vert. (Motion Blurs):** Directional blurs simulating horizontal, diagonal, or vertical movement.
   - **Zoom:** Zoom-burst blur radiating from the center of the image.

3. **Künstlerisch & Glas (Artistic & Glass)**
   - **Kristallisieren (Crystallize):** Jittered cellular crystallization noise.
   - **Milchglas (Frosted Glass):** Noise-based frosted glass scattering effect.
   - **Prisma (Prism Glass):** Beveled prismatic refractive tile effect.

4. **Abdeckung (Solid Block)**
   - **Zensurbalken (Censorship Bar):** Overlays solid dark blocks to fully mask content.

---

## 🛠️ Architecture & Technology Stack

Mosaik+ is built on a clean, scalable architecture:

- **Framework:** [Flutter](https://flutter.dev) (built for Web, Desktop, and Mobile support).
- **State Management:** [Riverpod](https://riverpod.dev) (with modern class-based `Notifier` patterns).
- **Core Dependencies:**
  - `image_picker` for picking files from the gallery or local filesystem.
  - `file_saver` for cross-platform file exports.
- **Custom Blending Engine:** Uses off-screen canvases (`PictureRecorder`) to pre-render the active filter effect across the entire image and composites it in real time under the user's hand-drawn paths using custom `Canvas` operations with `BlendMode.srcIn`.

### Directory Layout

```text
lib/
├── core/
│   ├── pwa/                 # Helper scripts for Progressive Web App installation prompts.
│   └── models.dart          # Enum definitions (FilterType, ToolMode) & PathData models.
├── filters/
│   └── image_filters.dart   # Image processing filters using dart:ui & ByteData logic.
├── state/
│   └── providers.dart       # Riverpod state notifiers for brush, tools, image layers, and actions.
├── painters/
│   └── mosaik_painters.dart # Canvas custom painters (MosaikPainter, Box/Motion/ZoomBlurPainters).
└── ui/
    ├── widgets/
    │   ├── canvas_area.dart # Interactive drawing canvas layer with gesture detection.
    │   └── toolbar.dart     # Tool controls, filter select chips, and slider settings.
    └── main_editor.dart     # Outer layout structure, app bar, import/export actions, PWA install handlers.
```

---

## 📦 Getting Started

### Prerequisites

Make sure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your system.

To check your setup, run:
```bash
flutter doctor
```

### Installation

1. **Clone the repository and navigate to the project directory:**
   ```bash
   git clone <repository-url>
   cd mosaik
   ```

2. **Fetch the dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the project on your preferred device:**
   ```bash
   flutter run
   ```

### Building for Web (PWA/WASM)

To build the production-ready Web PWA with WebAssembly (WASM) support for a subdirectory deployment (e.g., `https://HOSTNAME/mosaik/`), run:

```bash
flutter build web --release --wasm --base-href "/mosaik/"
```

*Note: WebAssembly (WasmGC) provides a major performance boost for the image filters. The base href must match your hosting subfolder path.*




---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the issues page or submit pull requests to enhance the filter suite or UI experience.

---

## 📄 License

This project is configured as a private package (`publish_to: 'none'`). All rights reserved.
