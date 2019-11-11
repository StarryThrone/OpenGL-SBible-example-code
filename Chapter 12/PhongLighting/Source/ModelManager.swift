//
//  ModelManager.swift
//  PhongLighting
//
//  Created by chenjie on 2019/10/30.
//  Copyright © 2019 chenjie. All rights reserved.
//

import Foundation
import GLKit

// 解析出的顶点属性数据在被访问时是否需要标准化处理
private let kVertexAttributeNormalizedFlag = 0x00000001
// 最大的子模型数量
private let kMaxSubobjectCount = 256

private func stringFromFourCharInUntValue(_ value: uint) -> String {
    let charAScalar = uint8(value & 0xFF)
    let charA = String(UnicodeScalar(charAScalar))
    let charBScalar = uint8((value >> 8) & 0xFF)
    let charB = String(UnicodeScalar(charBScalar))
    let charCScalar = uint8((value >> 16) & 0xFF)
    let charC = String(UnicodeScalar(charCScalar))
    let charDScalar = uint8((value >> 24) & 0xFF)
    let charD = String(UnicodeScalar(charDScalar))
    let resultString = charA + charB + charC + charD
    return resultString
}

// 文件头结构
private struct SB6ModelFileHeader {
    // 文件类型
    var fileType: UInt32
    func fileTypeString() -> String {
        let resultString = stringFromFourCharInUntValue(self.fileType)
        return resultString
    }
    
    // 文件头的内存大小
    var size: UInt32
    // 文件包含的块数量
    var chunkCount: UInt32
    var flags: UInt32
}

// 数据块类型
private enum ChunkType: String {
    // 索引信息数据块，用于模型渲染，渲染优先级高于SB6M_CHUNK_TYPE_VERTEX_DATA
    case indexData = "INDX"
    // 顶点信息数据块，用于初始化顶点数组对象，为其填充数据，以及模型渲染
    case vertexData = "VRTX"
    // 顶点属性数据块，用于开启顶点数组对象属性
    case vertexAttributes = "ATRB"
    // 子对象列表数据块
    case subobjectList = "OLST"
    // 评论数据块
    case comment = "CMNT"
}

// 数据块头结构
private struct ChunkHeader {
    // 数据块的类型
    var chunkTypeValue: UInt32
    func chunkType() -> ChunkType {
        let typeString = stringFromFourCharInUntValue(self.chunkTypeValue)
        let type = ChunkType(rawValue: typeString)!
        return type
    }
    
    // 整个数据块的内存大小
    var size: UInt32
}

// 顶点信息数据块
private struct VertexDataChunk {
    // 数据块头信息
    var header: ChunkHeader
    // 顶点数据的内存大小
    var dataSize: UInt32
    // 顶点数据相对于文件初始位置的内存位移量
    var dataOffset: UInt32
    // 整个模型的顶点数量
    var vertexCount: UInt32
}

// 索引信息数据块
private struct IndexDataChunk {
    // 数据块头信息
    var header: ChunkHeader
    // 索引数据的类型，如GL_UNSIGNED_SHORT
    var dataType: UInt32
    // 索引的数量
    var indexCount: UInt32
    // 索引数据相对于文件初始位置的内存位移量
    var dataOffset: UInt32
}

/**
 顶点属性数据块描述结构
 
 用于调用OpenGL的API（glVertexAttribPointer），加载某个顶点属性时的参数列表
 */
private struct VertexAttributeInformation {
    // 属性的名字
    var name: String
    // 每个属性的组件数量，如RGB颜色为3
    var size: UInt32
    // 属性的数据类型，如GL_FLOAT
    var type: UInt32
    // 两个相邻顶点属性之间的内存偏移量，如果为0，表示它们的m内存布局是紧密排列
    var normalized: UInt32
    // 是否需要标准化
    var flags: UInt32
    // 第一个属性在顶点数组缓存中的偏移量，单位为Bytes
    var dataOffset: UInt32
}

/**
 顶点属性数据块
 
 描述有了顶点属性的个数，及其属性
 */
private struct VertexAttributeChunk {
    // 数据块头信息
    var header: ChunkHeader
    // 数据块包含的顶点数量
    var attribCount: UInt32
    // 数据块描述
    var attributeInformations: [VertexAttributeInformation]?
}

// 子对象描述
private struct SubobjectInformation {
    var first: UInt32
    var count: UInt32
}

// 子对象列表数据块
private struct SubobjectChunk {
    var header: ChunkHeader
    var subobjectCount: UInt32
    // 该属性类型为Array，内存大小为8，由于其是结构体最后一个属性，不会影响数据读取的正确性
    var subobjectInformations: [SubobjectInformation]
}

class ModelManager {
    //MARK:- Public Properties
    private(set) var vao: GLuint = 0
    private(set) var num_sub_objects = 0
    static let shareManager = ModelManager()
    
