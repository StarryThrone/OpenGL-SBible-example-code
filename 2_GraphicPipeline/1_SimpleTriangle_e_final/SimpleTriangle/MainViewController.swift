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
    fileprivate var context: EAGLContext?
    fileprivate var glProgram: GLuint = 0
    fileprivate var vbo: GLuint = 0
    
    //MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        let openGLContextConfigured = setupOpenGLContext()
        if !openGLContextConfigured {
            return
        }
        let openGLInfrastructureConfigured = setupOpenGLInfrastructure()
        if !openGLInfrastructureConfigured {
            return
        }
        self.preferredFramesPerSecond = 60
    }
    
    deinit {
        glDeleteProgram(glProgram)
        glDeleteVertexArraysOES(1, &vbo)
    }

    //MARK: - Override
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        var defaultColor: [GLfloat] = [0, 0, 0, 1]
        glClearBufferfv(GLenum(GL_COLOR), 0, &defaultColor)
        
        glUseProgram(self.glProgram)
        let duration = Float(self.framesDisplayed) / Float(self.preferredFramesPerSecond)
        let radiansPerSecond = duration * Float.pi * 0.5
        var offsetAttributes = [GLfloat](arrayLiteral: sinf(radiansPerSecond) * 0.5, cosf(radiansPerSecond) * 0.5, 0.0, 0.0)
        glVertexAttrib4fv(0, &offsetAttributes)
        
        var triangleColor = [GLfloat](arrayLiteral: 1, 1, 0, 1)
        glVertexAttrib4fv(1, &triangleColor)
        
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        glFlush()
    }
    
    //MARK: - Private Methods
    fileprivate func setupOpenGLContext() -> Bool {
        guard let context = EAGLContext(api: EAGLRenderingAPI.openGLES3) else {
            print("Failed to intialize opengl es context")
            return false
        }
        
        EAGLContext.setCurrent(context)
        let view = self.view as! GLKView
        view.context = context
        view.drawableColorFormat = GLKViewDrawableColorFormat.RGBA8888
        return true
    }
    
    fileprivate func setupOpenGLInfrastructure() -> Bool {
        let shaderLoaded = loadShaders()
        if !shaderLoaded {
            return false
        }
        
        glGenVertexArrays(1, &self.vbo)
        glBindVertexArray(self.vbo)
        
        return true
    }
    
    fileprivate func loadShaders() -> Bool {
        var vertexShader: GLuint = 0
        let vertexShaderFileName = "Shader"
        var fragmentShader: GLuint = 0
        let fragmentShaderFileName = "Shader"
        
        glProgram = glCreateProgram()
        guard let vertexShaderFilePath = Bundle.main.path(forResource: vertexShaderFileName, ofType: "vsh") else { return false }
        let vertexShaderCompiled = compileShader(shader: &vertexShader, type: GLenum(GL_VERTEX_SHADER), filePath: vertexShaderFilePath)
        if !vertexShaderCompiled {
            return false
        }
        
        guard let fragmentShaderFilePath = Bundle.main.path(forResource: fragmentShaderFileName, ofType: "fsh") else { return false }
        let fragmentShaderCompiled = compileShader(shader: &fragmentShader, type: GLenum(GL_FRAGMENT_SHADER), filePath: fragmentShaderFilePath)
        if !fragmentShaderCompiled {
            return false
        }
        
        glAttachShader(glProgram, vertexShader)
        glAttachShader(glProgram, fragmentShader)
        if vertexShader != 0 {
            glDeleteShader(vertexShader)
        }
        if fragmentShader != 0 {
            glDeleteShader(fragmentShader)
        }
        
        let programLinked = linkProgram(glProgram)
        if programLinked {
            return true
        } else {
            return false
        }
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

