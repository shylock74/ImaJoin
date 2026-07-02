# ImaJoin

**ImaJoin** is a high-performance, professional macOS utility designed to seamlessly join multiple images either horizontally or vertically. It preserves original alpha channels (transparency), guarantees perfect pixel alignment, and offers advanced options like real-time padding adjustments and automatic cropping of empty margins.

Built on Swift 6, SwiftUI, and AppKit core graphics, ImaJoin is tailored for designers, developers, and content creators who need a fast, robust tool to merge sprite sheets, UI mockups, icons, and transparent graphics without losing detail or fidelity.

---

## 🚀 Key Features

### 1. Intuitive Drag & Drop Workflow
- Simply drag and drop target image files from Finder into the drop zone.
- Images are automatically sorted alphabetically by filename to ensure a predictable and consistent final output order.

### 2. Multi-Orientation Join Engines
- **Horizontal Join**: Align images side-by-side. If source images vary in height, they are automatically centered vertically along a dynamic canvas sized to the maximum height of the group.
- **Vertical Join**: Align images top-to-bottom. If source images vary in width, they are automatically centered horizontally along a canvas sized to the maximum width of the group.

### 3. Smart Padding Control
- Add negative or positive spacing between images (ranging from `-500px` to `+500px`) using the interactive slider or keyboard input. Negative padding allows overlapping layouts, perfect for creative sprite alignments.

### 4. Intelligent Autocrop (Non-Transparent Bounding Box)
- **Automatic Bounding Box Finder**: Analyzes the alpha channel of each image to find the absolute minimum bounding box containing non-transparent pixels (`alpha > 0`).
- **Dynamic Layout Calculations**: When enabled, the application adjusts layout sizes, margins, and canvas size around the cropped image contents.
- **DPI and Scale Protection**: Retains the backing scale factor of the original images (e.g. `@2x` Retina sizes) when creating cropped representations.
- **Transparency Fallback**: If an image is completely transparent, the system falls back to its original dimensions to avoid zero-size scaling issues.

### 5. Professional Interactive Preview
- **Live Preview Window**: Open a secondary zoomable window to see layout changes, padding modifications, and autocrop states instantly before saving.
- **Pinch-to-Zoom & Pan Gestures**: Full gesture support for zoom-to-fit, zoom-in, zoom-out, and pan using the trackpad.
- **Dynamic Minimap (Bird's Eye View)**: A side-panel minimap renders the entire canvas at scale, featuring a red viewport rectangle that tracks the scroll position in real time.
- **High-Contrast Background Picker**: Instantly toggle between Checkerboard (transparency grid), Solid White, and Solid Black backgrounds to inspect edges and fine transparent details.

### 6. Seamless Asset Saving
- Merged images are saved as lossless transparent PNGs.
- The output file is automatically saved in the same directory as the first source image, named with the suffix `_join.png`, streamlining the asset production workflow.

---

## 🛠️ Architecture & Codebase Structure

The application is structured following modern macOS architectural principles, utilising MVVM and the Swift 6 `@Observable` macro framework.

```
ImaJoin/
├── a. Data Structures/
│   └── IJImageItem.swift         # Data representation of url, raw, and autocropped images.
├── b. Business Logic/
│   └── IJImageJoiner.swift       # Image rendering, alpha extraction, bounding box calculations, and saving.
├── c. View Models/
│   └── IJImageJoinerViewModel.swift # App state machine (padding, joinMode, autocrop, previews).
└── d. UI/
    ├── IJMainView.swift          # Main application window layout and drop zones.
    ├── IJPreviewView.swift       # Preview controller, minimap tracking, background controls.
    └── IJDragAreaView.swift      # Specialized Cocoa/SwiftUI drag-and-drop container.
```

### Technical Highlights
- **Language**: Swift 6
- **Deployment Target**: macOS 14.0+
- **UI Framework**: SwiftUI + local `UMUIControls` package (located at `../UMUIControls` containing premium switches, segmented bars, and sliders).
- **Core Graphics**: `CGContext`, `CGImage`, and `NSBitmapImageRep` are used to perform pixel-perfect image manipulation, preserving color spaces and alpha channels.

---

## 📦 Getting Started & Building

### Prerequisites
- **macOS Sonoma (14.0)** or higher.
- **Xcode 15.0** or higher (supporting Swift 5.9 / 6.0 features).
- The `UMUIControls` sibling directory must be located at `../UMUIControls` relative to this folder.

### Building
1. Open `ImaJoin.xcodeproj` in Xcode.
2. Ensure the scheme is set to `ImaJoin` -> `My Mac`.
3. Press `⌘R` to build and run the application.

---

## 📝 License
This project is private and proprietary. All rights reserved.
