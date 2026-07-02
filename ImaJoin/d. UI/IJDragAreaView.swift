import SwiftUI
import UniformTypeIdentifiers
import UMUIControls

/// IJDragAreaView provides a visual area where users can drop image files.
/// It handles the drag-and-drop interaction and notifies the parent when files are dropped.
public struct IJDragAreaView :	View {
	/// The closure to call when files are dropped.
	public var onFilesDropped :	([URL]) -> Void
	
	/// Internal state to track if a drag operation is currently over the view.
	@State private var isTargeted :	Bool = false
	
	/// Public initializer.
	/// - Parameter onFilesDropped: A closure that receives the dropped URLs.
	public init (onFilesDropped :	@escaping ([URL]) -> Void) {
		self.onFilesDropped = onFilesDropped
	}
	
	/// The body of the view.
	public var body :	some View {
		ZStack {
			RoundedRectangle (cornerRadius :	12)
				.strokeBorder (style :	StrokeStyle (lineWidth :	2,
													 dash :			[ 10 ]))
				.foregroundColor (isTargeted ? .accentColor : .secondary)
				.background (RoundedRectangle (cornerRadius :	12)
					.fill (isTargeted ? Color.accentColor.opacity (0.1) : Color.clear))
			
			VStack (spacing : 0) {
				Image (systemName :	"photo.on.rectangle.angled")
					.font (.system (size :	48))
					.foregroundColor (isTargeted ? .accentColor : .secondary)
				
				UMUIVSpacer (12)
				
				Text ("Drag images here")
					.font (.headline)
					.foregroundColor (isTargeted ? .accentColor : .secondary)
				
				UMUIVSpacer (4)
				
				UMUICaptionGrayText ("PNG, JPEG, HEIC supported")
			}
		}
		.frame (minWidth :	300,
				minHeight :	200)
		.onDrop (of :			[ .fileURL ],
				 isTargeted :	$isTargeted,
				 perform :		{ providers in
			/// Extract URLs from the dropped providers.
			let group = DispatchGroup ()
			var urls :	[ URL ] = []
			
			for provider in providers {
				group.enter ()
				_ = provider.loadObject (ofClass :	URL.self,
										 completionHandler :	{ url,
																  _ in
					if let url = url {
						urls.append (url)
					}
					group.leave ()
				})
			}
			
			group.notify (queue :	.main,
						  execute :	{
				if !urls.isEmpty {
					self.onFilesDropped (urls)
				}
			})
			return true
		})
	}
}
