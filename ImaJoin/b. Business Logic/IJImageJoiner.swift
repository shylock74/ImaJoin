import Foundation
import AppKit

/// IJJoinMode defines the orientation for joining images.
/// It is used to specify whether images should be laid out horizontally, vertically, or in a grid.
public enum IJJoinMode: String, CaseIterable {
	/// Images are placed side-by-side.
	case horizontal = "Horizontal"
	/// Images are placed top-to-bottom.
	case vertical = "Vertical"
	/// Images are placed in a grid.
	case grid = "Grid"
}

/// IJGridPriority defines how the grid layout behaves when the number of images exceeds R * C.
public enum IJGridPriority: String, CaseIterable {
	/// Columns count is respected, new rows are added.
	case columns = "Columns"
	/// Rows count is respected, new columns are added.
	case rows = "Rows"
	/// Standard grid dimensions are strictly respected, ignoring excess images.
	case none = "None"
}

/// IJImageJoiner provides static methods to join images and save the result.
/// This class contains the core logic for image processing and file I/O.
public class IJImageJoiner {
	
	/// Joins a list of images according to the specified mode and saves the result as a PNG file.
	/// The images are sorted alphabetically by their filename before being joined.
	/// - Parameter items: The list of IJImageItem objects to join.
	/// - Parameter mode: The join orientation (horizontal or vertical).
	/// - Returns: The URL where the image was saved, or nil if the operation failed.
	public static func joinAndSave (items :	[IJImageItem],
									mode :	IJJoinMode,
									spacing :	Double = 0,
									autocrop :	Bool = false,
									gridRows :  Int = 2,
									gridCols :  Int = 2,
									gridPriority : IJGridPriority = .columns) -> URL? {
		guard !items.isEmpty else {
			return nil
		}
		
		/// Sort items alphabetically by filename to ensure consistent ordering.
		let sortedItems = items.sorted (by : { (item1,
												item2) in
			return item1.url.lastPathComponent.localizedStandardCompare (item2.url.lastPathComponent) == .orderedAscending
		})
		
		let targetItems = autocrop ? sortedItems.map { IJImageItem(url: $0.url, image: $0.croppedImage, croppedImage: $0.croppedImage) } : sortedItems
		
		/// The target size of the resulting image.
		let resultSize = calculateResultSize (items :		targetItems,
											  mode :		mode,
											  spacing :	spacing,
											  gridRows :	gridRows,
											  gridCols :	gridCols,
											  gridPriority: gridPriority)
		
		/// The rectangles where each image will be drawn in the composite image.
		var frames :		[NSRect] = []
		
		if mode == .horizontal {
			let maxHeight = resultSize.height
			var currentX : CGFloat = 0
			for item in targetItems {
				let imageSize = item.image.size
				/// Align centered vertically if the image is shorter than the max height.
				let yOffset = (maxHeight - imageSize.height) / 2
				frames.append (NSRect (x :		currentX,
									   y :		yOffset,
									   width :	imageSize.width,
									   height :	imageSize.height))
				currentX += imageSize.width + CGFloat (spacing)
			}
		} else if mode == .vertical {
			var currentY = resultSize.height
			for item in targetItems {
				let imageSize = item.image.size
				/// Align centered horizontally if the image is narrower than the max width.
				let maxWidth = resultSize.width
				let xOffset = (maxWidth - imageSize.width) / 2
				currentY -= imageSize.height
				frames.append (NSRect (x :		xOffset,
									   y :		currentY,
									   width :	imageSize.width,
									   height :	imageSize.height))
				currentY -= CGFloat (spacing)
			}
		} else {
			let maxW = targetItems.map { $0.image.size.width }.max() ?? 0
			let maxH = targetItems.map { $0.image.size.height }.max() ?? 0
			
			var actualRows = max(1, gridRows)
			var actualCols = max(1, gridCols)
			let count = targetItems.count
			
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
			
			for (index, item) in itemsToDraw.enumerated() {
				let row = index / actualCols
				let col = index % actualCols
				
				// Calculate cell boundaries
				let cellX = CGFloat(col) * maxW + CGFloat(col) * CGFloat(spacing)
				let cellY = resultSize.height - CGFloat(row + 1) * maxH - CGFloat(row) * CGFloat(spacing)
				
				// Center image within cell
				let imageSize = item.image.size
				let xOffset = (maxW - imageSize.width) / 2
				let yOffset = (maxH - imageSize.height) / 2
				
				frames.append(NSRect(x: cellX + xOffset,
									 y: cellY + yOffset,
									 width: imageSize.width,
									 height: imageSize.height))
			}
		}
		
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
		
		/// Draw each image into its calculated frame.
		for index in 0..<frames.count {
			let item = targetItems [index]
			item.image.draw (in :		frames [index],
							 from :		.zero,
							 operation : .sourceOver,
							 fraction :	1.0)
		}
		
		NSGraphicsContext.restoreGraphicsState ()
		
		/// Determine the output location (same folder as the first image).
		let firstURL = sortedItems [0].url
		let folderURL = firstURL.deletingLastPathComponent ()
		let fileName = firstURL.deletingPathExtension ().lastPathComponent
		let outputURL = folderURL.appendingPathComponent ("\(fileName)_join.png")
		
		/// Convert the bitmap representation to PNG data.
		guard let pngData = rep.representation (using :	.png,
												properties : [:]) else {
			return nil
		}
		
		/// Write the data to the disk.
		do {
			try pngData.write (to :	outputURL)
			return outputURL
		} catch {
			print ("Failed to save image: \(error)")
			return nil
		}
	}
	
