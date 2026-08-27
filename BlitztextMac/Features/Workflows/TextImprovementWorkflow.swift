import Foundation
import AppKit
import Observation

@Observable
@MainActor
final class TextImprovementWorkflow: Workflow {
    let type = WorkflowType.textImprover
    var phase: WorkflowPhase = .idle {
        didSet { onPhaseChange?(phase) }
    }
    var onOutput: WorkflowOutputHandler?
    var onPhaseChange: WorkflowPhaseChangeHandler?

    private let recorder = AudioRecorder()
    private let settings: TextImprovementSettings
    private let language: String
    private let backend: TranscriptionBackend
    private let localModelName: String
    private var processingTask: Task<Void, Never>?

    init(
        settings: TextImprovementSettings,
        language: String = "",
        backend: TranscriptionBackend = .gemini,
        localModelName: String = LocalTranscriptionService.recommendedFastModelName
    ) {
        self.settings = settings
        self.language = language
        self.backend = backend
        self.localModelName = localModelName
    }

    // MARK: - Recording State

    var isRecording: Bool { recorder.isRecording }
    var audioLevel: Float { recorder.audioLevel }

    // MARK: - Workflow Protocol

    func start() {
        phase = .running("Aufnahme läuft ...")
        recorder.startRecording()

        if let error = recorder.errorMessage {
            phase = .error(error)
        }
    }

    func stop() {
        if recorder.isRecording {
            recorder.stopRecording()
            guard !TranscriptionQualityService.shouldRejectRecording(duration: recorder.lastRecordingDuration) else {
                recorder.discardRecording()
                phase = .error("Keine Aufnahme erkannt.")
                return
            }
            processRecording()
        } else {
            processingTask?.cancel()
            phase = .idle
        }
    }

    func reset() {
        processingTask?.cancel()
        if recorder.isRecording {
            recorder.stopRecording()
        }
        recorder.discardRecording()
        phase = .idle
    }

    // MARK: - Two-Phase Processing: Transcription -> GPT

    private func processRecording() {
        guard let url = recorder.recordingURL else {
            phase = .error("Keine Aufnahme vorhanden.")
            return
        }

        phase = .running(backend == .local ? "Wird lokal transkribiert ..." : "Wird transkribiert ...")
        let recordingDuration = recorder.lastRecordingDuration
        let vocabularyHints = recordingDuration >= 0.9 ? settings.customTerms : []
        let requestLanguage = language

        processingTask = Task {
            defer {
                try? FileManager.default.removeItem(at: url)
            }

            do {
                let rawText: String
                switch backend {
                case .gemini:
                    rawText = try await TranscriptionService.transcribe(
                        audioURL: url,
                        customTerms: vocabularyHints,
                        language: requestLanguage
                    )
                case .local:
                    rawText = try await LocalTranscriptionService.shared.transcribe(
                        audioURL: url,
                        language: requestLanguage,
                        modelName: localModelName
                    )
                }

                let cleanedRawText = TranscriptionQualityService.cleanedTranscript(rawText)
                guard !TranscriptionQualityService.isLikelyArtifact(cleanedRawText, recordingDuration: recordingDuration) else {
                    phase = .error("Keine Aufnahme erkannt.")
                    return
                }

                if Task.isCancelled { return }

                // Phase 2: GPT improvement
                phase = .running("Text wird verbessert ...")

                let improved = try await LLMService.improve(
                    text: cleanedRawText,
                    settings: settings
                )

                let cleanedImproved = TranscriptionQualityService.cleanedTranscript(improved)
                phase = .done(cleanedImproved)
                onOutput?(cleanedImproved)
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }
}
