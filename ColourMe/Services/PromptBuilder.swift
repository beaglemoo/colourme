import Foundation

enum PromptBuilder {
    static func imagePrompt(subject: String, complexity: ComplexityLevel) -> String {
        """
        Black and white children's colouring book page. Subject: \(subject). \
        Clean bold black outlines only, no shading, no grey fill, no colour, \
        pure white background, printable line art, portrait orientation. \
        \(complexity.promptModifier)
        """
    }

    static func fallbackSubjects(theme: String, count: Int) -> [String] {
        (1...count).map { "A fun \(theme) scene, variation \($0)" }
    }

    static func coverPrompt(theme: String, complexity: ComplexityLevel) -> String {
        """
        Black and white children's colouring book cover illustration about \(theme). \
        A joyful montage scene, clean bold black outlines only, no shading, no grey \
        fill, no colour, pure white background, printable line art, portrait \
        orientation. No text, no letters, no title - artwork only, with clear \
        empty space at the top. \(complexity.promptModifier)
        """
    }
}
