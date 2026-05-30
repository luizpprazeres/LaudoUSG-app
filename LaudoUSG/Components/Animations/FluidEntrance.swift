import SwiftUI

private struct FluidEntranceValues {
    var opacity = 1.0
    var offsetY = 0.0
    var scale = 1.0
}

struct FluidEntranceModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: FluidEntranceValues(),
            trigger: trigger
        ) { view, values in
            view
                .opacity(values.opacity)
                .offset(y: values.offsetY)
                .scaleEffect(values.scale)
        } keyframes: { _ in
            KeyframeTrack(\.opacity) {
                CubicKeyframe(0, duration: 0.01)
                CubicKeyframe(1, duration: 0.28)
            }
            KeyframeTrack(\.offsetY) {
                CubicKeyframe(14, duration: 0.01)
                CubicKeyframe(0, duration: 0.34)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.98, duration: 0.01)
                CubicKeyframe(1, duration: 0.34)
            }
        }
    }
}

extension View {
    func fluidEntrance<Trigger: Equatable>(trigger: Trigger) -> some View {
        modifier(FluidEntranceModifier(trigger: trigger))
    }
}

private struct FluidEntrancePreview: View {
    @State private var trigger = 0

    var body: some View {
        Text("Laudo pronto")
            .font(TextStyle.bodySemibold)
            .padding()
            .background(AppSurface.card)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .fluidEntrance(trigger: trigger)
            .onTapGesture {
                trigger += 1
            }
    }
}

#Preview {
    FluidEntrancePreview()
}
