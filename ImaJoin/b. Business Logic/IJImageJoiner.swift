import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// IJJoinMode defines the orientation for joining images.
/// It is used to specify whether images should be laid out horizontally, vertically, or in a grid.
public enum IJJoinMode: String, CaseIterable, Sendable {
	/// Images are placed side-by-side.
	case horizontal = "Horizontal"
	/// Images are placed top-to-bottom.
	case vertical = "Vertical"
	/// Images are placed in a grid.
	case grid = "Grid"
}

/// IJGridPriority defines how the grid layout behaves when the number of images exceeds R * C.
public enum IJGridPriority: String, CaseIterable, Sendable {
	/// Columns count is respected, new rows are added.
	case columns = "Columns"
	/// Rows count is respected, new columns are added.
	case rows = "Rows"
	/// Standard grid dimensions are strictly respected, ignoring excess images.
	case none = "None"
}

/// IJSizingMode defines how items are sized.
public enum IJSizingMode: String, CaseIterable, Sendable {
	case original = "Original Size"
	case uniformToMax = "Uniform to Max"
	case uniformToMin = "Uniform to Min"
	case custom = "Custom Size"
}

/// IJScalingMode defines how images scale inside their cells.
public enum IJScalingMode: String, CaseIterable, Sendable {
	case fit = "Fit"
	case stretch = "Stretch"
}

/// IJHorizontalAlignment defines horizontal alignment within a cell/canvas.
public enum IJHorizontalAlignment: String, CaseIterable, Sendable {
	case left = "Left"
	case center = "Center"
	case right = "Right"
}

/// IJVerticalAlignment defines vertical alignment within a cell/canvas.
public enum IJVerticalAlignment: String, CaseIterable, Sendable {
	case top = "Top"
	case center = "Center"
	case bottom = "Bottom"
}

/// IJExportFormat defines the output file format.
public enum IJExportFormat: String, CaseIterable, Sendable {
	case png = "PNG"
	case jpeg = "JPEG"
	case webp = "WebP"
	case tiff = "TIFF"
}

/// IJImageLayoutFrame holds layout coordinate data for a single image within the final stitched image.
public struct IJImageLayoutFrame: Sendable {
	public let item: IJImageItem
	public let rect: NSRect      // Cell boundaries on canvas
	public let drawRect: NSRect  // Image drawing boundaries inside the cell (absolute coordinates on canvas)
}

/// IJImageJoiner provides static methods to join images and save the result.
/// This class contains the core logic for image processing and file I/O.
public class IJImageJoiner {
	
	private static func nextPowerOfTwo(_ value: CGFloat) -> CGFloat {
		let doubleVal = Double(value)
		guard doubleVal > 1 else { return 1 }
		return CGFloat(pow(2.0, ceil(log2(doubleVal))))
	}
	
