import A2UISwiftCore
import UIKit

final class ImageEditorViewController: UIViewController {
    private let editingService = ImageEditingService()
    private lazy var a2uiCoordinator = ImageEditorA2UICoordinator { [weak self] action in
        self?.handleA2UIAction(action)
    }
    private let chatClient = VolcengineChatClient(apiKey: APIKeyResolver.resolveArkAPIKey())

    private let imageView = UIImageView()
    private let scrollView = UIScrollView()
    private let messageStack = UIStackView()
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "A2UI Image Editor"
        view.backgroundColor = .systemGroupedBackground
        configureLayout()
        updatePreview(editingService.currentImage)
        addAssistantMessage("Try a local edit, or ask for a quick adjustment. A2UI renders the cards and controls below.")
        renderA2UISurfaces(ImageEditorA2UIContent.controlCard())
    }

    private func configureLayout() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .secondarySystemGroupedBackground
        imageView.layer.cornerRadius = 18
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive

        messageStack.translatesAutoresizingMaskIntoConstraints = false
        messageStack.axis = .vertical
        messageStack.spacing = 10
        messageStack.alignment = .fill

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.placeholder = "Ask for a filter, brighten, square crop..."
        inputField.borderStyle = .roundedRect
        inputField.returnKeyType = .send
        inputField.delegate = self

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold),
            forImageIn: .normal
        )
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        let inputBar = UIStackView(arrangedSubviews: [inputField, sendButton])
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        inputBar.axis = .horizontal
        inputBar.spacing = 10
        inputBar.alignment = .center
        inputBar.isLayoutMarginsRelativeArrangement = true
        inputBar.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        inputBar.backgroundColor = .systemBackground

        view.addSubview(imageView)
        view.addSubview(scrollView)
        view.addSubview(inputBar)
        scrollView.addSubview(messageStack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.30),

            scrollView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),

            messageStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            messageStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            messageStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            messageStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            messageStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 40),
            sendButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    @objc private func sendTapped() {
        let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return }
        inputField.text = ""
        addUserMessage(text)
        handleUserRequest(text)
    }

    private func handleUserRequest(_ text: String) {
        let lowered = text.lowercased()
        if lowered.contains("crop") || lowered.contains("square") || lowered.contains("裁剪") {
            apply(operation: .squareCrop)
            return
        }
        if lowered.contains("bright") || lowered.contains("亮") || lowered.contains("曝光") {
            apply(operation: .brighten)
            return
        }
        if lowered.contains("reset") || lowered.contains("还原") || lowered.contains("重置") {
            apply(operation: .reset)
            return
        }
        if let filter = ImageFilter.allCases.first(where: { lowered.contains($0.rawValue) || lowered.contains($0.title.lowercased()) }) {
            apply(operation: .filter, filter: filter)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                if let response = try await chatClient.generateAssistantText(for: text) {
                    await MainActor.run {
                        self.addAssistantMessage(response)
                        self.renderA2UISurfaces(ImageEditorA2UIContent.controlCard())
                    }
                } else {
                    await MainActor.run {
                        self.addAssistantMessage("I can apply filters, brighten the image, crop it square, or reset it.")
                        self.renderA2UISurfaces(ImageEditorA2UIContent.controlCard())
                    }
                }
            } catch {
                await MainActor.run {
                    self.addAssistantMessage("Ark request failed: \(error.localizedDescription)")
                    self.renderA2UISurfaces(ImageEditorA2UIContent.controlCard())
                }
            }
        }
    }

    private func handleA2UIAction(_ action: A2uiClientAction) {
        guard action.name == "applyEdit",
              let operationValue = action.context["operation"]?.stringValue,
              let operation = ImageEditOperation(rawValue: operationValue)
        else { return }

        let filter = selectedFilter(from: action.context["filter"])
        apply(operation: operation, filter: filter)
    }

    private func selectedFilter(from value: AnyCodable?) -> ImageFilter? {
        guard let value else { return nil }
        if let string = value.stringValue {
            return ImageFilter(rawValue: string)
        }
        if let first = value.arrayValue?.first?.stringValue {
            return ImageFilter(rawValue: first)
        }
        return nil
    }

    private func apply(operation: ImageEditOperation, filter: ImageFilter? = nil) {
        let result = editingService.apply(operation: operation, filter: filter)
        updatePreview(result.image)
        addAssistantMessage(result.title)
        renderA2UISurfaces(ImageEditorA2UIContent.resultCard(result: result))
    }

    private func updatePreview(_ image: UIImage) {
        imageView.image = image
    }

    private func addUserMessage(_ text: String) {
        append(ChatBubbleView(text: text, isUser: true))
    }

    private func addAssistantMessage(_ text: String) {
        append(ChatBubbleView(text: text, isUser: false))
    }

    private func renderA2UISurfaces(_ messages: [A2uiMessage]) {
        for surface in a2uiCoordinator.render(messages: messages) {
            let wrapper = UIView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            wrapper.backgroundColor = .clear
            wrapper.addSubview(surface)
            NSLayoutConstraint.activate([
                surface.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                surface.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                surface.topAnchor.constraint(equalTo: wrapper.topAnchor),
                surface.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            ])
            append(wrapper)
        }
    }

    private func append(_ view: UIView) {
        messageStack.addArrangedSubview(view)
        scrollToBottom()
    }

    private func scrollToBottom() {
        view.layoutIfNeeded()
        let bottomOffset = CGPoint(
            x: 0,
            y: max(-scrollView.adjustedContentInset.top, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        )
        scrollView.setContentOffset(bottomOffset, animated: true)
    }
}

extension ImageEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}
