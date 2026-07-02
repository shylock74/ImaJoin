import Foundation
import SwiftUI
import AppKit
import Combine

/// IJImageJoinerViewModel manages the state and actions for joining images.
/// It observes the selected join mode and handles the processing of dropped files.
@Observable
public class IJImageJoinerViewModel {
	/// The current join mode selected by the user.
	public var joinMode :	IJJoinMode = .horizontal
	
	/// A flag indicating if an operation is currently in progress.
	public var isProcessing :	Bool = false
	
	/// The list of items currently being processed or previewed.
	public var processedItems :	[ IJImageItem ] = []
	
	/// A flag to control the visibility of the preview window.
	public var showPreview :	Bool = false
	
	/// The URL of the last saved image, if any.
	public var lastSavedURL :	URL?
	
	/// The spacing between joined images in pixels.
	public var spacing :	Double = 0
	
	/// The calculated final resolution of the joined image.
	public var finalResolution :	NSSize {
		return IJImageJoiner.calculateResultSize (items :	processedItems,
												  mode :	joinMode,
												  spacing :	spacing)
	}
	
	/// Default public initializer.
	public init () {}
	
	/// Processes the dropped file URLs and joins the images.
	/// - Parameter urls: The list of URLs representing the dropped image files.
	public func handleDroppedFiles (urls :	[URL]) {
		self.isProcessing = true
		self.lastSavedURL = nil
		
		/// Perform image loading on a background thread to keep the UI responsive.
		DispatchQueue.global (qos :	.userInitiated).async (execute : {
			/// Load images from the provided URLs.
			var items :	[IJImageItem] = []
			for url in urls {
				if let image = NSImage (contentsOf :	url) {
					items.append (IJImageItem (url :	url,
											   image :	image))
				}
			}
			
			/// Sort items alphabetically by filename.
			let sortedItems = items.sorted (by : { (item1,
													item2) in
				return item1.url.lastPathComponent.localizedStandardCompare (item2.url.lastPathComponent) == .orderedAscending
			})
			
			/// Update the UI on the main thread.
			DispatchQueue.main.async (execute : {
				self.processedItems = sortedItems
				self.isProcessing = false
			})
		})
	}
	
	/// Joins and saves the loaded images.
	public func joinAndSave () {
		guard !processedItems.isEmpty else { return }
		self.isProcessing = true
		
		DispatchQueue.global (qos :	.userInitiated).async (execute : {
			let savedURL = IJImageJoiner.joinAndSave (items :	self.processedItems,
													  mode :	self.joinMode,
													  spacing :	self.spacing)
			
			DispatchQueue.main.async (execute : {
				self.lastSavedURL = savedURL
				self.isProcessing = false
			})
		})
	}
}
