import Foundation
import AppKit

/// IJJoinMode defines the orientation for joining images.
/// It is used to specify whether images should be laid out horizontally or vertically.
public enum IJJoinMode {
	/// Images are placed side-by-side.
	case horizontal
	/// Images are placed top-to-bottom.
	case vertical
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
									spacing :	Double = 0) -> URL? {
		guard !items.isEmpty else {
			return nil
		}
		
		/// Sort items alphabetically by filename to ensure consistent ordering.
		let sortedItems = items.sorted (by : { (item1,
												item2) in
			return item1.url.lastPathComponent.localizedStandardCompare (item2.url.lastPathComponent) == .orderedAscending
		})
		
		/// The target size of the resulting image.
		let resultSize = calculateResultSize (items :		sortedItems,
											  mode :		mode,
											  spacing :	spacing)
		
		/// The rectangles where each image will be drawn in the composite image.
		var frames :		[NSRect] = []
		
		if mode == .horizontal {
			let maxHeight = resultSize.height
			var currentX : CGFloat = 0
			for item in sortedItems {
				let imageSize = item.image.size
				/// Align centered vertically if the image is shorter than the max height.
				let yOffset = (maxHeight - imageSize.height) / 2
				frames.append (NSRect (x :		currentX,
									   y :		yOffset,
									   width :	imageSize.width,
									   height :	imageSize.height))
				currentX += imageSize.width + CGFloat (spacing)
			}
		} else {
			var currentY = resultSize.height
			for item in sortedItems {
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
		for (index,
			 item) in sortedItems.enumerated () {
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
											spacing :	Double) -> NSSize {
		guard !items.isEmpty else {
			return .zero
		}
		
		if mode == .horizontal {
			let maxHeight = items.map ({ $0.image.size.height }).max () ?? 0
			let totalImageWidth = items.map ({ $0.image.size.width }).reduce (0, +)
			let totalSpacing = CGFloat (items.count - 1) * CGFloat (spacing)
			let totalWidth = totalImageWidth + totalSpacing
			
			return NSSize (width :	max (1, totalWidth),
						   height :	max (1, maxHeight))
		} else {
			let maxWidth = items.map ({ $0.image.size.width }).max () ?? 0
			let totalImageHeight = items.map ({ $0.image.size.height }).reduce (0, +)
			let totalSpacing = CGFloat (items.count - 1) * CGFloat (spacing)
			let totalHeight = totalImageHeight + totalSpacing
			
			return NSSize (width :	max (1, maxWidth),
						   height :	max (1, totalHeight))
		}
	}
}
