import SwiftUI
import UMUIControls

/// IJMainView is the root view of the application.
/// It provides the user interface for selecting the join mode and dropping images.
public struct IJMainView :	View {
	/// The view model that handles the business logic.
	@Environment (IJImageJoinerViewModel.self) private var viewModel
	
	/// Public initializer.
	public init () {}
	
	/// The body of the view.
	public var body :	some View {
		@Bindable var viewModel = viewModel
		@Environment (\.openWindow) var openWindow
		
		let joinModeBinding = Binding<String>(
			get: { viewModel.joinMode == .horizontal ? "Horizontal" : "Vertical" },
			set: { viewModel.joinMode = $0 == "Horizontal" ? .horizontal : .vertical }
		)
		
		VStack (spacing : 0) {
			Text ("ImaJoin")
				.font (.largeTitle)
				.fontWeight (.bold)
			
			UMUIVSpacer (20)
			
			UMUISection ("Settings") {
				VStack (spacing: 12) {
					UMUISegmentedBar (label: "Join Mode", options: ["Horizontal", "Vertical"], selection: joinModeBinding, labelWidth: 80)
					UMUINumberControl (title: "Padding", value: $viewModel.spacing, range: -500...500, unit: "px", decimals: 0, labelWidth: 80, fieldWidth: 60)
				}
			}
			
			UMUIVSpacer (20)
			
			UMUISection ("Input") {
				IJDragAreaView (onFilesDropped :	{ urls in
					viewModel.handleDroppedFiles (urls :	urls)
				})
			}
			
			UMUIVSpacer (20)
			
			UMUISection ("Actions") {
				if viewModel.isProcessing {
					ProgressView ("Processing...")
						.padding ()
				} else {
					VStack (spacing :	16) {
						if let url = viewModel.lastSavedURL {
							VStack (spacing :	4) {
								Text ("Image saved successfully!")
									.foregroundColor (.green)
									.font (.subheadline)
								
								UMUICapsuleButton ("Show in Finder", style: .gray) {
									NSWorkspace.shared.activateFileViewerSelecting ([ url ])
								}
							}
						}
						
						HStack (spacing :	12) {
							UMUICapsuleButton ("Join and Save", style: .accent) {
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
				Text ("Final Resolution: \(Int (viewModel.finalResolution.width)) x \(Int (viewModel.finalResolution.height)) px")
					.font (.caption)
					.foregroundColor (.secondary)
			}
		}
		.frame (minWidth :	400,
				minHeight :	550)
		.padding ()
	}
}
