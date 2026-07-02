# ImaJoin

ImaJoin is a professional macOS application designed to join multiple images either horizontally or vertically while maintaining their original alpha channels and ensuring perfect alignment.

## Key Features

- **Intuitive Drag & Drop**: Simply drag and drop your image files into the designated area to begin processing.
- **Advanced Join Modes**:
	- **Horizontal Join**: Combines images side-by-side. If images vary in height, they are vertically centered, and the canvas height is set to the maximum height among all images.
	- **Vertical Join**: Combines images top-to-bottom. If images vary in width, they are horizontally centered, and the canvas width is set to the maximum width among all images.
- **Smart Alphabetical Sorting**: To ensure a predictable result, images are automatically sorted by their filename in alphabetical order before the join operation.
- **Preserve Transparency**: Full support for the alpha channel (transparency) is maintained throughout the process, and the final output is saved in the PNG format.
- **Integrated Workflow**: The resulting image is automatically saved in the same directory as the first source image, making it easy to find and use.

## Technical Details

- **Language**: Swift 6
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with `@Observable` (Combine)
- **Image Processing**: AppKit (`NSImage`, `NSBitmapImageRep`)

## Usage Instructions

1. **Launch the App**: Open ImaJoin on your Mac.
2. **Select Orientation**: Choose between "Join Horizontally" or "Join Vertically" using the segmented control at the top.
3. **Drop Images**: Drag the images you want to combine into the "Drag images here" area.
4. **Processing**: The app will automatically sort the images alphabetically and perform the join operation in the background.
5. **View Result**: Once complete, a success message will appear with a "Show in Finder" link to reveal the saved PNG file.
