import UIKit

final class ImageEditorSettingsViewController: UITableViewController {
    var onAPIKeyChanged: (() -> Void)?

    private let keyField = UITextField()
    private let currentKey: String

    init(currentKey: String) {
        self.currentKey = currentKey
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )

        keyField.placeholder = "Volcengine Ark API Key"
        keyField.text = currentKey
        keyField.isSecureTextEntry = true
        keyField.autocorrectionType = .no
        keyField.autocapitalizationType = .none
        keyField.clearButtonMode = .whileEditing
        keyField.textContentType = .password
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : 2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Volcengine Ark" : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else { return nil }
        return "Priority: key entered here, then ARK_API_KEY from the environment. The sample uses the OpenAI-compatible chat completions endpoint."
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)

        if indexPath.section == 0 {
            cell.contentView.addSubview(keyField)
            keyField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                keyField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                keyField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                keyField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                keyField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
                keyField.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            ])
        } else if indexPath.row == 0 {
            cell.textLabel?.text = "Model"
            cell.detailTextLabel?.text = "deepseek-v4-flash-260425"
            cell.selectionStyle = .none
        } else {
            cell.textLabel?.text = "Clear Custom Key"
            cell.textLabel?.textColor = .systemRed
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1, indexPath.row == 1 else { return }
        keyField.text = ""
        UserDefaults.standard.removeObject(forKey: "arkAPIKey")
        onAPIKeyChanged?()
    }

    @objc private func saveTapped() {
        let trimmed = keyField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: "arkAPIKey")
        } else {
            UserDefaults.standard.set(trimmed, forKey: "arkAPIKey")
        }
        onAPIKeyChanged?()
        dismiss(animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
