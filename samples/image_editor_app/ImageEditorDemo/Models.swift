import UIKit

enum ImageEditOperation: String {
    case filter
    case brighten
    case squareCrop
    case reset
}

enum ImageFilter: String, CaseIterable {
    case mono
    case vivid
    case warm
    case cool

    var title: String {
        switch self {
        case .mono: return "Mono"
        case .vivid: return "Vivid"
        case .warm: return "Warm"
        case .cool: return "Cool"
        }
    }
}

struct ImageEditResult {
    let title: String
    let detail: String
    let image: UIImage
}

enum ChatEntry {
    case user(String)
    case assistant(String)
    case surface(UIView)
}
