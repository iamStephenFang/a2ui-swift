import A2UISwiftCore
import A2UIUIKit
import UIKit

final class ImageEditorA2UICoordinator {
    private let processor: MessageProcessor
    private var actionSubscriptions: [String: Subscription] = [:]
    private var surfaceCreatedSubscription: Subscription?
    private let onAction: (A2uiClientAction) -> Void

    init(onAction: @escaping (A2uiClientAction) -> Void) {
        self.onAction = onAction
        self.processor = MessageProcessor(catalogs: [basicCatalog])
        self.surfaceCreatedSubscription = processor.onSurfaceCreated { [weak self] surface in
            self?.subscribeToActions(on: surface)
        }
    }

    func render(messages: [A2uiMessage]) -> [UIView] {
        let newSurfaceIds = messages.compactMap { message -> String? in
            if case .createSurface(let payload) = message {
                return payload.surfaceId
            }
            return nil
        }

        _ = processor.processMessages(messages)

        return newSurfaceIds.compactMap { surfaceId in
            guard let surface = processor.model.getSurface(surfaceId),
                  surface.componentsModel.get("root") != nil
            else { return nil }
            let host = A2UISurfaceHostView()
            host.translatesAutoresizingMaskIntoConstraints = false
            host.render(surface: surface, rootComponentId: "root")
            return host
        }
    }

    private func subscribeToActions(on surface: SurfaceModel) {
        actionSubscriptions[surface.id]?.unsubscribe()
        actionSubscriptions[surface.id] = surface.onAction.subscribe { [weak self] action in
            self?.onAction(action)
        }
    }
}
