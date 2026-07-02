import SwiftUI
import UMUIControls

/// Preference key to track ScrollView's visible rect
private struct ScrollOffsetPreferenceKey: PreferenceKey {
	static var defaultValue: CGRect = .zero
	static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
		value = nextValue()
	}
}

/// IJBackgroundType defines the possible background styles for the preview.
public enum IJBackgroundType: String, CaseIterable {
	case checkerboard = "Checkerboard"
	case white = "White"
	case black = "Black"
}

/// IJPreviewView provides a zoomable and draggable preview of the joined images.
/// It uses SwiftUI layouts to mimic the final joined result.
public struct IJPreviewView :	View {
	/// The shared view model.
	@Environment (IJImageJoinerViewModel.self) private var viewModel
	
	/// State for background selection.
	@State private var backgroundType :	IJBackgroundType = .checkerboard
	
	/// State for zoom and pan gestures.
	@State private var zoomScale :		CGFloat = 1.0
	@State private var currentMagnification :	CGFloat = 1.0
	
	@State private var visibleRect :	CGRect = .zero
	@State private var contentSize :	CGSize = .zero
	
	/// Public initializer.
	public init () {}
	
	private var totalScale: CGFloat {
		max(0.01, zoomScale * currentMagnification)
	}
	
	/// The body of the view.
	public var body :	some View {
		@Bindable var viewModel = viewModel
		
		let bgBinding = Binding<String>(
			get: { backgroundType.rawValue },
			set: { backgroundType = IJBackgroundType(rawValue: $0) ?? .checkerboard }
		)
		
		let joinModeBinding = Binding<String>(
			get: {
				switch viewModel.joinMode {
				case .horizontal: return "Horizontal"
				case .vertical: return "Vertical"
				case .grid: return "Grid"
				}
			},
			set: {
				switch $0 {
				case "Horizontal": viewModel.joinMode = .horizontal
				case "Vertical": viewModel.joinMode = .vertical
				case "Grid": viewModel.joinMode = .grid
				default: viewModel.joinMode = .horizontal
				}
			}
		)
		
		let gridPriorityBinding = Binding<String>(
			get: {
				switch viewModel.gridPriority {
				case .columns: return "Columns"
				case .rows: return "Rows"
				case .none: return "None"
				}
			},
			set: {
				switch $0 {
				case "Columns": viewModel.gridPriority = .columns
				case "Rows": viewModel.gridPriority = .rows
				case "None": viewModel.gridPriority = .none
				default: viewModel.gridPriority = .columns
				}
			}
		)
		
		VStack (spacing :	0) {
			/// Header with controls.
			HStack {
				Text ("Preview")
					.font (.headline)
				
				Spacer ()
				
				UMUISegmentedBar (options: IJBackgroundType.allCases.map { $0.rawValue }, selection: bgBinding, labelWidth: 0)
					.frame (width: 250)
				
				UMUIHSpacer (20)
				
				UMUICapsuleButton ("Zoom In", style: .gray) { zoomScale *= 1.2 }
				UMUICapsuleButton ("Zoom Out", style: .gray) { zoomScale /= 1.2 }
				UMUICapsuleButton ("Zoom Fit", style: .accent) { zoomToFit() }
			}
			.padding ()
			.background (.thinMaterial)
			.zIndex (1)
			
			/// Preview area.
			HStack (spacing: 0) {
				GeometryReader { mainGeo in
					ScrollView ([.horizontal, .vertical], showsIndicators: true) {
						let scaledWidth = contentSize.width * totalScale
						let scaledHeight = contentSize.height * totalScale
						
						ZStack {
							backgroundView
							
							contentView
								.scaleEffect (totalScale)
						}
						.frame(width: max(mainGeo.size.width, scaledWidth),
							   height: max(mainGeo.size.height, scaledHeight))
						.background(
							GeometryReader { innerGeo in
								Color.clear.preference(
									key: ScrollOffsetPreferenceKey.self,
									value: innerGeo.frame(in: .named("ScrollViewSpace"))
								)
							}
						)
					}
					.coordinateSpace(name: "ScrollViewSpace")
					.onPreferenceChange(ScrollOffsetPreferenceKey.self) { rect in
						visibleRect = CGRect(
							x: -rect.origin.x,
							y: -rect.origin.y,
							width: mainGeo.size.width,
							height: mainGeo.size.height
						)
					}
					.gesture(
						MagnificationGesture()
							.onChanged { value in currentMagnification = value }
							.onEnded { value in
								zoomScale *= value
								currentMagnification = 1.0
							}
					)
					.onAppear {
						contentSize = viewModel.finalResolution
						zoomToFit(in: mainGeo.size)
					}
					.onChange(of: viewModel.finalResolution) { _, newSize in
						contentSize = newSize
					}
					.onChange(of: viewModel.joinMode) { _, _ in
						zoomToFit(in: mainGeo.size)
					}
				}
				
				Divider ()
				
				/// Minimap Panel
				VStack (spacing: 0) {
					Text ("Minimap")
						.font (.headline)
						.padding (.top, 16)
					
					UMUIVSpacer (16)
					
					minimapView
					
					Spacer ()
				}
				.frame (width: 240)
				.background (Color(nsColor: .windowBackgroundColor))
			}
			
			Divider ()
			
			/// Bottom Controls
			VStack (spacing: 12) {
				HStack (spacing: 20) {
					UMUISegmentedBar (label: "Join Mode", options: ["Horizontal", "Vertical", "Grid"], selection: joinModeBinding, labelWidth: 80)
						.frame (width: 250)
					
					UMUISmallSwitch ("Autocrop", isOn :	$viewModel.autocrop, size :	.small)
					
					Spacer ()
					
					VStack (spacing: 4) {
						if !viewModel.processedItems.isEmpty {
							Text ("Final Resolution: \(Int (viewModel.finalResolution.width)) x \(Int (viewModel.finalResolution.height)) px")
								.font (.caption)
								.foregroundColor (.secondary)
						}
						
						UMUICapsuleButton ("Join and Save", style: .accent) {
							viewModel.joinAndSave ()
						}
						.disabled (viewModel.processedItems.isEmpty)
					}
					
					Spacer ()
					
					UMUINumberControl (title: "Padding", value: $viewModel.spacing, range: -500...500, unit: "px", decimals: 0, labelWidth: 80, fieldWidth: 60)
						.frame (width: 280)
				}
				
				if viewModel.joinMode == .grid {
					HStack (spacing: 20) {
						UMUINumberControl (title: "Rows", value: $viewModel.gridRows, range: 1...100, unit: "", decimals: 0, labelWidth: 80, fieldWidth: 60)
							.frame (width: 250)
						
						UMUINumberControl (title: "Columns", value: $viewModel.gridCols, range: 1...100, unit: "", decimals: 0, labelWidth: 80, fieldWidth: 60)
							.frame (width: 250)
						
						Spacer ()
						
						UMUISegmentedBar (label: "Priority", options: ["Columns", "Rows", "None"], selection: gridPriorityBinding, labelWidth: 80)
							.frame (width: 280)
					}
				}
			}
			.padding ()
			.background (Color(nsColor: .windowBackgroundColor))
		}
		.frame (minWidth :	800,
				minHeight :	680)
	}
	
