import UIKit

final class ChatBubbleView: UIView {
    init(text: String, isUser: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.text = text
        label.textColor = isUser ? .white : .label

        let bubble = UIView()
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.backgroundColor = isUser ? .systemBlue : .secondarySystemGroupedBackground
        bubble.layer.cornerRadius = 18
        bubble.layer.cornerCurve = .continuous
        bubble.addSubview(label)

        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .top
        row.addArrangedSubview(isUser ? UIView() : bubble)
        row.addArrangedSubview(isUser ? bubble : UIView())
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.78),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ImageMessageCardView: UIView {
    private let onPreview: (() -> Void)?

    convenience init(text: String, image: UIImage, isUser: Bool, onPreview: (() -> Void)? = nil) {
        self.init(title: nil, detail: text, image: image, isUser: isUser, onPreview: onPreview)
    }

    init(title: String?, detail: String, image: UIImage, isUser: Bool, onPreview: (() -> Void)? = nil) {
        self.onPreview = onPreview
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 14
        imageView.layer.cornerCurve = .continuous
        imageView.isUserInteractionEnabled = onPreview != nil
        if onPreview != nil {
            imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(previewTapped)))
        }
        let imageRatio = image.size.width > 0 ? image.size.height / image.size.width : 1
        let displayRatio = min(max(imageRatio, 0.56), 1.35)

        let textStack = UIStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 4

        if let title {
            let titleLabel = UILabel()
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.numberOfLines = 0
            titleLabel.font = .preferredFont(forTextStyle: .headline)
            titleLabel.text = title
            titleLabel.textColor = isUser ? .white : .label
            textStack.addArrangedSubview(titleLabel)
        }

        let detailLabel = UILabel()
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.numberOfLines = 0
        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.text = detail
        detailLabel.textColor = isUser ? .white : .label
        textStack.addArrangedSubview(detailLabel)

        let content = UIStackView(arrangedSubviews: [imageView, textStack])
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 10
        content.alignment = .fill

        let bubble = UIView()
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.backgroundColor = isUser ? .systemBlue : .secondarySystemGroupedBackground
        bubble.layer.cornerRadius = 20
        bubble.layer.cornerCurve = .continuous
        bubble.addSubview(content)

        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .top
        row.addArrangedSubview(isUser ? UIView() : bubble)
        row.addArrangedSubview(isUser ? bubble : UIView())
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.78),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: displayRatio),
            content.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 10),
            content.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -10),
            content.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            content.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func previewTapped() {
        onPreview?()
    }
}
