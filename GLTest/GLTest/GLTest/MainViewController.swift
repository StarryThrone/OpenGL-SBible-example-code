//
//  MainViewController.swift
//  GLTest
//
//  Created by chenjie.starry on 2024/3/5.
//

import UIKit
import GLKit

let vertextAttributes: [GLfloat] = [-1.0, 1.0, 0.0, 1.0, 0.0, 0.0,
                                   -1.0, -1.0, 0.0, 0.0, 1.0, 0.0,
                                   1.0, -1.0, 0.0, 0.0, 0.0, 1.0]

class MainViewController: GLKViewController {
    fileprivate var context: EAGLContext?
    
    fileprivate var vbo: GLuint = 0
    fileprivate var vertexBuffer: GLuint = 0

    fileprivate var glProgram: GLuint = 0
    fileprivate var positionLocation: GLint = 0
    fileprivate var colorLocation: GLint = 0
    fileprivate var offsetLocation: GLint = 0
    
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
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        glUseProgram(self.glProgram)
        let duration = Float(self.framesDisplayed) / Float(self.preferredFramesPerSecond)
        let radiansPerSecond = duration * Float.pi * 0.5
        var offsetAttributes = [GLfloat](arrayLiteral: sinf(radiansPerSecond) * 0.5, cosf(radiansPerSecond) * 0.5, 0.0, 0.0)

        offsetLocation = glGetAttribLocation(glProgram, "offset")
        glVertexAttrib4fv(GLuint(offsetLocation), &offsetAttributes)
        
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        glFlush()
    }
    
    //MARK: - Private Methods
    fileprivate func setupOpenGLContext() -> Bool {
        guard let context = EAGLContext(api: EAGLRenderingAPI.openGLES2) else {
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
        func bufferOffset(_ i: Int) -> UnsafeRawPointer? {
            return UnsafeRawPointer(bitPattern: i)
        }
        
        
        let shaderLoaded = loadShaders()
        if !shaderLoaded {
            return false
        }
        
        glGenVertexArrays(1, &self.vbo)
        glBindVertexArray(self.vbo)
        
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        let dataSize = MemoryLayout<GLfloat>.stride * vertextAttributes.count
        vertextAttributes.withUnsafeBufferPointer { buffer in
            if let baseAddress = buffer.baseAddress {
                let rawPointer = UnsafeRawPointer(baseAddress)
                glBufferData(GLenum(GL_ARRAY_BUFFER), dataSize, rawPointer, GLenum(GL_STATIC_DRAW))
            }
        }
        
        positionLocation = glGetAttribLocation(glProgram, "position")
        glEnableVertexAttribArray(GLuint(positionLocation))
        glVertexAttribPointer(GLuint(positionLocation), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 
                              Int32(MemoryLayout<GLfloat>.stride) * 6, bufferOffset(0))
        
        colorLocation = glGetAttribLocation(glProgram, "color")
        glEnableVertexAttribArray(GLuint(colorLocation))
        glVertexAttribPointer(GLuint(colorLocation), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 
                              Int32(MemoryLayout<GLfloat>.stride) * 6, bufferOffset(MemoryLayout<GLfloat>.stride * 3))
        
        return true
    }
    
    fileprivate func loadShaders() -> Bool {
        var vertexShader: GLuint = 0
        let vertexShaderFileName = "vs_es2"
        var fragmentShader: GLuint = 0
        let fragmentShaderFileName = "fs_es2"
        
        glProgram = glCreateProgram()
        guard let vertexShaderFilePath = Bundle.main.path(forResource: vertexShaderFileName, ofType: "glsl") else { return false }
        let vertexShaderCompiled = compileShader(shader: &vertexShader, type: GLenum(GL_VERTEX_SHADER), filePath: vertexShaderFilePath)
        if !vertexShaderCompiled {
            return false
        }
        
        guard let fragmentShaderFilePath = Bundle.main.path(forResource: fragmentShaderFileName, ofType: "glsl") else { return false }
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
