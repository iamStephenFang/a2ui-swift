import UIKit

enum ImageEditOperation: String {
    case filter
    case brightness
    case crop
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

enum BrightnessLevel: String, CaseIterable {
    case subtle
    case medium
    case strong

    var title: String {
        switch self {
        case .subtle: return "Subtle"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }

    var adjustment: Double {
        switch self {
        case .subtle: return 0.08
        case .medium: return 0.16
        case .strong: return 0.26
        }
    }
}

enum ImageCropRatio: String, CaseIterable {
    case square
    case portrait
    case landscape
    case widescreen

    var title: String {
        switch self {
        case .square: return "Square"
        case .portrait: return "Portrait 4:5"
        case .landscape: return "Landscape 4:3"
        case .widescreen: return "Widescreen 16:9"
        }
    }

    var widthToHeight: CGFloat {
        switch self {
        case .square: return 1
        case .portrait: return 4.0 / 5.0
        case .landscape: return 4.0 / 3.0
        case .widescreen: return 16.0 / 9.0
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
