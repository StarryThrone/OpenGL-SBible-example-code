//
//  TextureManager.swift
//  CubeEnvironmentMap
//
//  Created by chenjie on 2019/11/23.
//  Copyright © 2019 chenjie. All rights reserved.
//

import Foundation
import GLKit

// 纹理文件头部信息大小为64个字节，前12个字节用于存储文件标识，后52字节存储了13个属性，分别对应结构体SB6TextureFileHeader的endianness后的属性
let SB6TextureFileHeaderIdentifierLength = 12
let SB6TextureFileHeaderSize = 64

fileprivate extension String {
    // 通过C语言的字符串数据创建String
    static func fromCString(address dataAddress: UnsafeRawPointer, count: UInt) -> String {
        let stringCollectionAddress = dataAddress.bindMemory(to: UInt8.self, capacity: Int(count))
        let stringCollectionTypeAddress = UnsafeBufferPointer(start: stringCollectionAddress, count: Int(count))
        let stringCollectionData = Array(stringCollectionTypeAddress)
        var string = ""
        for index in 0..<Int(count) {
            let stringFragment = String(UnicodeScalar(stringCollectionData[index]))
            string = string + stringFragment
        }
        return string
    }
}

// 纹理文件的头结构
struct SB6TextureFileHeader {
    var identifier: String
    var endianness: UInt32
    var glType: UInt32
    var glTypeSize: UInt32
    var glFormat: UInt32
    var glInternalFormat: UInt32
    var glBaseInternalFormat: UInt32
    var pixelWidth: UInt32
    var pixelHeight: UInt32
    var pixelDepth: UInt32
    var arrayElements: UInt32
    var faces: UInt32
    var mipLevels: UInt32
    var keyPairBytes: UInt32
    
    init(contentOfData dataAddress: UnsafeRawPointer) {
        self.identifier = String.fromCString(address: dataAddress, count: 12)

        let collectionBaseDataAddress = dataAddress.advanced(by: SB6TextureFileHeaderIdentifierLength)
        let collectionBaseTypeDataAddress = collectionBaseDataAddress.bindMemory(to: UInt32.self, capacity: 13)
        let collectionDataAddress = UnsafeBufferPointer(start: collectionBaseTypeDataAddress, count: 13)
        let collectionData = Array(collectionDataAddress)
        self.endianness = collectionData[0]
        self.glType = collectionData[1]
        self.glTypeSize = collectionData[2]
        self.glFormat = collectionData[3]
        self.glInternalFormat = collectionData[4]
        self.glBaseInternalFormat = collectionData[5]
        self.pixelWidth = collectionData[6]
        self.pixelHeight = collectionData[7]
        self.pixelDepth = collectionData[8]
        self.arrayElements = collectionData[9]
        self.faces = collectionData[10]
        self.mipLevels = collectionData[11]
        self.keyPairBytes = collectionData[12]
    }
}

// KTX文件标识符
let kSB6TextureFileIdentifier: [UInt8] = [0xAB, 0x4B, 0x54, 0x58, 0x20, 0x31, 0x31, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A]

// 计算纹理的每行像素数据所占用的内存大小
// pad用于控制像素行对其方式，取1.2.4.8.16....，这样返回的数字一定为pad的整数倍
func memoryRowStrid(forFileHeader header: SB6TextureFileHeader, widthPixelCount: Int, pad: Int) -> Int {
    var channels = 0
    if header.glBaseInternalFormat == UInt32(GL_RED) {
        channels = 1
    } else if header.glBaseInternalFormat == UInt32(GL_RG) {
        channels = 2
    } else if header.glBaseInternalFormat == UInt32(GL_BGR) || header.glBaseInternalFormat == UInt32(GL_RG8) {
        channels = 3
    } else if header.glBaseInternalFormat == UInt32(GL_BGRA) || header.glBaseInternalFormat == UInt32(GL_RGBA) {
        channels = 4
    }
    
    var strid = Int(header.glTypeSize) * channels * widthPixelCount
    strid = (strid + (pad - 1)) & ~(pad - 1)
    return strid
}

// 计算立方体纹理的每个面的像素数据所占用的内存大小
func faceSize(forFileHeader header: SB6TextureFileHeader) -> Int {
    let stride = memoryRowStrid(forFileHeader: header, widthPixelCount: Int(header.pixelWidth), pad: 4)
    let faceSize = Int(header.pixelHeight) * stride
    return faceSize
}

class TextureManager {
    //MARK:- Public Properties
    static let shareManager = TextureManager()
    