	/// Calculates the detailed layout coordinates for the joined images.
	public static func calculateLayout (
		items: [IJImageItem],
		mode: IJJoinMode,
		spacing: Double,
		autocrop: Bool = false,
		gridRows: Int = 2,
		gridCols: Int = 2,
		gridPriority: IJGridPriority = .columns,
		sizingMode: IJSizingMode = .original,
		scalingMode: IJScalingMode = .fit,
		customWidth: Double = 128,
		customHeight: Double = 128,
		horizontalAlignment: IJHorizontalAlignment = .center,
		verticalAlignment: IJVerticalAlignment = .center,
		powerOfTwo: Bool = false
	) -> (canvasSize: NSSize, frames: [IJImageLayoutFrame]) {
		guard !items.isEmpty else {
			return (.zero, [])
		}
		
		let targetItems = items
		
		// 1. Calculate cell target size for each item
		let workSizes = targetItems.map { item -> NSSize in
			let img = autocrop ? item.croppedImage : item.image
			return img.size
		}
		
		let maxW = workSizes.map { $0.width }.max() ?? 0
		let maxH = workSizes.map { $0.height }.max() ?? 0
		
		let minW = workSizes.map { $0.width }.min() ?? 0
		let minH = workSizes.map { $0.height }.min() ?? 0
		
		// 2. Pre-calculate the cell size for each item based on sizingMode
		var cellSizes: [NSSize] = []
		for itemSize in workSizes {
			switch sizingMode {
			case .original:
				cellSizes.append(itemSize)
			case .uniformToMax:
				cellSizes.append(NSSize(width: maxW, height: maxH))
			case .uniformToMin:
				cellSizes.append(NSSize(width: minW, height: minH))
			case .custom:
				cellSizes.append(NSSize(width: CGFloat(customWidth), height: CGFloat(customHeight)))
			}
		}
		
		var frames: [IJImageLayoutFrame] = []
		var canvasSize = NSSize.zero
		
		// 3. Perform placement
		if mode == .horizontal {
			let maxCellH = cellSizes.map { $0.height }.max() ?? 0
			let totalCellW = cellSizes.map { $0.width }.reduce(0, +)
			let totalSpacing = CGFloat(targetItems.count - 1) * CGFloat(spacing)
			canvasSize = NSSize(width: totalCellW + totalSpacing, height: maxCellH)
			
			var currentX: CGFloat = 0
			for (index, item) in targetItems.enumerated() {
				let cellSize = cellSizes[index]
				let cellW = cellSize.width
				let cellH = cellSize.height
				
				let yOffset: CGFloat
				switch verticalAlignment {
				case .top:
					yOffset = maxCellH - cellH
				case .center:
					yOffset = (maxCellH - cellH) / 2
				case .bottom:
					yOffset = 0
				}
				
				let cellRect = NSRect(x: currentX, y: yOffset, width: cellW, height: cellH)
				let drawRect = calculateDrawRect(imageSize: workSizes[index], inside: cellRect, scalingMode: scalingMode, hAlign: horizontalAlignment, vAlign: verticalAlignment)
				
				frames.append(IJImageLayoutFrame(item: item, rect: cellRect, drawRect: drawRect))
				currentX += cellW + CGFloat(spacing)
			}
		} else if mode == .vertical {
			let maxCellW = cellSizes.map { $0.width }.max() ?? 0
			let totalCellH = cellSizes.map { $0.height }.reduce(0, +)
			let totalSpacing = CGFloat(targetItems.count - 1) * CGFloat(spacing)
			canvasSize = NSSize(width: maxCellW, height: totalCellH + totalSpacing)
			
			var currentY = canvasSize.height
			for (index, item) in targetItems.enumerated() {
				let cellSize = cellSizes[index]
				let cellW = cellSize.width
				let cellH = cellSize.height
				
				let xOffset: CGFloat
				switch horizontalAlignment {
				case .left:
					xOffset = 0
				case .center:
					xOffset = (maxCellW - cellW) / 2
				case .right:
					xOffset = maxCellW - cellW
				}
				
				currentY -= cellH
				let cellRect = NSRect(x: xOffset, y: currentY, width: cellW, height: cellH)
				let drawRect = calculateDrawRect(imageSize: workSizes[index], inside: cellRect, scalingMode: scalingMode, hAlign: horizontalAlignment, vAlign: verticalAlignment)
				
				frames.append(IJImageLayoutFrame(item: item, rect: cellRect, drawRect: drawRect))
				currentY -= CGFloat(spacing)
			}
		} else {
			// Grid Mode
			let uniformCellSize: NSSize
			switch sizingMode {
			case .original:
				uniformCellSize = NSSize(width: maxW, height: maxH)
			case .uniformToMax:
				uniformCellSize = NSSize(width: maxW, height: maxH)
			case .uniformToMin:
				uniformCellSize = NSSize(width: minW, height: minH)
			case .custom:
				uniformCellSize = NSSize(width: CGFloat(customWidth), height: CGFloat(customHeight))
			}
			
			let count = targetItems.count
			var actualRows = max(1, gridRows)
			var actualCols = max(1, gridCols)
			
			if count > actualRows * actualCols {
				switch gridPriority {
				case .columns:
					actualCols = max(1, gridCols)
					actualRows = max(1, Int(ceil(Double(count) / Double(actualCols))))
				case .rows:
					actualRows = max(1, gridRows)
					actualCols = max(1, Int(ceil(Double(count) / Double(actualRows))))
				case .none:
					break
				}
			}
			
			let maxImagesToDraw = actualRows * actualCols
			let itemsToDraw = Array(targetItems.prefix(maxImagesToDraw))
			
			canvasSize = NSSize(
				width: CGFloat(actualCols) * uniformCellSize.width + CGFloat(max(0, actualCols - 1)) * CGFloat(spacing),
				height: CGFloat(actualRows) * uniformCellSize.height + CGFloat(max(0, actualRows - 1)) * CGFloat(spacing)
			)
			
			for (index, item) in itemsToDraw.enumerated() {
				let row = index / actualCols
				let col = index % actualCols
				
				let cellX = CGFloat(col) * uniformCellSize.width + CGFloat(col) * CGFloat(spacing)
				let cellY = canvasSize.height - CGFloat(row + 1) * uniformCellSize.height - CGFloat(row) * CGFloat(spacing)
				
				let cellRect = NSRect(x: cellX, y: cellY, width: uniformCellSize.width, height: uniformCellSize.height)
				
				let drawSize: NSSize
				if sizingMode == .original {
					drawSize = workSizes[index]
				} else {
					switch scalingMode {
					case .stretch:
						drawSize = uniformCellSize
					case .fit:
						let scale = min(uniformCellSize.width / workSizes[index].width, uniformCellSize.height / workSizes[index].height)
						drawSize = NSSize(width: workSizes[index].width * scale, height: workSizes[index].height * scale)
					}
				}
				
				let xOffset: CGFloat
				switch horizontalAlignment {
				case .left:
					xOffset = 0
				case .center:
					xOffset = (uniformCellSize.width - drawSize.width) / 2
				case .right:
					xOffset = uniformCellSize.width - drawSize.width
				}
				
				let yOffset: CGFloat
				switch verticalAlignment {
				case .bottom:
					yOffset = 0
				case .center:
					yOffset = (uniformCellSize.height - drawSize.height) / 2
				case .top:
					yOffset = uniformCellSize.height - drawSize.height
				}
				
				let drawRect = NSRect(x: cellX + xOffset, y: cellY + yOffset, width: drawSize.width, height: drawSize.height)
				
				frames.append(IJImageLayoutFrame(item: item, rect: cellRect, drawRect: drawRect))
			}
		}
		
		// 4. Power of Two adjustment
		if powerOfTwo {
			let originalH = canvasSize.height
			let finalW = nextPowerOfTwo(canvasSize.width)
			let finalH = nextPowerOfTwo(canvasSize.height)
			
			let offsetY = finalH - originalH
			canvasSize = NSSize(width: finalW, height: finalH)
			
			frames = frames.map { frame in
				let newRect = NSRect(x: frame.rect.origin.x, y: frame.rect.origin.y + offsetY, width: frame.rect.width, height: frame.rect.height)
				let newDrawRect = NSRect(x: frame.drawRect.origin.x, y: frame.drawRect.origin.y + offsetY, width: frame.drawRect.width, height: frame.drawRect.height)
				return IJImageLayoutFrame(item: frame.item, rect: newRect, drawRect: newDrawRect)
			}
		}
		
		return (canvasSize, frames)
	}
	
