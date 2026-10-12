import SwiftUI
import MapKit

/// Full-screen map with floating glass controls and a persistent explore sheet.
struct MapContainerView: View {
    @Environment(ChainDatabase.self) private var chainDB
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = ExploreModel()
    @State private var showLegend = false
    @Namespace private var glassNamespace

    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 46

    var body: some View {
        // No rotation: the compass would collide with the floating controls, and
        // north-up is what you want when hunting for dinner.
        Map(position: $model.position, interactionModes: [.pan, .zoom], selection: $model.selectedItem) {
            // Sample data has no real location; skipping the annotation also keeps
            // MapKit from querying location authorization on the main thread.
            if !model.isMock {
                UserAnnotation()
            }

            ForEach(model.displayedResults) { entry in
                let isSelected = model.selectedItem == entry.item
                let assessment = model.assessment(for: entry)
                Annotation(entry.item.name ?? "Restaurant", coordinate: entry.item.location.coordinate, anchor: .bottom) {
                    RatingPin(
                        rating: assessment.rating,
                        style: PlacardStyle(assessment),
                        isSelected: isSelected
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(entry.item.name ?? "Restaurant"), \(assessment.rating.accessibilityLabel)")
                    .accessibilityValue(assessment.isGraded ? assessment.label : "")
                    .accessibilityHint("Shows details")
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
                .tag(entry.item)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            model.cameraChanged(to: context.region)
        }
        .overlay(alignment: .topTrailing) {
            floatingControls
                .padding(.trailing, DS.Spacing.l)
                .padding(.top, DS.Spacing.s)
        }
        .sheet(isPresented: .constant(true)) {
            ExploreSheet(model: model)
                .presentationDetents([.peek, .medium, .large], selection: $model.detent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                .sensoryFeedback(.selection, trigger: model.detent)
        }
        .sensoryFeedback(.selection, trigger: model.selectedItem) { _, new in new != nil }
        .task { await model.start(using: chainDB) }
    }

    // MARK: - Floating controls

    private var floatingControls: some View {
        GlassEffectContainer(spacing: DS.Spacing.m) {
            VStack(alignment: .trailing, spacing: DS.Spacing.m) {
                Button {
                    model.showSettings = true
                } label: {
                    controlIcon("gearshape.fill")
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Settings")

                VStack(spacing: 0) {
                    locationButton
                    Divider().frame(width: controlSize * 0.6)
                    filterMenu
                }
                .glassEffect(.regular.interactive(), in: .capsule)

                if showLegend {
                    MapLegendCard { toggleLegend() }
                        .glassEffect(.regular, in: .rect(cornerRadius: DS.Radius.card))
                        .glassEffectID("legend", in: glassNamespace)
                } else {
                    Button(action: toggleLegend) {
                        controlIcon("questionmark")
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("legend", in: glassNamespace)
                    .accessibilityLabel("Rating guide")
                    .accessibilityHint("Shows what each grade means")
                }
            }
        }
    }

    private var locationButton: some View {
        Button {
            if model.isLocationBlocked {
                model.detent = .medium
            } else {
                model.centerOnUser(reduceMotion: reduceMotion)
            }
        } label: {
            controlIcon(model.isLocationBlocked ? "location.slash" : "location.fill")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show my location")
        .accessibilityHint(model.isLocationBlocked ? "Location access is off" : "Centers the map on you")
    }

    private var filterMenu: some View {
        Menu {
            Picker("Filter by grade", selection: $model.filter) {
                Label("All grades", systemImage: "square.grid.2x2").tag(SlopRating?.none)
                ForEach(SlopRating.allCases) { rating in
                    Label("\(rating.grade)  \(rating.name)", systemImage: rating.symbol)
                        .tag(SlopRating?.some(rating))
                }
            }
        } label: {
            controlIcon(model.filter == nil
                ? "line.3.horizontal.decrease"
                : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("Filter by grade")
        .accessibilityValue(model.filter.map { $0.accessibilityLabel } ?? "All grades")
        .sensoryFeedback(.selection, trigger: model.filter)
    }

    private func controlIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: max(controlSize, DS.minHitTarget), height: max(controlSize, DS.minHitTarget))
            .contentShape(.rect)
    }

    private func toggleLegend() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .snappySlop) {
            showLegend.toggle()
        }
    }
}

/// Compact grade key that morphs out of the map's "?" button.
private struct MapLegendCard: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                Text("Grades")
                    .font(DS.Typeface.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: DS.Spacing.l)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: DS.minHitTarget, height: DS.minHitTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close rating guide")
            }
            ScrollView {
                RatingLegendView(showsDescriptions: false)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 360)
        }
        .padding(.leading, DS.Spacing.l)
        .padding([.trailing, .bottom], DS.Spacing.s)
        .frame(maxWidth: 260)
    }
}
