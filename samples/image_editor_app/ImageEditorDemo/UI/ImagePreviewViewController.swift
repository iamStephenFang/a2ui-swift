import UIKit

final class ImagePreviewViewController: UIViewController {
    private let image: UIImage
    private let caption: String?
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let captionLabel = UILabel()
    private let captionBackground = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))

    init(image: UIImage, title: String? = nil, caption: String? = nil) {
        self.image = image
        self.caption = caption
        super.init(nibName: nil, bundle: nil)
        self.title = title ?? "Preview"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareTapped)
        )
        configureLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateZoomScale()
        centerImage()
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .black
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = true

        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)

        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.font = .preferredFont(forTextStyle: .subheadline)
        captionLabel.textColor = .white
        captionLabel.numberOfLines = 0
        captionLabel.text = caption

        captionBackground.translatesAutoresizingMaskIntoConstraints = false
        captionBackground.layer.cornerRadius = 16
        captionBackground.layer.cornerCurve = .continuous
        captionBackground.clipsToBounds = true
        captionBackground.isHidden = caption?.isEmpty ?? true
        captionBackground.contentView.addSubview(captionLabel)

        view.addSubview(scrollView)
        view.addSubview(captionBackground)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            captionBackground.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            captionBackground.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            captionBackground.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            captionLabel.leadingAnchor.constraint(equalTo: captionBackground.contentView.leadingAnchor, constant: 14),
            captionLabel.trailingAnchor.constraint(equalTo: captionBackground.contentView.trailingAnchor, constant: -14),
            captionLabel.topAnchor.constraint(equalTo: captionBackground.contentView.topAnchor, constant: 12),
            captionLabel.bottomAnchor.constraint(equalTo: captionBackground.contentView.bottomAnchor, constant: -12),
        ])
    }

    private func updateZoomScale() {
        guard image.size.width > 0, image.size.height > 0 else { return }

        let availableSize = scrollView.bounds.size
        guard availableSize.width > 0, availableSize.height > 0 else { return }

        let widthScale = availableSize.width / image.size.width
        let heightScale = availableSize.height / image.size.height
        let fittingScale = min(widthScale, heightScale)
        scrollView.minimumZoomScale = fittingScale
        scrollView.maximumZoomScale = max(fittingScale * 4, 4)

        if scrollView.zoomScale == 1 || scrollView.zoomScale < fittingScale {
            scrollView.zoomScale = fittingScale
        }

        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size
    }

    private func centerImage() {
        let horizontalInset = max((scrollView.bounds.width - scrollView.contentSize.width * scrollView.zoomScale) / 2, 0)
        let verticalInset = max((scrollView.bounds.height - scrollView.contentSize.height * scrollView.zoomScale) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            return
        }

        let location = recognizer.location(in: imageView)
        let targetScale = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.5)
        let width = scrollView.bounds.width / targetScale
        let height = scrollView.bounds.height / targetScale
        let zoomRect = CGRect(
            x: location.x - width / 2,
            y: location.y - height / 2,
            width: width,
            height: height
        )
        scrollView.zoom(to: zoomRect, animated: true)
    }

    @objc private func shareTapped() {
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(activity, animated: true)
    }
}

extension ImagePreviewViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }
}
