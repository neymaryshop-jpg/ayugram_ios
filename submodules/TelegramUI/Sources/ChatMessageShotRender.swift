import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import SGSimpleSettings

// MARK: Swiftgram — message shot: рендер сообщения в изображение
// (AyuGram: ayu/features/message_shot/message_shot.cpp: removeEmptySpaceAround / addPadding / makeDefaultBackgroundColor)

public final class ChatMessageShotRender {
    private static let shotPadding: CGFloat = 12.0

    public static func render(node: ASDisplayNode, theme: PresentationTheme) -> UIImage? {
        let view = node.view
        let bounds = view.bounds
        guard bounds.width > 0.0, bounds.height > 0.0 else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale

        let rendered = UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            view.layer.render(in: context.cgContext)
        }

        guard let cropped = Self.cropTransparentBorders(from: rendered) else {
            return nil
        }

        let padding = Self.shotPadding * format.scale
        let paddedSize = CGSize(width: cropped.size.width + padding * 2.0, height: cropped.size.height + padding * 2.0)
        let padded = UIGraphicsImageRenderer(size: paddedSize, format: format).image { context in
            cropped.draw(at: CGPoint(x: padding, y: padding))
        }

        if !SGSimpleSettings.shared.messageShotShowBackground {
            return padded
        }

        // фон: аналог makeDefaultBackgroundColor (тёмная тема — светлее фона, светлая — темнее)
        let backgroundColor: UIColor
        if theme.overallDarkAppearance {
            backgroundColor = UIColor(white: 0.22, alpha: 1.0)
        } else {
            backgroundColor = UIColor(white: 0.93, alpha: 1.0)
        }
        return UIGraphicsImageRenderer(size: paddedSize, format: format).image { context in
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: paddedSize))
            padded.draw(at: .zero)
        }
    }

    private static func cropTransparentBorders(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else {
            return image
        }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            return image
        }
        guard let dataProvider = cgImage.dataProvider, let data = dataProvider.data, let ptr = CFDataGetBytePtr(data) else {
            return image
        }
        let bytesPerRow = cgImage.bytesPerRow
        let bitsPerPixel = cgImage.bitsPerPixel
        let bytesPerPixel = max(1, bitsPerPixel / 8)
        guard bitsPerPixel == 32 || bitsPerPixel == 64 else {
            return image
        }

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        for y in 0 ..< height {
            for x in 0 ..< width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = ptr[offset + bytesPerPixel - 1]
                if alpha != 0 {
                    if x < minX {
                        minX = x
                    }
                    if x > maxX {
                        maxX = x
                    }
                    if y < minY {
                        minY = y
                    }
                    if y > maxY {
                        maxY = y
                    }
                }
            }
        }
        guard minX <= maxX, minY <= maxY else {
            return image
        }
        let rect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = cgImage.cropping(to: rect) else {
            return image
        }
        return UIImage(cgImage: cropped)
    }
}