	private static func calculateDrawRect(
		imageSize: NSSize,
		inside cellRect: NSRect,
		scalingMode: IJScalingMode,
		hAlign: IJHorizontalAlignment,
		vAlign: IJVerticalAlignment
	) -> NSRect {
		let drawW: CGFloat
		let drawH: CGFloat
		
		switch scalingMode {
		case .stretch:
			drawW = cellRect.width
			drawH = cellRect.height
		case .fit:
			let scale = min(cellRect.width / imageSize.width, cellRect.height / imageSize.height)
			drawW = imageSize.width * scale
			drawH = imageSize.height * scale
		}
		
		let x: CGFloat
		switch hAlign {
		case .left:
			x = cellRect.minX
		case .center:
			x = cellRect.minX + (cellRect.width - drawW) / 2
		case .right:
			x = cellRect.minX + (cellRect.width - drawW)
		}
		
		let y: CGFloat
		switch vAlign {
		case .bottom:
			y = cellRect.minY
		case .center:
			y = cellRect.minY + (cellRect.height - drawH) / 2
		case .top:
			y = cellRect.minY + (cellRect.height - drawH)
		}
		
		return NSRect(x: x, y: y, width: drawW, height: drawH)
	}
	
	/// Joins a list of images according to the specified mode and saves the result using CGImageDestination.
	public static func joinAndSave (
		items: [IJImageItem],
		mode: IJJoinMode,
		spacing: Double = 0,
		autocrop: Bool = false,
		gridRows: Int = 2,
		gridCols: Int = 2,
		gridPriority: IJGridPriority = .columns,
		sizingMode: IJSizingMode = .original,
		scalingMode: IJScalingMode = .fit,
		customWidth: Double = 128,
		customHeight: Double = 128,
		horizontalAlignment: IJHorizontalAlignment = .center,
		verticalAlignment: IJVerticalAlignment = .center,
		powerOfTwo: Bool = false,
		exportMetadata: Bool = false,
		exportFormat: IJExportFormat = .png,
		exportQuality: Double = 0.8,
		outputURL: URL
	) -> URL? {
		guard !items.isEmpty else {
			return nil
		}
		
		let (resultSize, frames) = calculateLayout(
			items: items,
			mode: mode,
			spacing: spacing,
			autocrop: autocrop,
			gridRows: gridRows,
			gridCols: gridCols,
			gridPriority: gridPriority,
			sizingMode: sizingMode,
			scalingMode: scalingMode,
			customWidth: customWidth,
			customHeight: customHeight,
			horizontalAlignment: horizontalAlignment,
			verticalAlignment: verticalAlignment,
			powerOfTwo: powerOfTwo
		)
		
		/// Create a bitmap representation to draw the images into.
		let offscreenRep = NSBitmapImageRep (bitmapDataPlanes :	nil,
											 pixelsWide :		Int (resultSize.width),
											 pixelsHigh :		Int (resultSize.height),
											 bitsPerSample :	8,
											 samplesPerPixel :	4,
											 hasAlpha :			true,
											 isPlanar :			false,
											 colorSpaceName :	.deviceRGB,
											 bytesPerRow :		0,
											 bitsPerPixel :		0)
		
		guard let rep = offscreenRep else {
			return nil
		}
		
		/// Set the current graphics context to our bitmap representation.
		NSGraphicsContext.saveGraphicsState ()
		NSGraphicsContext.current = NSGraphicsContext (bitmapImageRep :	rep)
		
		let context = NSGraphicsContext.current?.cgContext
		context?.clear(CGRect(origin: .zero, size: resultSize))
		
		/// Draw each image into its calculated frame.
		for frame in frames {
			let workImage = autocrop ? frame.item.croppedImage : frame.item.image
			workImage.draw (in :		frame.drawRect,
							from :		.zero,
							operation : .sourceOver,
							fraction :	1.0)
		}
		
		NSGraphicsContext.restoreGraphicsState ()
		
		/// Convert the bitmap representation to CGImage.
		guard let cgImage = rep.cgImage else {
			return nil
		}
		
		let uti: UTType
		switch exportFormat {
		case .png: uti = .png
		case .jpeg: uti = .jpeg
		case .webp: uti = UTType("com.google.webp") ?? .png
		case .tiff: uti = .tiff
		}
		
		guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, uti.identifier as CFString, 1, nil) else {
			return nil
		}
		
