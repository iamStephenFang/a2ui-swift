import A2UISwiftCore
import Foundation

enum ImageEditorA2UIContent {
    static func filterCard() -> [A2uiMessage] {
        choiceCard(
            surfacePrefix: "filter_controls",
            title: "Choose a Filter",
            body: "Pick the look you want to apply to the current image.",
            path: "/selectedFilter",
            initialValue: ImageFilter.vivid.rawValue,
            label: "Filter",
            options: ImageFilter.allCases.map { ($0.title, $0.rawValue) },
            buttonTitle: "Apply Filter",
            operation: .filter,
            contextKey: "filter"
        )
    }

    static func brightnessCard() -> [A2uiMessage] {
        choiceCard(
            surfacePrefix: "brightness_controls",
            title: "Adjust Brightness",
            body: "Choose how much brighter the image should become.",
            path: "/selectedBrightness",
            initialValue: BrightnessLevel.medium.rawValue,
            label: "Brightness",
            options: BrightnessLevel.allCases.map { ($0.title, $0.rawValue) },
            buttonTitle: "Apply Brightness",
            operation: .brightness,
            contextKey: "brightness"
        )
    }

    static func cropCard() -> [A2uiMessage] {
        choiceCard(
            surfacePrefix: "crop_controls",
            title: "Choose Crop Ratio",
            body: "Select the output composition for the current image.",
            path: "/selectedCropRatio",
            initialValue: ImageCropRatio.square.rawValue,
            label: "Ratio",
            options: ImageCropRatio.allCases.map { ($0.title, $0.rawValue) },
            buttonTitle: "Apply Crop",
            operation: .crop,
            contextKey: "cropRatio"
        )
    }

    private static func choiceCard(
        surfacePrefix: String,
        title: String,
        body: String,
        path: String,
        initialValue: String,
        label: String,
        options: [(String, String)],
        buttonTitle: String,
        operation: ImageEditOperation,
        contextKey: String
    ) -> [A2uiMessage] {
        let surfaceId = "\(surfacePrefix)_\(UUID().uuidString)"
        return [
            .createSurface(CreateSurfacePayload(
                surfaceId: surfaceId,
                catalogId: basicCatalogId,
                sendDataModel: true
            )),
            .updateDataModel(UpdateDataModelPayload(
                surfaceId: surfaceId,
                path: path,
                value: .array([.string(initialValue)])
            )),
            .updateComponents(UpdateComponentsPayload(
                surfaceId: surfaceId,
                components: [
                    component("root", "Card", ["child": .string("content")]),
                    component("content", "Column", [
                        "children": .array(["title", "body", "picker", "apply_button"].map(AnyCodable.string)),
                        "align": .string("stretch"),
                    ]),
                    component("title", "Text", [
                        "text": .string(title),
                        "variant": .string("h3"),
                    ]),
                    component("body", "Text", [
                        "text": .string(body),
                    ]),
                    component("picker", "ChoicePicker", [
                        "label": .string(label),
                        "options": .array(options.map {
                            .dictionary([
                                "label": .string($0.0),
                                "value": .string($0.1),
                            ])
                        }),
                        "value": dataBinding(path),
                        "displayStyle": .string("chips"),
                        "variant": .string("mutuallyExclusive"),
                    ]),
                    button(
                        "apply_button",
                        titleId: "apply_button_text",
                        title: buttonTitle,
                        operation: operation,
                        contextKey: contextKey,
                        valuePath: path
                    ),
                    text("apply_button_text", buttonTitle),
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
        contextKey: String? = nil,
        valuePath: String? = nil
    ) -> RawComponent {
        var context: [String: AnyCodable] = [
            "operation": .string(operation.rawValue),
        ]
        if let contextKey, let valuePath {
            context[contextKey] = dataBinding(valuePath)
        }
        return component(id, "Button", [
            "child": .string(titleId),
            "variant": .string("primary"),
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
