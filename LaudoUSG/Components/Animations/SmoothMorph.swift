import SwiftUI

struct SmoothMorphModifier<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(id: id, in: namespace)
            .animation(.laudousgSmooth, value: id)
    }
}

extension View {
    func smoothMorph<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        modifier(SmoothMorphModifier(id: id, namespace: namespace))
    }
}

private struct SmoothMorphPreview: View {
    @Namespace private var namespace
    @State private var isTrailing = false

    var body: some View {
        HStack {
            if !isTrailing {
                pill
            }
            Spacer()
            if isTrailing {
                pill
            }
        }
        .padding()
        .onTapGesture {
            withAnimation(.laudousgSmooth) {
                isTrailing.toggle()
            }
        }
    }

    private var pill: some View {
        Capsule()
            .fill(BrandColor.primary)
            .frame(width: 96, height: 36)
            .smoothMorph(id: "preview-pill", in: namespace)
    }
}

#Preview {
    SmoothMorphPreview()
}