	/// Calculates and sets the initial zoom to fit the entire image.
	private func zoomToFit (in containerSize : CGSize = .zero) {
		let sizeToFit = containerSize == .zero ? visibleRect.size : containerSize
		guard contentSize.width > 0, contentSize.height > 0, sizeToFit.width > 0 else { return }
		
		let padding :	CGFloat = 40
		let availableWidth = max(1, sizeToFit.width - padding)
		let availableHeight = max(1, sizeToFit.height - padding)
		
		let scaleW = availableWidth / contentSize.width
		let scaleH = availableHeight / contentSize.height
		
		zoomScale = min (1.0, min (scaleW, scaleH))
		currentMagnification = 1.0
	}
	
	@ViewBuilder
	private var minimapView: some View {
		GeometryReader { geo in
			let scale = min(geo.size.width / max(1, contentSize.width), geo.size.height / max(1, contentSize.height))
			let minimapWidth = max(1, contentSize.width * scale)
			let minimapHeight = max(1, contentSize.height * scale)
			
			let scaledWidth = contentSize.width * totalScale
			let scaledHeight = contentSize.height * totalScale
			
			let zStackWidth = max(visibleRect.width, scaledWidth)
			let zStackHeight = max(visibleRect.height, scaledHeight)
			
			let imageX = visibleRect.origin.x - (zStackWidth - scaledWidth) / 2
			let imageY = visibleRect.origin.y - (zStackHeight - scaledHeight) / 2
			
			let pctX = scaledWidth > 0 ? imageX / scaledWidth : 0
			let pctY = scaledHeight > 0 ? imageY / scaledHeight : 0
			let pctW = scaledWidth > 0 ? visibleRect.width / scaledWidth : 1
			let pctH = scaledHeight > 0 ? visibleRect.height / scaledHeight : 1
			
			let clX = max(0, min(1, pctX))
			let clY = max(0, min(1, pctY))
			let clRight = max(0, min(1, pctX + pctW))
			let clBottom = max(0, min(1, pctY + pctH))
			
			let rectX = minimapWidth * clX
			let rectY = minimapHeight * clY
			let rectW = minimapWidth * (clRight - clX)
			let rectH = minimapHeight * (clBottom - clY)
			
			ZStack(alignment: .center) {
				backgroundView
					.frame(width: minimapWidth, height: minimapHeight)
					.clipped()
				
				contentView
					.scaleEffect(scale)
					.frame(width: minimapWidth, height: minimapHeight)
					.clipped()
				
				Color.clear
					.frame(width: minimapWidth, height: minimapHeight)
					.overlay(
						Rectangle()
							.stroke(Color.red, lineWidth: 2)
							.frame(width: max(0, rectW), height: max(0, rectH))
							.offset(x: rectX, y: rectY),
						alignment: .topLeading
					)
			}
			.frame(width: geo.size.width, height: geo.size.height, alignment: .center)
		}
		.frame(height: 200)
		.padding(.horizontal)
	}
	
