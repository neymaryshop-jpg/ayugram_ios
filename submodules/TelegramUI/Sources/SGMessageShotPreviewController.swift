import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

// MARK: Swiftgram — message shot: превью с кнопками «Поделиться» / «Сохранить»
// (AyuGram: ayu/ui/boxes/message_shot_box.cpp)

public final class SGMessageShotPreviewController: ViewController {
    private let shotImage: UIImage
    private let theme: PresentationTheme
    private let strings: PresentationStrings

    private var imageNode: ASImageNode?
    private var shareButtonNode: HighlightableButtonNode?
    private var saveButtonNode: HighlightableButtonNode?
    private var closeButtonNode: HighlightableButtonNode?
    private var didSave = false

    public init(image: UIImage, theme: PresentationTheme, strings: PresentationStrings) {
        self.shotImage = image
        self.theme = theme
        self.strings = strings
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .White
        self.blocksBackgroundWhenInOverlay = true
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
    }

    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()

        let node = ASDisplayNode()
        node.backgroundColor = UIColor(white: 0.0, alpha: 0.85)
        self.displayNode = node

        let imageNode = ASImageNode()
        imageNode.image = self.shotImage
        imageNode.contentMode = .scaleAspectFit
        node.addSubnode(imageNode)
        self.imageNode = imageNode

        let shareButtonNode = HighlightableButtonNode()
        shareButtonNode.setTitle(self.strings.Conversation_ContextMenuShare, with: Font.medium(17.0), with: self.theme.list.itemAccentColor, for: [])
        node.addSubnode(shareButtonNode)
        self.shareButtonNode = shareButtonNode

        let saveButtonNode = HighlightableButtonNode()
        saveButtonNode.setTitle(self.strings.Common_Save, with: Font.medium(17.0), with: self.theme.list.itemAccentColor, for: [])
        node.addSubnode(saveButtonNode)
        self.saveButtonNode = saveButtonNode

        let closeButtonNode = HighlightableButtonNode()
        closeButtonNode.setTitle(self.strings.Common_Close, with: Font.regular(17.0), with: self.theme.list.itemSecondaryTextColor, for: [])
        node.addSubnode(closeButtonNode)
        self.closeButtonNode = closeButtonNode

        shareButtonNode.addTarget(self, action: #selector(self.sharePressed), forControlEvents: .touchUpInside)
        saveButtonNode.addTarget(self, action: #selector(self.savePressed), forControlEvents: .touchUpInside)
        closeButtonNode.addTarget(self, action: #selector(self.closePressed), forControlEvents: .touchUpInside)
    }

    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        guard let node = self.displayNode as? ASDisplayNode, let imageNode = self.imageNode else {
            return
        }

        let insets = layout.insets(options: [.input])
        let bottomInset: CGFloat = 12.0 + insets.bottom
        let buttonHeight: CGFloat = 50.0
        let safeWidth = layout.size.width - 32.0
        let availableHeight = layout.size.height - insets.top - bottomInset - buttonHeight * 3.0 - 40.0

        let imageSize = self.shotImage.size
        var fitSize = imageSize
        if imageSize.width > safeWidth || imageSize.height > availableHeight {
            let scale = min(safeWidth / imageSize.width, availableHeight / imageSize.height)
            fitSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        }
        let imageFrame = CGRect(origin: CGPoint(x: (layout.size.width - fitSize.width) / 2.0, y: insets.top + 20.0), size: fitSize)
        transition.updateFrame(node: imageNode, frame: imageFrame)

        var y = imageFrame.maxY + 20.0
        if let shareButtonNode = self.shareButtonNode {
            transition.updateFrame(node: shareButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: y), size: CGSize(width: layout.size.width, height: buttonHeight)))
            y += buttonHeight
        }
        if let saveButtonNode = self.saveButtonNode {
            transition.updateFrame(node: saveButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: y), size: CGSize(width: layout.size.width, height: buttonHeight)))
            y += buttonHeight
        }
        if let closeButtonNode = self.closeButtonNode {
            transition.updateFrame(node: closeButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: y), size: CGSize(width: layout.size.width, height: buttonHeight)))
        }
    }

    @objc private func sharePressed() {
        let activityController = UIActivityViewController(activityItems: [self.shotImage], applicationActivities: nil)
        if let window = self.view.window {
            activityController.popoverPresentationController?.sourceView = window
            activityController.popoverPresentationController?.sourceRect = CGRect(origin: window.center, size: .zero)
        }
        self.present(activityController, animated: true, completion: nil)
    }

    @objc private func savePressed() {
        guard !self.didSave else {
            return
        }
        self.didSave = true
        UIImageWriteToSavedPhotosAlbum(self.shotImage, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func closePressed() {
        self.dismiss()
    }

    @objc private func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        self.didSave = false
        if let error = error {
            let alertController = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: self.strings.Common_OK, style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        } else {
            self.present(self.makeSavedAlert(), animated: true, completion: nil)
        }
    }

    private func makeSavedAlert() -> UIAlertController {
        let alertController = UIAlertController(title: self.strings.MessageShot_SavedTitle, message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: self.strings.Common_OK, style: .default, handler: nil))
        return alertController
    }
}