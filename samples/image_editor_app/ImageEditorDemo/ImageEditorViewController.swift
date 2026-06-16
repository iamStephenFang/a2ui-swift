import A2UISwiftCore
import PhotosUI
import UIKit

final class ImageEditorViewController: UIViewController {
    private let editingService = ImageEditingService()
    private lazy var a2uiCoordinator = ImageEditorA2UICoordinator { [weak self] action in
        self?.handleA2UIAction(action)
    }
    private var chatClient = VolcengineChatClient(apiKey: APIKeyResolver.resolveArkAPIKey())
    private var pendingSelectedImage: UIImage?

    private let scrollView = UIScrollView()
    private let messageStack = UIStackView()
    private let inputTextView = UITextView()
    private let inputPlaceholderLabel = UILabel()
    private let selectedImagePreview = UIImageView()
    private let selectImageButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private let inputBarBackground = UIVisualEffectView(effect: ImageEditorViewController.makeGlassEffect(
        fallbackStyle: .systemUltraThinMaterial,
        tintColor: UIColor.systemBackground.withAlphaComponent(0.08)
    ))

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Image Editor"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        configureLayout()
        addAssistantMessage("Choose an image from the bottom bar, then ask for a filter, brightness change, square crop, or reset.")
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive

        messageStack.translatesAutoresizingMaskIntoConstraints = false
        messageStack.axis = .vertical
        messageStack.spacing = 12
        messageStack.alignment = .fill

