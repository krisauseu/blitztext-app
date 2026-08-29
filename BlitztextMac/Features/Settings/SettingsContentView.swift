import SwiftUI
import AppKit

struct SettingsContentView: View {
    @Bindable var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Two-tab segmented picker
            Picker("", selection: $selectedTab) {
                Text("Anpassen").tag(0)
                Text("Zugang").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            GeometryReader { geometry in
                ScrollView {
                    if selectedTab == 0 {
                        CustomizeSettingsView(appState: appState)
                            .frame(width: geometry.size.width, alignment: .leading)
                    } else {
                        AccessSettingsView(appState: appState)
                            .frame(width: geometry.size.width, alignment: .leading)
                    }
                }
                .frame(width: geometry.size.width)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            appState.refreshAccessibilityPermission()
            selectedTab = defaultTabSelection
        }
    }

    private var defaultTabSelection: Int {
        if !appState.accessibilityPermissionGranted {
            return 1
        }
        if appState.isConfigured && !BlitztextInstallLocationService.shouldOfferMoveToApplications {
            return 0
        }
        return 1
    }
}

// MARK: - Section Label (quiet style)

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Access Settings (Tab 1: Zugang)

struct AccessSettingsView: View {
    @Bindable var appState: AppState

    private enum FieldFocus {
        case geminiAPIKey
        case openAIAPIKey
    }