    //MARK: - Private Properties
    private var sub_object = [SubobjectInformation]()
    private var vertex_buffer: GLuint = 0
    private var index_buffer: GLuint = 0
    private var num_indices: UInt32 = 0
    private var index_type: UInt32 = 0
            
    //MARK:- Life Cycle Methods
    private func attribDeclArrayAt(address: UnsafeRawPointer, count: Int) -> [VertexAttributeInformation] {
        var dataAddress = address
        var decelArray = [VertexAttributeInformation]()
        
        for _ in 0...(count - 1) {
            let dataTypeAddress = dataAddress.bindMemory(to: UInt32.self, capacity: 21)
            let dataCollectionAddress = UnsafeBufferPointer(start: dataTypeAddress, count: 21)
            let dataCollection = Array(dataCollectionAddress)
            
            var name = ""
            for index in 0...15 {
                let value = dataCollection[index]
                let currentString = stringFromFourCharInUntValue(value)
                name = name + currentString
            }
            let size = dataCollection[16]
            let type = dataCollection[17]
            let strid = dataCollection[18]
            let flags = dataCollection[19]
            let data_offset = dataCollection[20]
            let decl = VertexAttributeInformation(name: name, size: size, type: type, normalized: strid, flags: flags, dataOffset: data_offset)
            
            decelArray.append(decl)
            dataAddress = dataAddress.advanced(by: 84)
        }
        
        return decelArray
    }
        
    //MARK:- Public Methods
    func loadObject(fileName: String) -> Bool {
        guard let filePath = Bundle.main.path(forResource: fileName, ofType: nil) else {
            return false
        }
        guard var cFilePath = filePath.cString(using: .utf8) else {
            return false
        }
        self.free()

        var modeString = "rb".cString(using: .utf8)!
        let inFile = fopen(&cFilePath, &modeString)

        // 计算文件大小
        var fileSize: size_t = 0
        fseek(inFile, 0, SEEK_END)
        fileSize = ftell(inFile)
        fseek(inFile, 0, SEEK_SET)

        let data = UnsafeMutableRawPointer.allocate(byteCount: fileSize, alignment: 1)
        fread(data, fileSize, 1, inFile)

        let fileHeaderAddress = data.bindMemory(to: SB6ModelFileHeader.self, capacity: 1)
        let fileHeader = fileHeaderAddress.pointee

        var vertex_attrib_chunk: VertexAttributeChunk?
        var vertex_data_chunk: VertexDataChunk?
        var index_data_chunk: IndexDataChunk?
        var sub_object_chunk: SubobjectChunk?

        var trunkBaseAddress = data.advanced(by: Int(fileHeader.size))
        print("==============Model detect started...==============")
        for _ in 0...fileHeader.chunkCount - 1 {
            let trunkAddress = trunkBaseAddress.bindMemory(to: ChunkHeader.self, capacity: 1)
            let trunkHeader = trunkAddress.pointee
            print("Data lock name: \(trunkHeader.chunkType()), block size \(trunkHeader.size)")

            switch trunkHeader.chunkType() {
            case .vertexAttributes:
                // 由于类型SB6M_VERTEX_ATTRIB_CHUNK的声明中包含有集合数据，保存的是地址，而文件中为连续数据，因此没有办法使用内存映射
                let attrib_countAddress = trunkBaseAddress.advanced(by: 8)
                let attrib_countTypAddress = attrib_countAddress.bindMemory(to: UInt32.self, capacity: 1)
                let attrib_count = attrib_countTypAddress.pointee

                let declAddress = attrib_countAddress.advanced(by: 4)
                let declCollection = self.attribDeclArrayAt(address: declAddress, count: Int(attrib_count))
                vertex_attrib_chunk = VertexAttributeChunk(header: trunkHeader, attribCount: attrib_count, attributeInformations: declCollection)
            case .vertexData:
                let vertex_data_chunkAddress = trunkBaseAddress.bindMemory(to: VertexDataChunk.self, capacity: 1)
                vertex_data_chunk = vertex_data_chunkAddress.pointee
            case .indexData:
                let index_data_chunkAddress = trunkBaseAddress.bindMemory(to: IndexDataChunk.self, capacity: 1)
                index_data_chunk = index_data_chunkAddress.pointee
            case .subobjectList:
                let sub_object_chunkAddress = trunkBaseAddress.bindMemory(to: SubobjectChunk.self, capacity: 1)
                sub_object_chunk = sub_object_chunkAddress.pointee
            default: break
            }

            trunkBaseAddress = trunkBaseAddress.advanced(by: Int(trunkHeader.size))
        }
        print("vertex attribte count: \(vertex_attrib_chunk!.attribCount)")

        for index in 0...Int(vertex_attrib_chunk!.attribCount - 1) {
            let attribDel = vertex_attrib_chunk!.attributeInformations![index]
            print("vertex attribte name: \(attribDel.name)")
        }
        print("==============Model detect finished....==============\n\n")

        if sub_object_chunk != nil {
            if sub_object_chunk!.subobjectCount > kMaxSubobjectCount {
                sub_object_chunk?.subobjectCount = uint(kMaxSubobjectCount)
            }
            self.num_sub_objects = Int(sub_object_chunk!.subobjectCount)

            var temp = [SubobjectInformation]()
            for index in 0...Int(sub_object_chunk!.subobjectCount - 1) {
                let object_decl = sub_object_chunk!.subobjectInformations[index]
                temp.append(object_decl)
            }
            self.sub_object = temp
        } else {
            let object_decl = SubobjectInformation(first: 0, count: vertex_data_chunk!.vertexCount)
            self.num_sub_objects = 1
            self.sub_object = [object_decl]
        }

        glGenBuffers(1, &self.vertex_buffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), self.vertex_buffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(vertex_data_chunk!.dataSize), data.advanced(by: Int(vertex_data_chunk!.dataOffset)), GLenum(GL_STATIC_DRAW))
        