	/// Calculates the resulting size of the joined images.
	/// - Parameter items: The list of items to join.
	/// - Parameter mode: The join orientation.
	/// - Parameter spacing: The spacing between images.
	/// - Returns: The calculated NSSize.
	public static func calculateResultSize (items :	[IJImageItem],
											mode :		IJJoinMode,
											spacing :	Double,
											autocrop :	Bool = false,
											gridRows :	Int = 2,
											gridCols :	Int = 2,
											gridPriority : IJGridPriority = .columns) -> NSSize {
		guard !items.isEmpty else {
			return .zero
		}
		
		let targetItems = autocrop ? items.map { IJImageItem(url: $0.url, image: $0.croppedImage, croppedImage: $0.croppedImage) } : items
		
		if mode == .horizontal {
			let maxHeight = targetItems.map ({ $0.image.size.height }).max () ?? 0
			let totalImageWidth = targetItems.map ({ $0.image.size.width }).reduce (0, +)
			let totalSpacing = CGFloat (targetItems.count - 1) * CGFloat (spacing)
			let totalWidth = totalImageWidth + totalSpacing
			
			return NSSize (width :	max (1, totalWidth),
						   height :	max (1, maxHeight))
		} else if mode == .vertical {
			let maxWidth = targetItems.map ({ $0.image.size.width }).max () ?? 0
			let totalImageHeight = targetItems.map ({ $0.image.size.height }).reduce (0, +)
			let totalSpacing = CGFloat (targetItems.count - 1) * CGFloat (spacing)
			let totalHeight = totalImageHeight + totalSpacing
			
			return NSSize (width :	max (1, maxWidth),
						   height :	max (1, totalHeight))
		} else {
			let count = targetItems.count
			let maxW = targetItems.map { $0.image.size.width }.max() ?? 0
			let maxH = targetItems.map { $0.image.size.height }.max() ?? 0
			
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
			
			let totalWidth = CGFloat(actualCols) * maxW + CGFloat(max(0, actualCols - 1)) * CGFloat(spacing)
			let totalHeight = CGFloat(actualRows) * maxH + CGFloat(max(0, actualRows - 1)) * CGFloat(spacing)
			
			return NSSize (width :	max (1, totalWidth),
						   height :	max (1, totalHeight))
		}
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