    //MARK:- Public Methods
    func loadObject(fileName: String, toTexture texture: inout GLuint, atIndex index: Int32) -> Bool {
        guard let filePath = Bundle.main.path(forResource: fileName, ofType: nil) else { return false }
        guard let cFilePath = filePath.cString(using: .utf8) else { return false }
        let modeString = "rb".cString(using: .utf8)!
        // 1. 加载纹理文件
        let fp = fopen(cFilePath, modeString)
        if fp == nil {
            return false
        }
        // 读取纹理数据
        let headerDataAddress = UnsafeMutableRawPointer.allocate(byteCount: SB6TextureFileHeaderSize, alignment: 1)
        if fread(headerDataAddress, SB6TextureFileHeaderSize, 1, fp) != 1 {
            // 数据读取失败，直接返回
            return false
        }
        // 校验文件类型
        if memcmp(headerDataAddress, kSB6TextureFileIdentifier, MemoryLayout.size(ofValue: kSB6TextureFileIdentifier)) != 0 {
            // 文件类型校验失败时直接返回
            return false
        }
        
        // 2. 读取文件头
        var fileHeader = SB6TextureFileHeader(contentOfData: UnsafeRawPointer(headerDataAddress))
        // 根据需要在文件和内存中做大小端格式的转换
        if fileHeader.endianness == 0x04030201 {
            // 小端模式不用转换
        } else if fileHeader.endianness == 0x01020304 {
            fileHeader.endianness = CFSwapInt32(fileHeader.endianness)
            fileHeader.glType = CFSwapInt32(fileHeader.glType)
            fileHeader.glTypeSize = CFSwapInt32(fileHeader.glTypeSize)
            fileHeader.glFormat = CFSwapInt32(fileHeader.glFormat)
            fileHeader.glInternalFormat = CFSwapInt32(fileHeader.glInternalFormat)
            fileHeader.glBaseInternalFormat = CFSwapInt32(fileHeader.glBaseInternalFormat)
            fileHeader.pixelWidth = CFSwapInt32(fileHeader.pixelWidth)
            fileHeader.pixelHeight = CFSwapInt32(fileHeader.pixelHeight)
            fileHeader.pixelDepth = CFSwapInt32(fileHeader.pixelDepth)
            fileHeader.arrayElements = CFSwapInt32(fileHeader.arrayElements)
            fileHeader.faces = CFSwapInt32(fileHeader.faces)
            fileHeader.mipLevels = CFSwapInt32(fileHeader.mipLevels)
            fileHeader.keyPairBytes = CFSwapInt32(fileHeader.keyPairBytes)
        } else {
            //无法确定大小端模式，解析失败，直接返回
            return false
        }
        
        // 纹理宽度为0，纹理有深度但是无高度时都被认为是无效纹理（？）
        if fileHeader.pixelWidth == 0 || (fileHeader.pixelHeight == 0 && fileHeader.pixelDepth != 0) {
            return false
        }
        
        // 3. 确定纹理类型
        var target = GLenum(GL_NONE)
        if fileHeader.pixelHeight == 0 {
            if fileHeader.arrayElements == 0 {
                target = GLenum(GL_TEXTURE_1D)
            } else {
                target = GLenum(GL_TEXTURE_1D_ARRAY)
            }
        } else if fileHeader.pixelDepth == 0 {
            if fileHeader.arrayElements == 0 {
                if fileHeader.faces == 0 {
                    target = GLenum(GL_TEXTURE_2D)
                } else {
                    target = GLenum(GL_TEXTURE_CUBE_MAP)
                }
            } else {
                if fileHeader.faces == 0 {
                    target = GLenum(GL_TEXTURE_2D_ARRAY)
                } else {
                    target = GLenum(GL_TEXTURE_CUBE_MAP_ARRAY)
                }
            }
        } else {
            target = GLenum(GL_TEXTURE_3D)
        }
        
        // 4. 配置纹理对象
        if texture == 0 {
            // 根据需要生成纹理对象
            glGenTextures(1, &texture)
        }
        
        glActiveTexture(GLenum(index))
        glBindTexture(target, texture)
        
        // 确定纹理文件像素数据的内存大小
        let bodyDataStartSize = ftell(fp) + Int(fileHeader.keyPairBytes)
        fseek(fp, 0, SEEK_END)
        let bodyDataEndSize = ftell(fp)
        fseek(fp, bodyDataStartSize, SEEK_SET)
        let bodyDataSize = bodyDataEndSize - bodyDataStartSize
        
        // 读取纹理的像素数据
        let bodyDataAddress = UnsafeMutableRawPointer.allocate(byteCount: bodyDataSize, alignment: 1)
        memset(bodyDataAddress, 0, bodyDataSize)
        fread(bodyDataAddress, 1, bodyDataSize, fp)
        
        if fileHeader.mipLevels == 0 {
            //强制覆盖分级贴图数量，方便稍后使用OpenGL接口生成分级纹理贴图
            fileHeader.mipLevels = 1
        }
        
        // 将纹理的像素数据传输到GPU的纹理对象中
        if target == GLenum(GL_TEXTURE_1D) {
            glTexImage1D(GLenum(GL_TEXTURE_1D), GLint(fileHeader.mipLevels), GLint(fileHeader.glInternalFormat), GLsizei(fileHeader.pixelWidth), 0, fileHeader.glFormat, fileHeader.glType, bodyDataAddress)
        } else if target == GLenum(GL_TEXTURE_2D) {
            var imageDataAddress = bodyDataAddress
            var height = fileHeader.pixelHeight
            var width = fileHeader.pixelWidth
            // 控制图像数据从CPU向GPU传输时数据的读取方式，防止最后一行图像数据读取时越界
            glPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 1)
            for index in 0..<fileHeader.mipLevels {
                glTexImage2D(GLenum(GL_TEXTURE_2D), GLint(index), GLint(fileHeader.glInternalFormat), GLsizei(width), GLsizei(height), 0, fileHeader.glFormat, fileHeader.glType, imageDataAddress)
                imageDataAddress = imageDataAddress.advanced(by: Int(height) * memoryRowStrid(forFileHeader: fileHeader, widthPixelCount: Int(width), pad: 1))
                height >>= 1
                width >>= 1
                if height == 0 {
                    height = 1
                }
                if width == 0 {
                    width = 1
                }
            }
            // 复原图像数据从CPU向GPU传输时数据的读取方式
            glPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 4)
        } else if target == GLenum(GL_TEXTURE_3D) {
            glTexImage3D(GLenum(GL_TEXTURE_3D), GLint(fileHeader.mipLevels), GLint(fileHeader.glInternalFormat), GLsizei(fileHeader.pixelWidth), GLsizei(fileHeader.pixelHeight), GLsizei(fileHeader.pixelDepth), 0, fileHeader.glFormat, fileHeader.glType, bodyDataAddress)
        } else if target == GLenum(GL_TEXTURE_1D_ARRAY) {
            glTexImage2D(GLenum(GL_TEXTURE_1D_ARRAY), GLint(fileHeader.mipLevels), GLint(fileHeader.glInternalFormat), GLsizei(fileHeader.pixelWidth), GLsizei(fileHeader.arrayElements), 0, fileHeader.glFormat, fileHeader.glType, bodyDataAddress)
        } else if target == GLenum(GL_TEXTURE_2D_ARRAY) {
            glTexImage3D(GLenum(GL_TEXTURE_2D_ARRAY), 0, GLint(fileHeader.glInternalFormat), GLsizei(fileHeader.pixelWidth), GLsizei(fileHeader.pixelHeight), GLsizei(fileHeader.arrayElements), 0, fileHeader.glFormat, fileHeader.glType, bodyDataAddress)
        } else if target == GLenum(GL_TEXTURE_CUBE_MAP) {
            // 这里只处理无分级贴图的Case
            let faceDataSize = faceSize(forFileHeader: fileHeader)
            var faceDataAddress = bodyDataAddress;
            for index in 0..<fileHeader.faces {
                glTexImage2D(GLenum(GL_TEXTURE_CUBE_MAP_POSITIVE_X) + index, 0, GLint(fileHeader.glInternalFormat), GLsizei(fileHeader.pixelWidth), GLsizei(fileHeader.pixelHeight), 0, fileHeader.glFormat, fileHeader.glType, faceDataAddress)
                faceDataAddress = faceDataAddress.advanced(by: faceDataSize)
            }
        } else if target == GLenum(GL_TEXTURE_CUBE_MAP_ARRAY) {
            glTexImage3D(GLenum(GL_TEXTURE_CUBE_MAP_ARRAY), GLint(fileHeader.mipLevels), GLint(fileHeader.glInternalFormat), GLsizei(fileHeader.pixelWidth), GLsizei(fileHeader.pixelHeight), GLsizei(fileHeader.arrayElements), 0, fileHeader.glFormat, fileHeader.glType, bodyDataAddress)
        } else {
            return false
        }
        
        // 如果文件中读出的分级纹理数量为1，通过OpenGL生成分级纹理
        if fileHeader.mipLevels == 1 {
            glGenerateMipmap(target)
        }
        
        // 5.清理数据
        bodyDataAddress.deallocate()
        fclose(fp)
        glBindTexture(target, 0)
 
        return true
    }
}
