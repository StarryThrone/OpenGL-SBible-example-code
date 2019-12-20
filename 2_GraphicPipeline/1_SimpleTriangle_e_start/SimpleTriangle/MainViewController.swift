//
//  MainViewController.swift
//  SimpleTriangle
//
//  Created by chenjie on 2019/4/18.
//  Copyright © 2019 starrythrone. All rights reserved.
//

import UIKit
import GLKit

class MainViewController: GLKViewController {
    
    //MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    deinit {
    }

    //MARK: - Override
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
    }
    
    //MARK: - Private Methods
    fileprivate func setupOpenGLContext() -> Bool {
        return true
    }
    
    fileprivate func setupOpenGLInfrastructure() -> Bool {
        return true
    }
    
    fileprivate func loadShaders() -> Bool {
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
    
    fileprivate func compileShader(shader: inout GLuint, type: GLenum, filePath: String) -> Bool {
        var source: UnsafePointer<Int8>?
        do {
            source = try NSString(contentsOfFile: filePath, encoding: String.Encoding.utf8.rawValue).utf8String
        } catch {
            print("Falied to load shader string...")
            return false
        }
        var shaderSource = UnsafePointer<GLchar>(source)
        
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
}

