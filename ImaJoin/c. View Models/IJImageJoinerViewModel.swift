import Foundation
import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

/// IJImageJoinerViewModel manages the state and actions for joining images.
/// It observes the selected join mode and handles the processing of dropped files.
@Observable
public class IJImageJoinerViewModel {
	/// The current join mode selected by the user.
	public var joinMode :	IJJoinMode = .horizontal
	
	/// The number of rows for grid mode.
	public var gridRows :	Double = 2
	
	/// The number of columns for grid mode.
	public var gridCols :	Double = 2
	
	/// The grid priority overflow behavior.
	public var gridPriority :	IJGridPriority = .columns
	
	/// A flag indicating if autocrop is enabled.
	public var autocrop :	Bool = false
	
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
	
	// --- New Advanced Settings ---
	
	/// Sizing mode for items (Original, Match Max, Match Min, Custom).
	public var sizingMode: IJSizingMode = .original
	
	/// Scaling mode inside the target cells (Fit, Stretch).
	public var scalingMode: IJScalingMode = .fit
	
	/// Custom width for scaling.
	public var customWidth: Double = 128
	
	/// Custom height for scaling.
	public var customHeight: Double = 128
	
	/// Horizontal alignment for cells/images.
	public var horizontalAlignment: IJHorizontalAlignment = .center
	
	/// Vertical alignment for cells/images.
	public var verticalAlignment: IJVerticalAlignment = .center
	
	/// Force final canvas to power of 2 size.
	public var powerOfTwo: Bool = false
	
	/// Export JSON metadata file mapping coordinates.
	public var exportMetadata: Bool = false
	
	/// Format of the exported image.
	public var exportFormat: IJExportFormat = .png
	
	/// Quality of the exported JPEG/WebP image (0.0 to 1.0).
	public var exportQuality: Double = 0.8
	
	/// The calculated final resolution of the joined image.
	public var finalResolution :	NSSize {
		return IJImageJoiner.calculateResultSize (items :	processedItems,
												  mode :	joinMode,
												  spacing :	spacing,
												  autocrop :	autocrop,
												  gridRows :	Int (gridRows),
												  gridCols :	Int (gridCols),
												  gridPriority: gridPriority,
												  sizingMode: sizingMode,
												  scalingMode: scalingMode,
												  customWidth: customWidth,
												  customHeight: customHeight,
												  horizontalAlignment: horizontalAlignment,
												  verticalAlignment: verticalAlignment,
												  powerOfTwo: powerOfTwo)
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
				if self.processedItems.isEmpty {
					self.processedItems = sortedItems
				} else {
					self.processedItems.append(contentsOf: items)
				}
				self.isProcessing = false
			})
		})
	}
	
	// --- List Editing and Sorting Methods ---
	
	public func removeItem(atOffsets offsets: IndexSet) {
		processedItems.remove(atOffsets: offsets)
		lastSavedURL = nil
	}
	
	public func removeItem(_ item: IJImageItem) {
		processedItems.removeAll(where: { $0.id == item.id })
		lastSavedURL = nil
	}
	
	public func moveItems(fromOffsets source: IndexSet, toOffset destination: Int) {
		processedItems.move(fromOffsets: source, toOffset: destination)
		lastSavedURL = nil
	}
	
	public func clearItems() {
		processedItems.removeAll()
		lastSavedURL = nil
	}
	
	public func sortAlphabetically() {
		processedItems.sort(by: { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending })
		lastSavedURL = nil
	}
	
	/// Opens a save panel on the main thread and saves the joined images.
	public func joinAndSave () {
		guard !processedItems.isEmpty else { return }
		
		let panel = NSSavePanel()
		panel.title = "Save Joined Image"
		panel.prompt = "Save"
		
		let firstURL = processedItems[0].url
		let defaultName = firstURL.deletingPathExtension().lastPathComponent + "_join"
		panel.nameFieldStringValue = defaultName
		
		let uti: UTType
		switch exportFormat {
		case .png: uti = .png
		case .jpeg: uti = .jpeg
		case .webp: uti = UTType("com.google.webp") ?? .png
		case .tiff: uti = .tiff
		}
		panel.allowedContentTypes = [uti]
		
		panel.begin { response in
			if response == .OK, let saveURL = panel.url {
				self.isProcessing = true
				
				// Capture all variables needed for background thread execution to avoid data race
				let items = self.processedItems
				let mode = self.joinMode
				let spacing = self.spacing
				let autocrop = self.autocrop
				let gridRows = Int(self.gridRows)
				let gridCols = Int(self.gridCols)
				let gridPriority = self.gridPriority
				let sizingMode = self.sizingMode
				let scalingMode = self.scalingMode
				let customWidth = self.customWidth
				let customHeight = self.customHeight
				let horizontalAlignment = self.horizontalAlignment
				let verticalAlignment = self.verticalAlignment
				let powerOfTwo = self.powerOfTwo
				let exportMetadata = self.exportMetadata
				let exportFormat = self.exportFormat
				let exportQuality = self.exportQuality
				
				DispatchQueue.global(qos: .userInitiated).async {
					let savedURL = IJImageJoiner.joinAndSave(
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
						powerOfTwo: powerOfTwo,
						exportMetadata: exportMetadata,
						exportFormat: exportFormat,
						exportQuality: exportQuality,
						outputURL: saveURL
					)
					
					DispatchQueue.main.async {
						self.lastSavedURL = savedURL
						self.isProcessing = false
					}
				}
			}
		}
	}
}
