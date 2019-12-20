//
//  GLCoreProfileView.swift
//  TessellatedTriangle
//
//  Created by chenjie on 2019/4/26.
//  Copyright © 2019 starrythrone. All rights reserved.
//

import Cocoa
import OpenGL.GL3

class GLCoreProfileView: NSOpenGLView {
    //MARK: - Propeties
    
    //MARK: - Life Cycle
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        
    }
    
    deinit {
    }
    
    //MARK: - Override
    override func prepareOpenGL() {
        super.prepareOpenGL()
    }
    
    override func reshape() {
        super.reshape()
    }
    
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    //MARK: - Private Methods
    fileprivate func setupOpenGLContext() -> Bool {
        return true
    }
    
    fileprivate func loadShaders() -> Bool {
        return true
    }

    fileprivate func compileShader(shader: inout GLuint, type: GLenum, filePath: String) -> Bool {
        var source: UnsafePointer<Int8>?
        do {
            source = try NSString(contentsOfFile: filePath, encoding: String.Encoding.utf8.rawValue).utf8String
        } catch {
            print("Failed to load shader string...")
            return false
        }
        var shaderSource = UnsafePointer<GLchar>(source)
        if (shaderSource == nil) {
            return false
        }
        
        shader = glCreateShader(type)
        glShaderSource(shader, 1, &shaderSource, nil)
        glCompileShader(shader)

        var status: GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
        if status == 0 {
            var logLength: GLint = 0
            glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
            var infoLog = [GLchar](repeating: 0, count: Int(logLength))
            glGetShaderInfoLog(shader, logLength, nil, &infoLog)
            let infoLogString = String(NSString.init(utf8String: &infoLog) ?? "")
            print("Compile shader failed at file:\n" + filePath + "\nwith log\n" + infoLogString)
            glDeleteShader(shader)
            return false
        }
        return true
    }
    
    fileprivate func linkProgram(_ program: GLuint) -> Bool {
        glLinkProgram(program)
        var status: GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
        if status == 0 {
            var infoLength: GLint = 0
            glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &infoLength)
            var infoLog = [GLchar](repeating: 0, count: Int(infoLength))
            glGetProgramInfoLog(program, infoLength, nil, &infoLog)
            let infoLogString = String(NSString.init(utf8String: &infoLog) ?? "")
            print("Like program fiaied with log: " + infoLogString)
            return false
        }
        return true
    }
}