        glGenVertexArrays(1, &self.vao)
        glBindVertexArray(self.vao)
        
        print("==============Load Vertex Attribute....==============")
        for index in 0...Int(vertex_attrib_chunk!.attribCount - 1) {
            let attrib_decl = vertex_attrib_chunk!.attributeInformations![index]
            let normalized = Int(attrib_decl.flags) & kVertexAttributeNormalizedFlag == 1 ? GLboolean(GL_TRUE) : GLboolean(GL_FALSE)
            print("Attribute name: \(attrib_decl.name), index: \(index), size: \(attrib_decl.size), type: \(attrib_decl.type), normalized: \(normalized), strid: \(attrib_decl.normalized), offset: \(attrib_decl.dataOffset)")
            glVertexAttribPointer(GLuint(index),
                                  GLint(attrib_decl.size),
                                  attrib_decl.type,
                                  normalized,
                                  GLsizei(attrib_decl.normalized),
                                  UnsafeRawPointer(bitPattern: UInt(attrib_decl.dataOffset)))
            glEnableVertexAttribArray(GLuint(index))
        }
        print("==============Load Vertex Attribute Fonished==============\n\n")

        if index_data_chunk != nil {
            glGenBuffers(1, &self.index_buffer)
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), self.index_buffer)
            let indexSize = Int32(index_data_chunk!.dataType) == GL_UNSIGNED_SHORT ? MemoryLayout<GLushort>.size : MemoryLayout<GLubyte>.size
            glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER),
                         GLsizeiptr(Int(index_data_chunk!.indexCount) * indexSize),
                         data.advanced(by: Int(index_data_chunk!.dataOffset)),
                         GLenum(GL_STATIC_DRAW))
            self.num_indices = index_data_chunk!.indexCount
            self.index_type = index_data_chunk!.dataType
        } else {
            self.num_indices = vertex_data_chunk!.vertexCount
        }

        data.deallocate()
        fclose(inFile)

        glBindVertexArray(0)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)

        return true
    }

    func render() {
        glBindVertexArray(self.vao)
        
        if self.index_buffer != 0 {
            var offset = 0
            glDrawElementsInstanced(GLenum(GL_TRIANGLES), GLsizei(self.num_indices), GLenum(self.index_type), &offset, 1)
        } else {
            let object_decl = self.sub_object.first!
            glDrawArraysInstanced(GLenum(GL_TRIANGLES), GLint(object_decl.first), GLsizei(object_decl.count), 1)
        }
        
        glBindVertexArray(0)
    }
    
    func render(instanceCount: UInt) {
        if self.index_buffer != 0 {
            var offset = 0
            glDrawElementsInstanced(GLenum(GL_TRIANGLES), GLsizei(self.num_indices), GLenum(self.index_type), &offset, GLsizei(instanceCount))
        } else {
            let object_decl = self.sub_object.first!
            glDrawArraysInstanced(GLenum(GL_TRIANGLES), GLint(object_decl.first), GLsizei(object_decl.count), GLsizei(instanceCount))
        }
    }
        
    func getSubObjectInfo(index: Int, first: inout GLuint, count: inout GLuint) {
        if index >= self.num_sub_objects {
            first = 0
            count = 0
        } else {
            let subObject = self.sub_object[index]
            first = subObject.first
            count = subObject.count
        }
    }
    
    func free() {
        glDeleteVertexArrays(1, &self.vao)
        glDeleteBuffers(1, &self.vertex_buffer)
        glDeleteBuffers(1, &self.index_buffer)
        
        self.vao = 0
        self.vertex_buffer = 0
        self.index_buffer = 0
        self.num_indices = 0
    }
}
