import A2UISwiftCore
import Foundation

enum ImageEditorA2UIContent {
    static func controlCard() -> [A2uiMessage] {
        let surfaceId = "edit_controls_\(UUID().uuidString)"
        return [
            .createSurface(CreateSurfacePayload(
                surfaceId: surfaceId,
                catalogId: basicCatalogId,
                sendDataModel: true
            )),
            .updateDataModel(UpdateDataModelPayload(
                surfaceId: surfaceId,
                path: "/selectedFilter",
                value: .array([.string(ImageFilter.vivid.rawValue)])
            )),
            .updateComponents(UpdateComponentsPayload(
                surfaceId: surfaceId,
                components: [
                    component("root", "Card", ["child": .string("content")]),
                    component("content", "Column", [
                        "children": .array(["title", "body", "filter_picker", "button_row"].map(AnyCodable.string)),
                        "align": .string("stretch"),
                    ]),
                    component("title", "Text", [
                        "text": .string("On-device image edits"),
                        "variant": .string("h3"),
                    ]),
                    component("body", "Text", [
                        "text": .string("Choose a quick edit. The image processing runs locally with UIKit and Core Image; A2UI only describes the controls."),
                    ]),
                    component("filter_picker", "ChoicePicker", [
                        "label": .string("Filter"),
                        "options": .array(ImageFilter.allCases.map {
                            .dictionary([
                                "label": .string($0.title),
                                "value": .string($0.rawValue),
                            ])
                        }),
                        "value": dataBinding("/selectedFilter"),
                        "displayStyle": .string("chips"),
                        "variant": .string("mutuallyExclusive"),
                    ]),
                    component("button_row", "Row", [
                        "children": .array(["apply_filter", "brighten", "crop_square", "reset"].map(AnyCodable.string)),
                        "align": .string("center"),
                    ]),
                    button("apply_filter", titleId: "apply_filter_text", title: "Apply Filter", operation: .filter, filterPath: "/selectedFilter"),
                    text("apply_filter_text", "Apply Filter"),
                    button("brighten", titleId: "brighten_text", title: "Brighten", operation: .brighten),
                    text("brighten_text", "Brighten"),
                    button("crop_square", titleId: "crop_square_text", title: "Square Crop", operation: .squareCrop),
                    text("crop_square_text", "Square Crop"),
                    button("reset", titleId: "reset_text", title: "Reset", operation: .reset),
                    text("reset_text", "Reset"),
                ]
            )),
        ]
    }

    static func resultCard(result: ImageEditResult) -> [A2uiMessage] {
        let surfaceId = "edit_result_\(UUID().uuidString)"
        return [
            .createSurface(CreateSurfacePayload(surfaceId: surfaceId, catalogId: basicCatalogId)),
            .updateComponents(UpdateComponentsPayload(
                surfaceId: surfaceId,
                components: [
                    component("root", "Card", ["child": .string("content")]),
                    component("content", "Column", [
                        "children": .array(["title", "detail"].map(AnyCodable.string)),
                        "align": .string("stretch"),
                    ]),
                    component("title", "Text", [
                        "text": .string(result.title),
                        "variant": .string("h3"),
                    ]),
                    component("detail", "Text", [
                        "text": .string(result.detail),
                    ]),
                ]
            )),
        ]
    }

    private static func text(_ id: String, _ value: String) -> RawComponent {
        component(id, "Text", ["text": .string(value)])
    }

    private static func button(
        _ id: String,
        titleId: String,
        title: String,
        operation: ImageEditOperation,
        filterPath: String? = nil
    ) -> RawComponent {
        var context: [String: AnyCodable] = [
            "operation": .string(operation.rawValue),
        ]
        if let filterPath {
            context["filter"] = dataBinding(filterPath)
        }
        return component(id, "Button", [
            "child": .string(titleId),
            "variant": operation == .filter ? .string("primary") : .string("bordered"),
            "action": .dictionary([
                "event": .dictionary([
                    "name": .string("applyEdit"),
                    "context": .dictionary(context),
                ]),
            ]),
            "accessibility": .dictionary([
                "label": .string(title),
            ]),
        ])
    }

    private static func component(_ id: String, _ type: String, _ properties: [String: AnyCodable]) -> RawComponent {
        RawComponent(id: id, component: type, properties: properties)
    }

    private static func dataBinding(_ path: String) -> AnyCodable {
        .dictionary(["path": .string(path)])
    }
}
