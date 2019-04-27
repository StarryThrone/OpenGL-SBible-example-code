//
//  GLCoreProfileView.swift
//  FragmentShader
//
//  Created by chenjie on 2019/4/27.
//  Copyright © 2019 starrythrone. All rights reserved.
//

import Cocoa
import OpenGL.GL3

class GLCoreProfileView: NSOpenGLView {

    //MARK: - Propeties
    fileprivate var lifeDuration: CGFloat = 0
    fileprivate var program: GLuint = 0
    fileprivate var vertexArray: GLuint = 0
    
    //MARK: - Life Cycle
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        
        let openGLContextConfigured = setupOpenGLContext()
        if !openGLContextConfigured {
            print("Prepare OpenGLContextFailed...")
        }
    }
    
    deinit {
        glDeleteProgram(program)
        glDeleteVertexArrays(1, &vertexArray)
    }

    //MARK: - Override
    override func prepareOpenGL() {
        super.prepareOpenGL()
        
        if let versionString = glGetString(GLenum(GL_VERSION)) {
            print("GL_VERSION: " + String(cString: versionString))
        }
        if let renderString = glGetString(GLenum(GL_RENDERER)) {
            print("GL_RENDERER: " + String(cString: renderString))
        }
        if let vendorString = glGetString(GLenum(GL_VENDOR)) {
            print("GL_VENDOR: " + String(cString: vendorString))
        }
        if let glVersionString = glGetString(GLenum(GL_SHADING_LANGUAGE_VERSION)) {
            print("GL_SHADING_LANGUAGE_VERSION: " + String(cString: glVersionString))
        }
        
        let shaderLoaded = loadShaders()
        if !shaderLoaded {
            return
        }
        
        glGenVertexArrays(1, &vertexArray);
        glBindVertexArray(vertexArray);
    }
    
    override func reshape() {
        super.reshape()
        let bounds = self.bounds
        glViewport(0, 0, GLsizei(NSWidth(bounds)), GLsizei(NSHeight(bounds)));
    }
    
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    //MARK: - Private Methods
    fileprivate func setupOpenGLContext() -> Bool {
        var pixelFormatAttributes: [NSOpenGLPixelFormatAttribute] =
            [UInt32(NSOpenGLPFAColorSize), 32,
             UInt32(NSOpenGLPFAAccelerated),
             UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion4_1Core), 0]
        guard let pixelFormat = NSOpenGLPixelFormat(attributes: &pixelFormatAttributes) else {
            return false
        }
        
        let currentOpenGLContext = NSOpenGLContext(format: pixelFormat, share: nil)
        self.openGLContext = currentOpenGLContext
        self.openGLContext?.makeCurrentContext()
        return true
    }
    
    fileprivate func loadShaders() -> Bool {
        self.program = glCreateProgram()
        
        var vertexShader: GLuint = 0
        guard let vertexShaderPath = Bundle.main.path(forResource: "ShaderV", ofType: "vsh") else {
            print("Can not load vertexShader file")
            return false
        }
        let vertexShaderCompiled = compileShader(shader: &vertexShader, type: GLenum(GL_VERTEX_SHADER), filePath: vertexShaderPath)
        if (!vertexShaderCompiled) {
            return false
        }
        
        var fragmentShader: GLuint = 0
        guard let fragmentShaderPath = Bundle.main.path(forResource: "ShaderF", ofType: "vsh") else {
            print("Can not load fragmentShader file")
            return false
        }
        let fragmentShaderCompiled = compileShader(shader: &fragmentShader, type: GLenum(GL_FRAGMENT_SHADER), filePath: fragmentShaderPath)
        if (!fragmentShaderCompiled) {
            return false
        }
        
        glAttachShader(self.program, vertexShader)
        glAttachShader(self.program, fragmentShader)
        
        if (vertexShader != 0) {
            glDeleteShader(vertexShader);
            vertexShader = 0
        }
        if (fragmentShader != 0) {
            glDeleteShader(fragmentShader);
            fragmentShader = 0
        }
        
        let programLinked = linkProgram(program)
        if programLinked {
            return true
        } else {
            return false
        }
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
