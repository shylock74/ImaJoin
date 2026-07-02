# ImaJoin

ImaJoin is a professional macOS application designed to join multiple images either horizontally or vertically while maintaining their original alpha channels and ensuring perfect alignment.

## Key Features

- **Intuitive Drag & Drop**: Simply drag and drop your image files into the designated area to begin processing.
- **Advanced Join Modes**:
	- **Horizontal Join**: Combines images side-by-side. If images vary in height, they are vertically centered, and the canvas height is set to the maximum height among all images.
	- **Vertical Join**: Combines images top-to-bottom. If images vary in width, they are horizontally centered, and the canvas width is set to the maximum width among all images.
- **Smart Alphabetical Sorting**: To ensure a predictable result, images are automatically sorted by their filename in alphabetical order before the join operation.
- **Interactive Preview**:
	- Open a dedicated preview window to inspect the result before or after saving.
	- **Zoom & Pan**: Use gestures to pinch-to-zoom or scroll naturally with native macOS scroll bars. Dedicated zoom buttons (In, Out, Fit) are available for precise control.
	- **Minimap (Bird's Eye View)**: A dedicated side panel displays a downscaled version of the whole image, featuring a red tracking rectangle to clearly indicate the currently visible area.
	- **Custom Backgrounds**: Choose between White, Black, or a Checkerboard background to check transparency and contrast.
- **Preserve Transparency**: Full support for the alpha channel (transparency) is maintained throughout the process, and the final output is saved in the PNG format with a `_join` suffix.
- **Integrated Workflow**: The resulting image is automatically saved in the same directory as the first source image.

## Technical Details

- **Language**: Swift 6
- **UI Framework**: SwiftUI + `UMUIControls`
- **Architecture**: MVVM with `@Observable` (Combine)
- **Image Processing**: AppKit (`NSImage`, `NSBitmapImageRep`)
- **UI Modernization**: The interface uses the `UMUIControls` library for a grouped, elegant, and native macOS feel. Standard components have been upgraded to `UMUICapsuleButton`, `UMUISegmentedBar`, `UMUINumberControl`, and grouped within `UMUISection`s. Note: AppKit/UIKit components are retained under the hood for core image rendering logic to ensure robustness and backward compatibility.

## Usage Instructions

1. **Launch the App**: Open ImaJoin on your Mac.
2. **Select Orientation**: Choose between "Horizontal" or "Vertical" join mode.
3. **Drop Images**: Drag the images you want to combine into the "Input" area.
4. **View Preview**: Click "Open Preview" to launch the preview window. You can scroll, zoom, pan, check the minimap to track your position, and change the background style.
5. **View Result**: Click "Show in Finder" to reveal the saved PNG file (saved with `_join` suffix).