	/// The view representing the selected background.
	@ViewBuilder
	private var backgroundView :	some View {
		switch backgroundType {
		case .white:
			Color.white
		case .black:
			Color.black
		case .checkerboard:
			IJCheckerboardView ()
		}
	}
	
	/// The view containing the images arranged according to the mode.
	@ViewBuilder
	private var contentView :	some View {
		if viewModel.joinMode == .horizontal {
			HStack (alignment :	.center,
					spacing :	CGFloat (viewModel.spacing)) {
				ForEach (viewModel.processedItems,
						 id :	\.url) { item in
					Image (nsImage :	viewModel.autocrop ? item.croppedImage : item.image)
				}
			}
		} else if viewModel.joinMode == .vertical {
			VStack (alignment :	.center,
					spacing :	CGFloat (viewModel.spacing)) {
				ForEach (viewModel.processedItems,
						 id :	\.url) { item in
					Image (nsImage :	viewModel.autocrop ? item.croppedImage : item.image)
				}
			}
		} else if viewModel.joinMode == .grid {
			let maxW = viewModel.processedItems.map { viewModel.autocrop ? $0.croppedImage.size.width : $0.image.size.width }.max() ?? 0
			let maxH = viewModel.processedItems.map { viewModel.autocrop ? $0.croppedImage.size.height : $0.image.size.height }.max() ?? 0
			
			let count = viewModel.processedItems.count
			
			// We can reuse the same layout math to determine rows/cols
			let actualCols: Int = {
				let initialRows = max(1, Int(viewModel.gridRows))
				let initialCols = max(1, Int(viewModel.gridCols))
				if count > initialRows * initialCols {
					switch viewModel.gridPriority {
					case .columns: return initialCols
					case .rows: return max(1, Int(ceil(Double(count) / Double(initialRows))))
					case .none: return initialCols
					}
				}
				return initialCols
			}()
			
			let actualRows: Int = {
				let initialRows = max(1, Int(viewModel.gridRows))
				let initialCols = max(1, Int(viewModel.gridCols))
				if count > initialRows * initialCols {
					switch viewModel.gridPriority {
					case .columns: return max(1, Int(ceil(Double(count) / Double(initialCols))))
					case .rows: return initialRows
					case .none: return initialRows
					}
				}
				return initialRows
			}()
			
			Grid(horizontalSpacing: CGFloat(viewModel.spacing), verticalSpacing: CGFloat(viewModel.spacing)) {
				ForEach(0..<actualRows, id: \.self) { rowIndex in
					GridRow {
						ForEach(0..<actualCols, id: \.self) { colIndex in
							let itemIndex = rowIndex * actualCols + colIndex
							if itemIndex < count {
								let item = viewModel.processedItems[itemIndex]
								Image(nsImage: viewModel.autocrop ? item.croppedImage : item.image)
									.frame(width: maxW, height: maxH, alignment: .center)
							} else {
								Color.clear
									.frame(width: maxW, height: maxH)
							}
						}
					}
				}
			}
		}
	}
}

/// IJCheckerboardView renders a repeated pattern of light and dark squares.
public struct IJCheckerboardView :	View {
	public init () {}
	public var body :	some View {
		UMUICheckerboard (size: .normal)
	}
}