		let options: [CFString: Any]
		if exportFormat == .jpeg || exportFormat == .webp {
			options = [kCGImageDestinationLossyCompressionQuality: exportQuality]
		} else {
			options = [:]
		}
		
		CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
		guard CGImageDestinationFinalize(destination) else {
			return nil
		}
		
		// If exportMetadata is true, generate and write JSON metadata
		if exportMetadata {
			let metadataURL = outputURL.deletingPathExtension().appendingPathExtension("json")
			
			let jsonFrames = frames.map { frame -> [String: Any] in
				let filename = frame.item.url.lastPathComponent
				let sourceSize = autocrop ? frame.item.croppedImage.size : frame.item.image.size
				let jsonY = resultSize.height - (frame.drawRect.origin.y + frame.drawRect.height)
				
				return [
					"filename": filename,
					"frame": [
						"x": Int(frame.drawRect.origin.x),
						"y": Int(jsonY),
						"w": Int(frame.drawRect.width),
						"h": Int(frame.drawRect.height)
					],
					"sourceSize": [
						"w": Int(sourceSize.width),
						"h": Int(sourceSize.height)
					]
				]
			}
			
			let metadataDict: [String: Any] = [
				"meta": [
					"app": "ImaJoin",
					"image": outputURL.lastPathComponent,
					"size": [
						"w": Int(resultSize.width),
						"h": Int(resultSize.height)
					]
				],
				"frames": jsonFrames
			]
			
			if let jsonData = try? JSONSerialization.data(withJSONObject: metadataDict, options: [.prettyPrinted, .sortedKeys]) {
				try? jsonData.write(to: metadataURL)
			}
		}
		
