//
//  TextureManager.swift
//  GLTest
//
//  Created by chenjie.starry on 2024/3/5.
//

import Foundation
import OpenGLES
import UIKit
import CoreGraphics

internal class TextureManager {
    internal static let shared = TextureManager()

    internal static func loadImage(name: String) -> GLuint {
        guard let image = UIImage(named: name),
              let cgImage = image.cgImage else {
            return 0
        }
        
        let imageWidth = Int(image.size.width)
        let imageHeight = Int(image.size.height)
        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: imageWidth * imageHeight * 4)
        rawData.initialize(to: 0)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(data: rawData, width: imageWidth, height: imageHeight, bitsPerComponent: 8, 
                                      bytesPerRow: imageWidth * 4, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return 0
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        
        var textureId: GLuint = 0
        glGenTextures(1, &textureId)
        glBindTexture(GLenum(GL_TEXTURE_2D), textureId)
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, GLsizei(imageWidth), GLsizei(imageHeight), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), rawData)
        return textureId
    }
}