    @State private var launchAtLoginService = LaunchAtLoginService()
    @State private var currentInstallLocation = BlitztextInstallLocationService.currentInstallLocation
    @State private var geminiAPIKey = ""
    @State private var editingGeminiAPIKey = false
    @State private var openAIAPIKey = ""
    @State private var editingOpenAIAPIKey = false
    @State private var saved = false
    @State private var saveErrorText: String?
    @State private var installActionErrorText: String?
    @State private var showCleanupOptions = false
    @State private var deleteLocalDataOnCleanup = true
    @State private var cleanupStatusText: String?
    @State private var cleanupErrorText: String?
    @FocusState private var focusedField: FieldFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Berechtigungen")

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: appState.accessibilityPermissionGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(appState.accessibilityPermissionGranted ? .green : .orange)
                        .frame(width: 18, height: 18)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.accessibilityPermissionGranted ? "Direktes Einfügen ist freigegeben." : "Direktes Einfügen ist noch nicht freigegeben.")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Öffne Bedienungshilfen und aktiviere Blitztext. Falls Blitztext schon aktiv ist, einmal aus- und wieder einschalten.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    Button("Bedienungshilfen öffnen") {
                        appState.requestAccessibilityPermission()
                    }
                    .buttonStyle(SubtleButtonStyle())

                    Button("Erneut prüfen") {
                        appState.refreshAccessibilityPermission()
                    }
                    .buttonStyle(SubtleButtonStyle())
                }
            }

            // MARK: - Gemini API Key
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Gemini API Key (Transkribierung)")
                    Spacer()
                    if appState.hasValue(for: .geminiAPIKey) && !editingGeminiAPIKey {
                        Button("Ändern") {
                            editingGeminiAPIKey = true
                            focusedField = .geminiAPIKey
                            saveErrorText = nil
                        }
                        .font(.system(size: 10, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }

                if appState.hasValue(for: .geminiAPIKey) && !editingGeminiAPIKey {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green.opacity(0.8))
                        Text(appState.apiKeyDisplayValue(for: .geminiAPIKey))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                } else {
                    HStack(spacing: 8) {
                        SecureField("AIza...", text: $geminiAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11.5))
                            .focused($focusedField, equals: .geminiAPIKey)
                            .onSubmit {
                                saveGeminiAPIKeyFromField()
                            }

                        Button(geminiAPIKeyActionTitle) {
                            if geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                pasteGeminiAPIKeyFromClipboard()
                            } else {
                                saveGeminiAPIKeyFromField()
                            }
                        }
                        .buttonStyle(SubtleButtonStyle())
                    }
                }

                Text("Für die Online-Transkribierung über Gemini 3.5 Transcribe. Der Key wird lokal in Application Support gespeichert.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // MARK: - OpenAI API Key
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "OpenAI API Key (Blitztext+, Translation, Emojis)")
                    Spacer()
                    if appState.hasValue(for: .openAIAPIKey) && !editingOpenAIAPIKey {
                        Button("Ändern") {
                            editingOpenAIAPIKey = true
                            focusedField = .openAIAPIKey
                            saveErrorText = nil
                        }
                        .font(.system(size: 10, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }

                if appState.hasValue(for: .openAIAPIKey) && !editingOpenAIAPIKey {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green.opacity(0.8))
                        Text(appState.apiKeyDisplayValue(for: .openAIAPIKey))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                } else {
                    HStack(spacing: 8) {
                        SecureField("sk-...", text: $openAIAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11.5))
                            .focused($focusedField, equals: .openAIAPIKey)
                            .onSubmit {
                                saveOpenAIAPIKeyFromField()
                            }

                        Button(openAIAPIKeyActionTitle) {
                            if openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                pasteOpenAIAPIKeyFromClipboard()
                            } else {
                                saveOpenAIAPIKeyFromField()
                            }
                        }
                        .buttonStyle(SubtleButtonStyle())
                    }
                }

                Text("Wird für Textoptimierung, Übersetzung und Emojis verwendet. Der Key wird lokal in Application Support gespeichert.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Installation")

                Text(installationHeadline)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(installationDetail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(BlitztextInstallLocationService.bundleURL.path)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if !BlitztextInstallLocationService.otherInstalledBundleURLs.isEmpty {
                    Text("Weitere Blitztext-Kopien auf diesem Mac können doppelte Login-Items auslösen.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    if BlitztextInstallLocationService.shouldOfferMoveToApplications {
                        Button("Nach /Applications bewegen") {
                            moveToApplications()
                        }
                        .buttonStyle(SubtleButtonStyle())
                    }

                    Button("Im Finder zeigen") {
                        revealInFinder(urls: [BlitztextInstallLocationService.bundleURL])
                    }
                    .buttonStyle(SubtleButtonStyle())

                    if !BlitztextInstallLocationService.otherInstalledBundleURLs.isEmpty {
                        Button("Weitere Kopien zeigen") {
                            revealInFinder(urls: BlitztextInstallLocationService.otherInstalledBundleURLs)
                        }
                        .buttonStyle(SubtleButtonStyle())
                    }
                }

                if let installActionErrorText {
                    Text(installActionErrorText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Updates")

                Text("Diese Preview hat keinen oeffentlichen Update-Feed. Baue neue Versionen selbst aus dem Repo.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !currentInstallLocation.isCanonicalInstall {
                    Text("Hotkeys und Login-Start laufen am stabilsten, wenn Blitztext aus /Applications gestartet wird.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Updates sind in dieser Preview manuell: pull, build, starten.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }

            // Launch at Login
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Beim Anmelden")

                Toggle("Blitztext automatisch starten", isOn: Binding(
                    get: { launchAtLoginService.isEnabled },
                    set: { launchAtLoginService.setEnabled($0) }
                ))
                .toggleStyle(.switch)

                Text(launchAtLoginService.errorText ?? launchAtLoginService.helperText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(
                        launchAtLoginService.errorText == nil
                            ? AnyShapeStyle(.secondary)
                            : AnyShapeStyle(.red)
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let saveErrorText {
                Text(saveErrorText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Hinweis")

                Text("Fuer direktes Einfuegen: Blitztext einmal nach /Applications legen und danach Mikrofon sowie Bedienungshilfen erlauben.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Sauber Entfernen")

                Text("Vor dem Löschen Blitztext erst auf diesem Mac bereinigen. So verschwinden Anmeldestart und lokale Daten sauber aus dem Weg.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if showCleanupOptions {
                    Toggle("Zugangsdaten und Einstellungen dieses Macs löschen", isOn: $deleteLocalDataOnCleanup)
                        .toggleStyle(.switch)

                    Text("Danach Blitztext beenden und die App aus /Applications löschen. Bereits verwaiste alte Login-Items können in den Systemeinstellungen einmalig manuell entfernt werden.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button("Abbrechen") {
                            showCleanupOptions = false
                        }
                        .buttonStyle(SubtleButtonStyle())

                        Button("Jetzt bereinigen") {
                            runCleanup()
                        }
                        .buttonStyle(SubtleButtonStyle())
                        .foregroundStyle(.red)
                    }
                } else {
                    Button("Entfernung vorbereiten") {
                        showCleanupOptions = true
                    }
                    .buttonStyle(SubtleButtonStyle())
                }

                if let cleanupStatusText {
                    Text(cleanupStatusText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.green)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let cleanupErrorText {
                    Text(cleanupErrorText)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Save button (right-aligned, text only)
            HStack {
                Spacer()
                Button {
                    save()
                } label: {
                    if saved {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("Gespeichert")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                    } else {
                        Text("Speichern")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                }
                .buttonStyle(SubtleButtonStyle())
                .animation(.easeInOut(duration: 0.2), value: saved)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            launchAtLoginService.refresh()
            refreshInstallState()
            load()
            if !appState.hasValue(for: .geminiAPIKey) {
                editingGeminiAPIKey = true
                focusedField = .geminiAPIKey
            } else if !appState.hasValue(for: .openAIAPIKey) {
                editingOpenAIAPIKey = true
                focusedField = .openAIAPIKey
            }
        }
    }

    private func load() {
        geminiAPIKey = ""
        openAIAPIKey = ""
    }

    private var geminiAPIKeyActionTitle: String {
        geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Einfügen"
            : "Speichern"
    }

    private var openAIAPIKeyActionTitle: String {
        openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Einfügen"
            : "Speichern"
    }

    private func save() {
        saveErrorText = nil
        cleanupStatusText = nil
        cleanupErrorText = nil
        KeychainService.invalidateCache()

        var hasSavedSomething = false

        let trimmedGemini = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if editingGeminiAPIKey && !trimmedGemini.isEmpty {
            guard saveGeminiAPIKey(trimmedGemini) else { return }
            hasSavedSomething = true
        }

        let trimmedOpenAI = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if editingOpenAIAPIKey && !trimmedOpenAI.isEmpty {
            guard saveOpenAIAPIKey(trimmedOpenAI) else { return }
            hasSavedSomething = true
        }

        if hasSavedSomething || (appState.hasValue(for: .geminiAPIKey) || appState.hasValue(for: .openAIAPIKey)) {
            showSavedConfirmation()
        }
    }

    private func saveGeminiAPIKeyFromField() {
        saveErrorText = nil
        cleanupStatusText = nil
        cleanupErrorText = nil
        guard saveGeminiAPIKey(geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        showSavedConfirmation()
    }

    private func saveOpenAIAPIKeyFromField() {
        saveErrorText = nil
        cleanupStatusText = nil
        cleanupErrorText = nil
        guard saveOpenAIAPIKey(openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        showSavedConfirmation()
    }

    private static func cleanKeyInput(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if (text.hasPrefix("\"") && text.hasSuffix("\"")) || (text.hasPrefix("'") && text.hasSuffix("'")) {
            text = String(text.dropFirst().dropLast())
        }
        if let eqIndex = text.lastIndex(of: "=") {
            let candidate = String(text[text.index(after: eqIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.count >= 8 {
                text = candidate
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    private func saveGeminiAPIKey(_ rawAPIKey: String) -> Bool {
        let cleaned = Self.cleanKeyInput(rawAPIKey)
        guard !cleaned.isEmpty else {
            saveErrorText = "Bitte trage deinen Gemini API Key ein."
            return false
        }

        guard cleaned.count >= 8 else {
            saveErrorText = "Der eingegebene Gemini API Key ist zu kurz."
            return false
        }

        do {
            try KeychainService.save(key: .geminiAPIKey, value: cleaned)
        } catch {
            saveErrorText = "Gemini API Key konnte nicht gespeichert werden: \(error.localizedDescription)"
            return false
        }

        KeychainService.invalidateCache()
        appState.refreshCredentialStatus()
        guard appState.hasValue(for: .geminiAPIKey) else {
            saveErrorText = "Gemini API Key wurde nicht persistent gespeichert. Bitte App neu starten und erneut versuchen."
            return false
        }

        geminiAPIKey = ""
        editingGeminiAPIKey = false
        focusedField = nil
        saveErrorText = nil
        return true
    }

    @discardableResult
    private func saveOpenAIAPIKey(_ rawAPIKey: String) -> Bool {
        let cleaned = Self.cleanKeyInput(rawAPIKey)
        guard !cleaned.isEmpty else {
            saveErrorText = "Bitte trage deinen OpenAI API Key ein."
            return false
        }

        guard cleaned.count >= 8 else {
            saveErrorText = "Der eingegebene OpenAI API Key ist zu kurz."
            return false
        }

        do {
            try KeychainService.save(key: .openAIAPIKey, value: cleaned)
        } catch {
            saveErrorText = "OpenAI API Key konnte nicht gespeichert werden: \(error.localizedDescription)"
            return false
        }

        KeychainService.invalidateCache()
        appState.refreshCredentialStatus()
        guard appState.hasValue(for: .openAIAPIKey) else {
            saveErrorText = "OpenAI API Key wurde nicht persistent gespeichert. Bitte App neu starten und erneut versuchen."
            return false
        }

        openAIAPIKey = ""
        editingOpenAIAPIKey = false
        focusedField = nil
        saveErrorText = nil
        return true
    }

    private func showSavedConfirmation() {
        withAnimation(.easeInOut(duration: 0.2)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) { saved = false }
        }
    }

    private func pasteGeminiAPIKeyFromClipboard() {
        guard let rawText = NSPasteboard.general.string(forType: .string) else {
            saveErrorText = "Zwischenablage enthält keinen Text."
            return
        }

        let firstLine = rawText.components(separatedBy: .newlines).first ?? rawText
        let cleaned = Self.cleanKeyInput(firstLine)
        guard !cleaned.isEmpty, cleaned.count >= 8 else {
            saveErrorText = "Zwischenablage enthält keinen gültigen Gemini API Key."
            return
        }

        guard saveGeminiAPIKey(cleaned) else {
            return
        }
        NSPasteboard.general.clearContents()
        showSavedConfirmation()
    }

    private func pasteOpenAIAPIKeyFromClipboard() {
        guard let rawText = NSPasteboard.general.string(forType: .string) else {
            saveErrorText = "Zwischenablage enthält keinen Text."
            return
        }

        let firstLine = rawText.components(separatedBy: .newlines).first ?? rawText
        let cleaned = Self.cleanKeyInput(firstLine)
        guard !cleaned.isEmpty, cleaned.count >= 8 else {
            saveErrorText = "Zwischenablage enthält keinen gültigen OpenAI API Key."
            return
        }

        guard saveOpenAIAPIKey(cleaned) else {
            return
        }
        NSPasteboard.general.clearContents()
        showSavedConfirmation()
    }

    private var installationHeadline: String {
        switch currentInstallLocation {
        case .applications:
            return "Blitztext liegt am richtigen Ort."
        case .userApplications:
            return "Blitztext liegt noch in ~/Applications."
        case .outsideApplications:
            return "Blitztext liegt noch nicht in /Applications."
        case .unknown:
            return "Der Installationsort konnte nicht sicher erkannt werden."
        }
    }

    private var installationDetail: String {
        switch currentInstallLocation {
        case .applications:
            if BlitztextInstallLocationService.otherInstalledBundleURLs.isEmpty {
                return "Für stabile Login-Items und Updates nur diese Kopie weiterverwenden."
            }
            return "Diese Kopie ist korrekt. Zusätzliche Kopien solltest du später entfernen."
        case .userApplications:
            return "Fuer stabile Hotkeys und Login-Items sollte Blitztext nur aus /Applications laufen."
        case .outsideApplications:
            return "Verschiebe Blitztext einmal nach /Applications, damit Anmeldestart und Hotkeys sauber bleiben."
        case .unknown:
            return "Öffne Blitztext möglichst direkt aus /Applications."
        }
    }

    private func refreshInstallState() {
        currentInstallLocation = BlitztextInstallLocationService.currentInstallLocation
        installActionErrorText = nil
    }

    private func moveToApplications() {
        installActionErrorText = nil

        do {
            try BlitztextInstallLocationService.moveToApplicationsAndRelaunch()
        } catch {
            installActionErrorText = error.localizedDescription
        }
    }

    private func runCleanup() {
        cleanupStatusText = nil
        cleanupErrorText = nil

        let report = deleteLocalDataOnCleanup
            ? BlitztextCleanupService.cleanupUserData()
            : BlitztextCleanupService.removeLaunchAtLoginRegistration()

        KeychainService.invalidateCache()
        launchAtLoginService.refresh()
        refreshInstallState()

        if deleteLocalDataOnCleanup {
            geminiAPIKey = ""
            editingGeminiAPIKey = true
            openAIAPIKey = ""
            editingOpenAIAPIKey = true
        }
        appState.refreshCredentialStatus()

        if report.failedItems.isEmpty {
            cleanupStatusText = deleteLocalDataOnCleanup
                ? "Anmeldestart und lokale Daten wurden bereinigt. Jetzt Blitztext beenden und aus /Applications löschen."
                : "Anmeldestart wurde deaktiviert. Jetzt Blitztext beenden und aus /Applications löschen."
            showCleanupOptions = false

            let urlsToReveal = report.knownInstallBundleURLs.isEmpty
                ? [BlitztextInstallLocationService.bundleURL]
                : report.knownInstallBundleURLs
            revealInFinder(urls: urlsToReveal)
            return
        }

        let failureSummary = report.failedItems
            .map { "\($0.url.lastPathComponent): \($0.errorDescription)" }
            .joined(separator: "\n")
        cleanupErrorText = "Nicht alles konnte bereinigt werden:\n\(failureSummary)"
    }

    private func revealInFinder(urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}

// MARK: - Customize Settings (Tab 2: Anpassen)

struct CustomizeSettingsView: View {
    @Bindable var appState: AppState
    @State private var newTerm = ""

    private var installedLocalModels: [LocalTranscriptionModel] {
        LocalTranscriptionService.installedModels()
    }

    private var localModelOptions: [LocalTranscriptionModel] {
        LocalTranscriptionService.modelOptions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // MARK: Transkription
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Transkription")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Methode")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $appState.appSettings.transcriptionBackend) {
                        ForEach(TranscriptionBackend.allCases) { backend in
                            Text(backend.displayName).tag(backend)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if appState.appSettings.transcriptionBackend == .gemini {
                    HStack(spacing: 6) {
                        Image(systemName: appState.hasValue(for: .geminiAPIKey) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(appState.hasValue(for: .geminiAPIKey) ? .green : .orange)
                        Text(appState.hasValue(for: .geminiAPIKey) ? "Gemini 3.5 Transcribe (Cloud API) ist einsatzbereit." : "Gemini API Key fehlt im Tab 'Zugang'.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: appState.selectedLocalModelIsInstalled ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(appState.selectedLocalModelIsInstalled ? .green : .blue)
                        Text(appState.selectedLocalModelIsInstalled ? "\(installedLocalModels.count) lokales WhisperKit-Modell installiert." : "Das ausgewählte Modell wird beim Installieren lokal gespeichert.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        Text("Lokales Modell")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Picker("", selection: Binding(
                            get: { appState.selectedLocalModelName },
                            set: { appState.appSettings.selectedLocalTranscriptionModelName = $0 }
                        )) {
                            ForEach(localModelOptions) { model in
                                Text("\(model.displayName) · \(model.installStateLabel)").tag(model.id)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .disabled(appState.isDownloadingLocalModel)
                    }

                    if let progress = appState.localModelDownloadProgress {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: progress)
                            Text(appState.localModelDownloadStatusText ?? "Modell wird geladen...")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 10) {
                            Button(appState.localModelDownloadButtonTitle) {
                                appState.installSelectedLocalModel()
                            }
                            .controlSize(.small)
                            .disabled(appState.selectedLocalModelIsInstalled)

                            Link("Modellseite", destination: LocalTranscriptionService.modelPageURL(for: appState.selectedLocalModelName))
                                .font(.system(size: 10.5, weight: .medium))
                        }
                    }

                    if let errorText = appState.localModelDownloadErrorText {
                        Text(errorText)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // MARK: Tastenkuerzel
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Tastenk\u{00FC}rzel")

                VStack(spacing: 6) {
                    ForEach(WorkflowType.mainMenuCases) { type in
                        HStack {
                            Text(type.hotkeyLabel)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 124, alignment: .leading)
                            Text(appState.displayName(for: type))
                                .font(.system(size: 11.5, weight: .medium))
                            Spacer()
                        }
                    }
                }

                // Mode picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Modus")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $appState.appSettings.hotkeyMode) {
                        ForEach(HotkeyMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // MARK: Blitztext+
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Blitztext+")

                // Tone
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schreibstil")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $appState.textImprovementSettings.tone) {
                        ForEach(TextImprovementSettings.TextTone.allCases) { tone in
                            Text(tone.displayName).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // System Prompt
                VStack(alignment: .leading, spacing: 8) {
                    Text("Eigene Anweisung")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $appState.textImprovementSettings.systemPrompt)
                        .font(.system(size: 11))
                        .frame(height: 64)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
                        .overlay(alignment: .topLeading) {
                            if appState.textImprovementSettings.systemPrompt.isEmpty {
                                Text("z.B. \"Schreibe pr\u{00E4}gnant und ohne F\u{00FC}llw\u{00F6}rter.\"")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.quaternary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                // Context
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kontext")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    TextField("z.B. \"E-Mails im Bereich Unternehmensberatung\"", text: $appState.textImprovementSettings.context)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }
            }

            // MARK: Blitztext Translate
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Blitztext Translate")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Zielsprache")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $appState.translationSettings.targetLanguage) {
                        ForEach(TranslationSettings.TargetLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // MARK: Blitztext :)
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Blitztext :)")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Emoji-Dichte")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $appState.emojiTextSettings.emojiDensity) {
                        ForEach(EmojiTextSettings.EmojiDensity.allCases) { density in
                            Text(density.displayName).tag(density)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // MARK: Eigennamen
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Eigennamen")

                // Term chips
                if !appState.textImprovementSettings.customTerms.isEmpty {
                    FlowLayout(spacing: 5) {
                        ForEach(appState.textImprovementSettings.customTerms, id: \.self) { term in
                            HStack(spacing: 3) {
                                Text(term)
                                    .font(.system(size: 10.5))
                                Button {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        appState.textImprovementSettings.customTerms.removeAll { $0 == term }
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(SubtleButtonStyle())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.04), lineWidth: 0.5)
                            )
                        }
                    }
                }

                HStack(spacing: 6) {
                    TextField("Neuer Begriff", text: $newTerm)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onSubmit { addTerm() }

                    Button { addTerm() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.blue.opacity(0.7))
                    }
                    .buttonStyle(SubtleButtonStyle())
                    .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !appState.textImprovementSettings.customTerms.contains(trimmed) else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            appState.textImprovementSettings.customTerms.append(trimmed)
        }
        newTerm = ""
    }
}

// MARK: - Flow Layout (for term tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
