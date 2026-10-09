import SwiftUI
import UniformTypeIdentifiers
import UMUIControls

/// IJMainView is the root view of the application.
/// It provides a dual-pane interface: a sidebar for listing and managing loaded images,
/// and a detail pane for configuring layout, sizing, and export settings.
public struct IJMainView :	View {
	/// The view model that handles the business logic.
	@Environment (IJImageJoinerViewModel.self) private var viewModel
	
	/// State to track if drag-over is targeting the sidebar.
	@State private var isSidebarTargeted :	Bool = false
	
	/// Public initializer.
	public init () {}
	
	/// Triggers file selection panel for loading images.
	private func selectFiles() {
		let panel = NSOpenPanel()
		panel.title = "Select Images to Join"
		panel.allowsMultipleSelection = true
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowedContentTypes = [.image]
		
		panel.begin { response in
			if response == .OK {
				viewModel.handleDroppedFiles(urls: panel.urls)
			}
		}
	}
	
	/// The body of the view.
	public var body :	some View {
		@Bindable var viewModel = viewModel
		@Environment (\.openWindow) var openWindow
		
		// Segmented Bar Bindings
		let joinModeBinding = Binding<String>(
			get: { viewModel.joinMode.rawValue },
			set: { viewModel.joinMode = IJJoinMode(rawValue: $0) ?? .horizontal }
		)
		
		let gridPriorityBinding = Binding<String>(
			get: { viewModel.gridPriority.rawValue },
			set: { viewModel.gridPriority = IJGridPriority(rawValue: $0) ?? .columns }
		)

		let sizingModeBinding = Binding<String>(
			get: { viewModel.sizingMode.rawValue },
			set: { viewModel.sizingMode = IJSizingMode(rawValue: $0) ?? .original }
		)

		let scalingModeBinding = Binding<String>(
			get: { viewModel.scalingMode.rawValue },
			set: { viewModel.scalingMode = IJScalingMode(rawValue: $0) ?? .fit }
		)

		let hAlignBinding = Binding<String>(
			get: { viewModel.horizontalAlignment.rawValue },
			set: { viewModel.horizontalAlignment = IJHorizontalAlignment(rawValue: $0) ?? .center }
		)

		let vAlignBinding = Binding<String>(
			get: { viewModel.verticalAlignment.rawValue },
			set: { viewModel.verticalAlignment = IJVerticalAlignment(rawValue: $0) ?? .center }
		)

		let exportFormatBinding = Binding<String>(
			get: { viewModel.exportFormat.rawValue },
			set: { viewModel.exportFormat = IJExportFormat(rawValue: $0) ?? .png }
		)
		
		HStack (spacing : 0) {
			// --- LEFT SIDEBAR: LOADED IMAGES ---
			VStack (spacing : 0) {
				// Sidebar Header
				HStack {
					Text ("Images")
						.font (.headline)
					
					if !viewModel.processedItems.isEmpty {
						Text ("(\(viewModel.processedItems.count))")
							.font (.subheadline)
							.foregroundColor (.secondary)
					}
					
					Spacer ()
					
					// Toolbar Buttons
					Button (action: selectFiles) {
						Image (systemName: "plus")
					}
					.buttonStyle (.plain)
					.help ("Add Images...")
					
					if !viewModel.processedItems.isEmpty {
						Button (action: { viewModel.sortAlphabetically() }) {
							Image (systemName: "arrow.up.arrow.down.square")
						}
						.buttonStyle (.plain)
						.help ("Sort Alphabetically")
						
						Button (action: { viewModel.clearItems() }) {
							Image (systemName: "trash")
								.foregroundColor (.red)
						}
						.buttonStyle (.plain)
						.help ("Clear All")
					}
				}
				.padding ()
				.background (Color (nsColor: .windowBackgroundColor))
				
				Divider ()
				
				// List or Drop Placeholder
				if viewModel.processedItems.isEmpty {
					VStack {
						Spacer ()
						IJDragAreaView (onFilesDropped :	{ urls in
							viewModel.handleDroppedFiles (urls :	urls)
						})
						.padding ()
						Spacer ()
					}
				} else {
					List {
						ForEach (viewModel.processedItems) { item in
							HStack (spacing: 8) {
								Image (nsImage :	item.image)
									.resizable ()
									.aspectRatio (contentMode :	.fit)
									.frame (width :	36,
											height :	36)
									.cornerRadius (4)
									.background (Color.black.opacity (0.1))
								
								VStack (alignment :	.leading,
										spacing :	2) {
									Text (item.url.lastPathComponent)
										.font (.subheadline)
										.fontWeight (.medium)
										.lineLimit (1)
									
									Text ("\(Int (item.image.size.width)) × \(Int (item.image.size.height)) px")
										.font (.caption)
										.foregroundColor (.secondary)
								}
								
								Spacer ()
								
								Button (action: { viewModel.removeItem (item) }) {
									Image (systemName :	"multiply.circle.fill")
										.foregroundColor (.secondary)
								}
								.buttonStyle (.plain)
							}
							.padding (.vertical, 2)
						}
						.onMove (perform: viewModel.moveItems)
					}
					.listStyle (.sidebar)
				}
			}
			.frame (width :	320)
			.background (isSidebarTargeted ? Color.accentColor.opacity(0.05) : Color (nsColor: .controlBackgroundColor))
			.onDrop (of: [.fileURL], isTargeted: $isSidebarTargeted) { providers in
				let group = DispatchGroup()
				var urls: [URL] = []
				for provider in providers {
					group.enter()
					_ = provider.loadObject(ofClass: URL.self) { url, _ in
						if let url = url {
							urls.append(url)
						}
						group.leave()
					}
				}
				group.notify(queue: .main) {
					if !urls.isEmpty {
						viewModel.handleDroppedFiles(urls: urls)
					}
				}
				return true
			}
			
			Divider ()
			
			// --- RIGHT DETAIL PANE: SETTINGS & ACTIONS ---
			ScrollView {
				VStack (spacing : 20) {
					// Title
					HStack {
						VStack (alignment: .leading, spacing: 4) {
							Text ("ImaJoin")
								.font (.title)
								.fontWeight (.bold)
							Text ("Configure your image composition")
								.font (.subheadline)
								.foregroundColor (.secondary)
						}
						Spacer ()
					}
					.padding (.bottom, 10)
					
					// 1. Layout Settings
					UMUISection ("Layout Settings") {
						VStack (spacing: 12) {
							UMUISegmentedBar (label: "Join Mode", options: ["Horizontal", "Vertical", "Grid"], selection: joinModeBinding, labelWidth: 90)
							
							if viewModel.joinMode == .grid {
								UMUINumberControl (title: "Rows", value: $viewModel.gridRows, range: 1...100, unit: "", decimals: 0, labelWidth: 90, fieldWidth: 60)
								UMUINumberControl (title: "Columns", value: $viewModel.gridCols, range: 1...100, unit: "", decimals: 0, labelWidth: 90, fieldWidth: 60)
								UMUISegmentedBar (label: "Priority", options: ["Columns", "Rows", "None"], selection: gridPriorityBinding, labelWidth: 90)
								
								UMUISegmentedBar (label: "H Align", options: ["Left", "Center", "Right"], selection: hAlignBinding, labelWidth: 90)
								UMUISegmentedBar (label: "V Align", options: ["Top", "Center", "Bottom"], selection: vAlignBinding, labelWidth: 90)
							} else if viewModel.joinMode == .horizontal {
								UMUISegmentedBar (label: "V Align", options: ["Top", "Center", "Bottom"], selection: vAlignBinding, labelWidth: 90)
							} else if viewModel.joinMode == .vertical {
								UMUISegmentedBar (label: "H Align", options: ["Left", "Center", "Right"], selection: hAlignBinding, labelWidth: 90)
							}
							
							UMUINumberControl (title: "Spacing", value: $viewModel.spacing, range: -500...500, unit: "px", decimals: 0, labelWidth: 90, fieldWidth: 60)
							
							HStack {
								Spacer ()
									.frame (width :	90)
								UMUISmallSwitch ("Autocrop margins", isOn :	$viewModel.autocrop, size :	.small)
								Spacer ()
							}
						}
					}
					
					// 2. Sizing & Scaling Settings
					UMUISection ("Sizing & Scaling") {
						VStack (spacing: 12) {
							UMUISegmentedBar (label: "Sizing", options: ["Original Size", "Uniform to Max", "Uniform to Min", "Custom Size"], selection: sizingModeBinding, labelWidth: 90)
							
							if viewModel.sizingMode == .custom {
								UMUINumberControl (title: "Width", value: $viewModel.customWidth, range: 1...4096, unit: "px", decimals: 0, labelWidth: 90, fieldWidth: 60)
								UMUINumberControl (title: "Height", value: $viewModel.customHeight, range: 1...4096, unit: "px", decimals: 0, labelWidth: 90, fieldWidth: 60)
							}
							
							if viewModel.sizingMode != .original {
								UMUISegmentedBar (label: "Scaling", options: ["Fit", "Stretch"], selection: scalingModeBinding, labelWidth: 90)
							}
						}
					}
					
					// 3. Export Settings
					UMUISection ("Export Settings") {
						VStack (spacing: 12) {
							UMUISegmentedBar (label: "Format", options: ["PNG", "JPEG", "WebP", "TIFF"], selection: exportFormatBinding, labelWidth: 90)
							
							if viewModel.exportFormat == .jpeg || viewModel.exportFormat == .webp {
								UMUINumberControl (title: "Quality", value: $viewModel.exportQuality, range: 0...1, isPercentage: true, decimals: 0, labelWidth: 90, fieldWidth: 60)
							}
							
							HStack {
								Spacer ()
									.frame (width: 90)
								VStack (alignment: .leading, spacing: 8) {
									UMUISmallSwitch ("Power of Two canvas size", isOn: $viewModel.powerOfTwo, size: .small)
									UMUISmallSwitch ("Export coordinates metadata (JSON)", isOn: $viewModel.exportMetadata, size: .small)
								}
								Spacer ()
							}
						}
					}
					
					// 4. Actions
					UMUISection ("Actions") {
						if viewModel.isProcessing {
							ProgressView ("Processing...")
								.padding ()
						} else {
							VStack (spacing :	16) {
								if let url = viewModel.lastSavedURL {
									VStack (spacing :	4) {
										Text ("Saved successfully!")
											.foregroundColor (.green)
											.font (.subheadline)
											.fontWeight (.semibold)
										
										UMUICapsuleButton ("Show in Finder", style: .gray) {
											NSWorkspace.shared.activateFileViewerSelecting ([ url ])
										}
									}
								}
								
								HStack (spacing :	12) {
									UMUICapsuleButton ("Join and Save...", style: .accent) {
										viewModel.joinAndSave ()
									}
									.disabled (viewModel.processedItems.isEmpty)
									
									UMUICapsuleButton ("Open Preview", style: .gray) {
										openWindow (id :	"preview")
									}
									.disabled (viewModel.processedItems.isEmpty)
								}
							}
						}
					}
					
					Spacer ()
					
					if !viewModel.processedItems.isEmpty {
						Text ("Estimated Output Size: \(Int (viewModel.finalResolution.width)) x \(Int (viewModel.finalResolution.height)) px")
							.font (.caption)
							.foregroundColor (.secondary)
					}
				}
				.padding ()
			}
			.frame (maxWidth :	.infinity)
		}
		.frame (minWidth :	880,
				minHeight :	620)
	}
}