        selectedImagePreview.translatesAutoresizingMaskIntoConstraints = false
        selectedImagePreview.contentMode = .scaleAspectFill
        selectedImagePreview.clipsToBounds = true
        selectedImagePreview.layer.cornerRadius = 12
        selectedImagePreview.layer.cornerCurve = .continuous
        selectedImagePreview.isHidden = true
        selectedImagePreview.isUserInteractionEnabled = true
        selectedImagePreview.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(selectedPreviewTapped)))

        selectImageButton.translatesAutoresizingMaskIntoConstraints = false
        selectImageButton.setImage(UIImage(systemName: "photo.badge.plus"), for: .normal)
        selectImageButton.tintColor = .label
        selectImageButton.backgroundColor = .tertiarySystemFill
        selectImageButton.layer.cornerRadius = 18
        selectImageButton.layer.cornerCurve = .continuous
        selectImageButton.addTarget(self, action: #selector(selectImageTapped), for: .touchUpInside)

        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputTextView.backgroundColor = .clear
        inputTextView.font = .preferredFont(forTextStyle: .body)
        inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        inputTextView.textContainer.lineFragmentPadding = 0
        inputTextView.returnKeyType = .default
        inputTextView.delegate = self
        inputTextView.isScrollEnabled = false

        inputPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        inputPlaceholderLabel.text = "Describe the edit..."
        inputPlaceholderLabel.font = .preferredFont(forTextStyle: .body)
        inputPlaceholderLabel.textColor = .placeholderText
        inputTextView.addSubview(inputPlaceholderLabel)

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold),
            forImageIn: .normal
        )
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        let inputTextContainer = UIView()
        inputTextContainer.translatesAutoresizingMaskIntoConstraints = false
        inputTextContainer.backgroundColor = .secondarySystemFill
        inputTextContainer.layer.cornerRadius = 18
        inputTextContainer.layer.cornerCurve = .continuous
        inputTextContainer.addSubview(inputTextView)

        let inputBar = UIStackView(arrangedSubviews: [selectedImagePreview, selectImageButton, inputTextContainer, sendButton])
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        inputBar.axis = .horizontal
        inputBar.spacing = 8
        inputBar.alignment = .bottom
        inputBar.isLayoutMarginsRelativeArrangement = true
        inputBar.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        inputBarBackground.translatesAutoresizingMaskIntoConstraints = false
        inputBarBackground.layer.cornerRadius = 28
        inputBarBackground.layer.cornerCurve = .continuous
        inputBarBackground.clipsToBounds = true
        inputBarBackground.contentView.addSubview(inputBar)

        view.addSubview(scrollView)
        view.addSubview(inputBarBackground)
        scrollView.addSubview(messageStack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: inputBarBackground.topAnchor, constant: -10),

            messageStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            messageStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            messageStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            messageStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            messageStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            inputBarBackground.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 10),
            inputBarBackground.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -10),
            inputBarBackground.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),

            inputBar.leadingAnchor.constraint(equalTo: inputBarBackground.contentView.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: inputBarBackground.contentView.trailingAnchor),
            inputBar.topAnchor.constraint(equalTo: inputBarBackground.contentView.topAnchor),
            inputBar.bottomAnchor.constraint(equalTo: inputBarBackground.contentView.bottomAnchor),

            selectedImagePreview.widthAnchor.constraint(equalToConstant: 42),
            selectedImagePreview.heightAnchor.constraint(equalToConstant: 42),
            selectImageButton.widthAnchor.constraint(equalToConstant: 36),
            selectImageButton.heightAnchor.constraint(equalToConstant: 36),
            sendButton.widthAnchor.constraint(equalToConstant: 40),
            sendButton.heightAnchor.constraint(equalToConstant: 40),

            inputTextView.leadingAnchor.constraint(equalTo: inputTextContainer.leadingAnchor, constant: 12),
            inputTextView.trailingAnchor.constraint(equalTo: inputTextContainer.trailingAnchor, constant: -12),
            inputTextView.topAnchor.constraint(equalTo: inputTextContainer.topAnchor, constant: 2),
            inputTextView.bottomAnchor.constraint(equalTo: inputTextContainer.bottomAnchor, constant: -2),
            inputTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            inputTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 96),

            inputPlaceholderLabel.leadingAnchor.constraint(equalTo: inputTextView.leadingAnchor),
            inputPlaceholderLabel.topAnchor.constraint(equalTo: inputTextView.topAnchor, constant: 8),
        ])
    }

    private static func makeGlassEffect(
        fallbackStyle: UIBlurEffect.Style,
        tintColor: UIColor
    ) -> UIVisualEffect {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.isInteractive = true
            effect.tintColor = tintColor
            return effect
        }
        return UIBlurEffect(style: fallbackStyle)
    }

    @objc private func sendTapped() {
        let text = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || pendingSelectedImage != nil else { return }

        let selectedImage = pendingSelectedImage
        inputTextView.text = ""
        pendingSelectedImage = nil
        selectedImagePreview.image = nil
        selectedImagePreview.isHidden = true
        inputPlaceholderLabel.isHidden = false

        let prompt = text.isEmpty ? "Edit this image." : text
        if let selectedImage {
            editingService.replaceImage(selectedImage)
            addUserMessage(prompt, image: selectedImage)
        } else {
            addUserMessage(prompt)
        }
        handleUserRequest(prompt)
    }

    private func handleUserRequest(_ text: String) {
        guard editingService.hasImage else {
            addAssistantMessage("Select an image first, then I can apply local edits or suggest one.")
            return
        }

        let lowered = text.lowercased()
        if lowered.contains("reset") || lowered.contains("还原") || lowered.contains("重置") {
            apply(operation: .reset)
            return
        }
        if let filter = ImageFilter.allCases.first(where: { lowered.contains($0.rawValue) || lowered.contains($0.title.lowercased()) }) {
            apply(operation: .filter, filter: filter)
            return
        }
        if lowered.contains("filter") || lowered.contains("滤镜") {
            addAssistantMessage("Pick a filter style for this image.")
            renderA2UISurfaces(ImageEditorA2UIContent.filterCard())
            return
        }
        if let brightness = brightnessLevel(in: lowered) {
            apply(operation: .brightness, brightness: brightness)
            return
        }
        if lowered.contains("bright") || lowered.contains("亮") || lowered.contains("曝光") {
            addAssistantMessage("Choose a brightness level.")
            renderA2UISurfaces(ImageEditorA2UIContent.brightnessCard())
            return
        }
        if let cropRatio = cropRatio(in: lowered) {
            apply(operation: .crop, cropRatio: cropRatio)
            return
        }
        if lowered.contains("crop") || lowered.contains("裁剪") {
            addAssistantMessage("Choose a crop ratio.")
            renderA2UISurfaces(ImageEditorA2UIContent.cropCard())
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                if let response = try await chatClient.generateAssistantText(for: text) {
                    await MainActor.run {
                        self.addAssistantMessage(response)
                    }
                } else {
                    await MainActor.run {
                        self.addAssistantMessage("I can apply filters, brighten the image, crop it square, or reset it.")
                    }
                }
            } catch {
                await MainActor.run {
                    self.addAssistantMessage("Ark request failed: \(error.localizedDescription)")
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
        let brightness = selectedBrightness(from: action.context["brightness"])
        let cropRatio = selectedCropRatio(from: action.context["cropRatio"])
        apply(operation: operation, filter: filter, brightness: brightness, cropRatio: cropRatio)
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

    private func selectedBrightness(from value: AnyCodable?) -> BrightnessLevel? {
        selectedString(from: value).flatMap(BrightnessLevel.init(rawValue:))
    }

    private func selectedCropRatio(from value: AnyCodable?) -> ImageCropRatio? {
        selectedString(from: value).flatMap(ImageCropRatio.init(rawValue:))
    }

    private func selectedString(from value: AnyCodable?) -> String? {
        guard let value else { return nil }
        if let string = value.stringValue {
            return string
        }
        return value.arrayValue?.first?.stringValue
    }

    private func brightnessLevel(in lowered: String) -> BrightnessLevel? {
        if lowered.contains("strong") || lowered.contains("more") || lowered.contains("高") || lowered.contains("强") {
            return .strong
        }
        if lowered.contains("subtle") || lowered.contains("slight") || lowered.contains("low") || lowered.contains("低") || lowered.contains("轻微") {
            return .subtle
        }
        return nil
    }

    private func cropRatio(in lowered: String) -> ImageCropRatio? {
        if lowered.contains("square") || lowered.contains("1:1") || lowered.contains("正方") {
            return .square
        }
        if lowered.contains("4:5") || lowered.contains("portrait") || lowered.contains("竖") {
            return .portrait
        }
        if lowered.contains("4:3") || lowered.contains("landscape") || lowered.contains("横") {
            return .landscape
        }
        if lowered.contains("16:9") || lowered.contains("wide") || lowered.contains("宽屏") {
            return .widescreen
        }
        return nil
    }

    private func apply(
        operation: ImageEditOperation,
        filter: ImageFilter? = nil,
        brightness: BrightnessLevel? = nil,
        cropRatio: ImageCropRatio? = nil
    ) {
        guard let result = editingService.apply(
            operation: operation,
            filter: filter,
            brightness: brightness,
            cropRatio: cropRatio
        ) else {
            addAssistantMessage("Select an image first, then choose an edit.")
            return
        }
        addAssistantMessage(result: result)
    }

    private func addUserMessage(_ text: String) {
        append(ChatBubbleView(text: text, isUser: true))
    }

    private func addUserMessage(_ text: String, image: UIImage) {
        append(ImageMessageCardView(text: text, image: image, isUser: true) { [weak self] in
            self?.showImagePreview(image: image, title: "Selected Image", caption: text)
        })
    }

    private func addAssistantMessage(_ text: String) {
        append(ChatBubbleView(text: text, isUser: false))
    }

    private func addAssistantMessage(result: ImageEditResult) {
        append(ImageMessageCardView(
            title: result.title,
            detail: result.detail,
            image: result.image,
            isUser: false
        ) { [weak self] in
            self?.showImagePreview(image: result.image, title: result.title, caption: result.detail)
        })
    }

    @objc private func selectImageTapped() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func settingsTapped() {
        let settings = ImageEditorSettingsViewController(
            currentKey: UserDefaults.standard.string(forKey: "arkAPIKey") ?? ""
        )
        settings.onAPIKeyChanged = { [weak self] in
            self?.chatClient.apiKey = APIKeyResolver.resolveArkAPIKey()
        }
        let navigationController = UINavigationController(rootViewController: settings)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    @objc private func selectedPreviewTapped() {
        guard let image = pendingSelectedImage else { return }
        showImagePreview(image: image, title: "Selected Image", caption: "This image is ready to send with your next edit request.")
    }

    private func showImagePreview(image: UIImage, title: String? = nil, caption: String? = nil) {
        let preview = ImagePreviewViewController(image: image, title: title, caption: caption)
        navigationController?.pushViewController(preview, animated: true)
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

extension ImageEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        inputPlaceholderLabel.isHidden = !textView.text.isEmpty
        UIView.performWithoutAnimation {
            view.layoutIfNeeded()
        }
        scrollToBottom()
    }
}

extension ImageEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self)
        else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            Task { @MainActor in
                self.pendingSelectedImage = image
                self.selectedImagePreview.image = image
                self.selectedImagePreview.isHidden = false
            }
        }
    }
}
