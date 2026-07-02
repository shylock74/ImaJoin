import SwiftUI

/// ImaJoinApp is the entry point of the macOS application.
/// It sets up the main window and the root view.
@main
struct ImaJoinApp :	App {
	/// The shared view model for the application.
	@State private var viewModel = IJImageJoinerViewModel ()
	
	/// The body of the application scene.
	var body :	some Scene {
		WindowGroup {
			IJMainView ()
				.environment (viewModel)
		}
		.windowResizability (.contentSize)
		
		WindowGroup ("Preview", id :	"preview") {
			IJPreviewView ()
				.environment (viewModel)
		}
	}
}
