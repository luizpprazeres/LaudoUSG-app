import SwiftUI

/// Editor de adição/remoção manual de achados tireoidianos.
/// Espelha o pattern de `BreastSchemaEditor` — toolbar de tipos + form lado/terço/tamanho + badges.
@MainActor
struct ThyroidSchemaEditor: View {
    @Binding var findings: [ThyroidFinding]

    @State private var activeForm: ThyroidFinding.FindingType? = nil
    @State private var formSide: ThyroidFinding.Side = .direito
    @State private var formTercio: ThyroidFinding.Tercio = .medio
    @State private var formSize: Int = 8

    private var manualFindings: [ThyroidFinding] {
        findings.filter { $0.source == .manual }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            toolbar
            if activeForm != nil {
                formCard
            }
            if !manualFindings.isEmpty {
                badgesList
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Adicionar achado")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(Self.toolbarConfig, id: \.type) { cfg in
                        toolbarButton(cfg: cfg)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func toolbarButton(cfg: ToolbarConfig) -> some View {
        let isActive = activeForm == cfg.type
        return Button {
            Haptics.tap()
            withAnimation(.snappy) {
                activeForm = isActive ? nil : cfg.type
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text(cfg.label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(cfg.color)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? AppSurface.textPrimary : Color.clear, lineWidth: 2)
            )
        }
        .accessibilityLabel("Adicionar \(cfg.label)")
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sideRow
            // Terço só faz sentido se o lado for um lobo (não istmo)
            if formSide != .istmo {
                tercioRow
            }
            sizeField
            actionRow
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(AppSurface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppSurface.border, lineWidth: 1)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var sideRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Localização").font(TextStyle.caption).foregroundStyle(AppSurface.textSecondary)
            Picker("Localização", selection: $formSide) {
                Text("Lobo direito").tag(ThyroidFinding.Side.direito)
                Text("Lobo esquerdo").tag(ThyroidFinding.Side.esquerdo)
                Text("Istmo").tag(ThyroidFinding.Side.istmo)
            }
            .pickerStyle(.segmented)
        }
    }

    private var tercioRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Terço").font(TextStyle.caption).foregroundStyle(AppSurface.textSecondary)
            Picker("Terço", selection: $formTercio) {
                Text("Superior").tag(ThyroidFinding.Tercio.superior)
                Text("Médio").tag(ThyroidFinding.Tercio.medio)
                Text("Inferior").tag(ThyroidFinding.Tercio.inferior)
            }
            .pickerStyle(.segmented)
        }
    }

    private var sizeField: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Tamanho (mm)").font(TextStyle.caption).foregroundStyle(AppSurface.textSecondary)
            HStack(spacing: 0) {
                TextField("0", value: $formSize, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 40)
                Stepper("", value: $formSize, in: 1...100)
                    .labelsHidden()
            }
            .padding(Spacing.xs)
            .background(AppSurface.background)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(AppSurface.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    private var actionRow: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                handleAdd()
            } label: {
                Text("Adicionar")
                    .font(TextStyle.bodyLargeSemibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .fill(BrandColor.primary)
                    )
            }
            Button {
                withAnimation(.snappy) { activeForm = nil }
            } label: {
                Text("Cancelar")
                    .font(TextStyle.bodyMedium)
                    .foregroundStyle(AppSurface.textSecondary)
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.md)
            }
        }
    }

    // MARK: - Badges list

    private var badgesList: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Adicionados manualmente")
                .font(TextStyle.captionMedium)
                .foregroundStyle(AppSurface.textSecondary)
                .textCase(.uppercase)
            FlowLayout(spacing: 6) {
                ForEach(manualFindings) { f in
                    badge(for: f)
                }
            }
        }
    }

    private func badge(for f: ThyroidFinding) -> some View {
        HStack(spacing: 6) {
            Text(badgeText(f))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurface.textPrimary)
            Button {
                Haptics.tap()
                withAnimation(.snappy) {
                    findings.removeAll { $0.id == f.id }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppSurface.textMuted)
            }
            .accessibilityLabel("Remover \(f.type.label)")
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(AppSurface.muted)
        )
        .overlay(
            Capsule().stroke(AppSurface.border, lineWidth: 1)
        )
    }

    private func badgeText(_ f: ThyroidFinding) -> String {
        var parts: [String] = [f.type.label, f.side.shortLabel]
        if let t = f.tercio { parts.append(t.shortLabel) }
        if let s = f.sizeMax { parts.append("\(Int(s))mm") }
        return parts.joined(separator: " ")
    }

    // MARK: - Actions

    private func handleAdd() {
        guard let type = activeForm else { return }
        Haptics.success()
        let tercio: ThyroidFinding.Tercio? = (formSide == .istmo) ? nil : formTercio
        let new = ThyroidFinding(
            side: formSide,
            tercio: tercio,
            type: type,
            sizeMax: Double(formSize),
            approximate: false,
            source: .manual
        )
        withAnimation(.snappy) {
            findings.append(new)
            activeForm = nil
        }
    }

    // MARK: - Config

    struct ToolbarConfig {
        let type: ThyroidFinding.FindingType
        let label: String
        let color: Color
    }

    /// P&B no marcador final, mas a toolbar mantém cor pra fácil reconhecimento
    /// do tipo durante seleção (igual mama).
    static let toolbarConfig: [ToolbarConfig] = [
        .init(type: .solid, label: "Sólido", color: BrandColor.primary),
        .init(type: .cystic, label: "Cisto", color: Color(hex: "0EA5E9")),
        .init(type: .mixed, label: "Misto", color: Color(hex: "F59E0B")),
        .init(type: .spongiform, label: "Esponjoso", color: Color(hex: "A855F7")),
        .init(type: .calcification, label: "Calcificação", color: Color(hex: "6B7280")),
    ]
}
