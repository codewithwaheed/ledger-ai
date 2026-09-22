import Foundation
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(Vision)
import Vision
#endif
#if canImport(UIKit)
import UIKit
#endif

public enum PDFExtractionError: Error, Sendable {
    case cannotOpen
    case locked
    case noText
}

/// Extracts one text string per page. Uses the PDF's own text layer; falls back to Vision OCR for scanned pages.
public struct PDFTextExtractor: Sendable {
    public init() {}

    public func extractPages(from url: URL, password: String? = nil) async throws -> [String] {
        #if canImport(PDFKit)
        guard let doc = PDFDocument(url: url) else { throw PDFExtractionError.cannotOpen }
        if doc.isLocked {
            guard let password, doc.unlock(withPassword: password) else { throw PDFExtractionError.locked }
        }
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.count > 40 {
                pages.append(text)
            } else {
                pages.append(try await ocr(page: page))
            }
        }
        guard pages.contains(where: { !$0.isEmpty }) else { throw PDFExtractionError.noText }
        return pages
        #else
        throw PDFExtractionError.cannotOpen
        #endif
    }

    #if canImport(PDFKit) && canImport(Vision)
    private func ocr(page: PDFPage) async throws -> String {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 3
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let image = page.thumbnail(of: size, for: .mediaBox)
        guard let cg = image.cgImage else { return "" }
        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                    .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
                    .compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            do { try VNImageRequestHandler(cgImage: cg).perform([request]) } catch { cont.resume(throwing: error) }
        }
    }
    #endif
}