		return outputURL
	}
	
	/// Calculates the resulting size of the joined images.
	public static func calculateResultSize (
		items: [IJImageItem],
		mode: IJJoinMode,
		spacing: Double,
		autocrop: Bool = false,
		gridRows: Int = 2,
		gridCols: Int = 2,
		gridPriority: IJGridPriority = .columns,
		sizingMode: IJSizingMode = .original,
		scalingMode: IJScalingMode = .fit,
		customWidth: Double = 128,
		customHeight: Double = 128,
		horizontalAlignment: IJHorizontalAlignment = .center,
		verticalAlignment: IJVerticalAlignment = .center,
		powerOfTwo: Bool = false
	) -> NSSize {
		let (size, _) = calculateLayout(
			items: items,
			mode: mode,
			spacing: spacing,
			autocrop: autocrop,
			gridRows: gridRows,
			gridCols: gridCols,
			gridPriority: gridPriority,
			sizingMode: sizingMode,
			scalingMode: scalingMode,
			customWidth: customWidth,
			customHeight: customHeight,
			horizontalAlignment: horizontalAlignment,
			verticalAlignment: verticalAlignment,
			powerOfTwo: powerOfTwo
		)
		return size
	}
	
	/// Finds the minimum containment rectangle where there are non-transparent pixels,
	/// crops the image to that bounding box, and returns the cropped image.
	/// If the image is completely transparent, returns the original image.
	public static func autocrop (_ image : NSImage) -> NSImage {
		guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
			return image
		}
		
		let width = cgImage.width
		let height = cgImage.height
		
		guard let context = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: width,
			space: CGColorSpaceCreateDeviceGray(),
			bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
		) else {
			return image
		}
		
		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
		
		guard let data = context.data else {
			return image
		}
		
		let pixelBuffer = data.assumingMemoryBound(to: UInt8.self)
		
		var minX = width
		var maxX = -1
		var minY = height
		var maxY = -1
		
		for y in 0..<height {
			let rowOffset = y * width
			for x in 0..<width {
				let alpha = pixelBuffer[rowOffset + x]
				if alpha > 0 {
					if x < minX { minX = x }
					if x > maxX { maxX = x }
					if y < minY { minY = y }
					if y > maxY { maxY = y }
				}
			}
		}
		
		// If the image is completely transparent, return the original image.
		if maxX < 0 || maxY < 0 {
			return image
		}
		
		let cropRect = CGRect(
			x: minX,
			y: minY,
			width: maxX - minX + 1,
			height: maxY - minY + 1
		)
		
		guard let croppedCG = cgImage.cropping(to: cropRect) else {
			return image
		}
		
		// Preserve original backing scale
		let scaleX = image.size.width / CGFloat(width)
		let scaleY = image.size.height / CGFloat(height)
		let croppedSize = NSSize(
			width: CGFloat(croppedCG.width) * scaleX,
			height: CGFloat(croppedCG.height) * scaleY
		)
		
		return NSImage(cgImage: croppedCG, size: croppedSize)
	}
}
