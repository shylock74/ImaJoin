import Foundation
import AppKit

/// IJImageItem represents a single image item dropped into the app.
/// It contains the original URL and the NSImage representation.
public struct IJImageItem {
	/// The file URL of the image.
	/// Used for alphabetical sorting and determining the output folder.
	public let url :	URL
	
	/// The actual image data.
	public let image :	NSImage
	
	/// Initializes a new image item.
	/// - Parameter url: The file URL of the image.
	/// - Parameter image: The NSImage representation of the image.
	public init (url :		URL,
				 image :	NSImage) {
		self.url = url
		self.image = image
	}
}
