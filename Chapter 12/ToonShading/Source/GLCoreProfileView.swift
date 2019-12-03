//
//  GLCoreProfileView.swift
//  ToonShading
//
//  Created by chenjie on 2019/12/3.
//  Copyright © 2019 chenjie. All rights reserved.
//

import GLKit

fileprivate struct UniformsLocation {
    var mv_matrix: GLint = 0
    var proj_matrix: GLint = 0
    var tex_toon: GLint = 0
    var light_pos: GLint = 0
}

class GLCoreProfileView: NSOpenGLView {
    //MARK:- Public properties
    // 除去暂停后实际渲染的时间
    var renderDuration: TimeInterval = 0
    
    //MARK:- Private Properties
    private var glProgram: GLuint = 0
    private var uniformsLocation = UniformsLocation()
    private var toonTexture: GLuint = 0

    //MARK:- Life Cycles
    override init?(frame frameRect: NSRect, pixelFormat format: NSOpenGLPixelFormat?) {
        super.init(frame: frameRect, pixelFormat: format)
        // 禁用Retina屏幕显示
        self.wantsBestResolutionOpenGLSurface = false

        self.prepareOpenGLContex()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        glDeleteProgram(self.glProgram)
        glDeleteTextures(1, &self.toonTexture)
    }
    
    //MARK:- Private Methods: General
    override func reshape() {
        super.reshape()
        glViewport(0, 0, GLsizei(NSWidth(self.frame)), GLsizei(NSHeight(self.frame)))
    }
    
    //MARK:- Private Methods: Render
    private func prepareOpenGLContex() {
        let pixelFormatAttributes = [UInt32(NSOpenGLPFAColorSize), 32,
                                     UInt32(NSOpenGLPFADepthSize), 24,
                                     UInt32(NSOpenGLPFAStencilSize), 8,
                                     UInt32(NSOpenGLPFAAccelerated),
                                     UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion4_1Core),
                                     0]
        guard let pixelFormat = NSOpenGLPixelFormat(attributes: pixelFormatAttributes) else { return }
        let currentOpenGLContext = NSOpenGLContext(format: pixelFormat, share: nil)
        self.openGLContext = currentOpenGLContext
        self.openGLContext?.makeCurrentContext()
        // 设置缓存交换频率和屏幕刷新同步
        var swapInterval = GLint(1)
        CGLSetParameter(CGLGetCurrentContext()!, kCGLCPSwapInterval, &swapInterval)
    }

    override func prepareOpenGL() {
        super.prepareOpenGL()
        print("Version: \(String(cString: glGetString(uint32(GL_VERSION))))")
        print("Renderer: \(String(cString: glGetString(uint32(GL_RENDERER))))")
        print("Vendor: \(String(cString: glGetString(GLenum(GL_VENDOR))))")
        print("GLSL Version: \(String(cString: glGetString(GLenum(GL_SHADING_LANGUAGE_VERSION))))")
        
        // 1. 准备所有的OpenGL程序
        if !self.prepareOpenGLProgram() {
            return
        }
        
        // 2. 加载纹理
        glGenTextures(1, &self.toonTexture)
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_1D), self.toonTexture)
        var data: [uint8] = [0x44, 0x00, 0x00, 0x00,
                             0x88, 0x00, 0x00, 0x00,
                             0xCC, 0x00, 0x00, 0x00,
                             0xFF, 0x00, 0x00, 0x00]
        glTexImage1D(GLenum(GL_TEXTURE_1D), 0, GL_RGB8, 4, 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), &data)
        glTexParameteri(GLenum(GL_TEXTURE_1D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_1D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_1D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glBindTexture(GLenum(GL_TEXTURE_1D), 0)
        
        
        // 3. 加载模型
        let modelLoaded = ModelManager.shareManager.loadObject(fileName: "torus_nrms_tc.sbm")
        if !modelLoaded {
            print("Load model failed.")
            return
        }

        // 4. 开启面剔除和深度测试
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_DEPTH_TEST))
        glDepthFunc(GLenum(GL_LEQUAL))
    }

    private func prepareOpenGLProgram() -> Bool {
        // 1. 准备阴影制作的OpenGL程序
        let shaders = ["VertexShader" : GLenum(GL_VERTEX_SHADER),
                       "FragmentShader" : GLenum(GL_FRAGMENT_SHADER)]
        let successed = self.prepareGLProgram(&self.glProgram, shaders: shaders)
        if !successed {
            return false
        }
        
        // 2. 获取统一变量的位置
        self.uniformsLocation.mv_matrix = glGetUniformLocation(self.glProgram, "mv_matrix")
        self.uniformsLocation.proj_matrix = glGetUniformLocation(self.glProgram, "proj_matrix")
        self.uniformsLocation.tex_toon = glGetUniformLocation(self.glProgram, "tex_toon")
        self.uniformsLocation.light_pos = glGetUniformLocation(self.glProgram, "light_pos")
        return true
    }
            
    private func prepareGLProgram(_ glProgram: inout GLuint, shaders: [String : GLenum]) -> Bool {
        if shaders.count == 0 {
            print("No available shader.")
            return false
        }
        
        // 1. 创建GL程序
        glProgram = glCreateProgram()

        for (_, shaderInfo) in shaders.enumerated() {
            // 2. 获取着色器的源码
            guard let shaderPath = Bundle.main.path(forResource: shaderInfo.key, ofType: "glsl") else {
                print("Can not find shader file at " + shaderInfo.key)
                return false
            }
            
            // 3. 创建着色器
            let shader = glCreateShader(shaderInfo.value)
            
            // 4. 编译着色器
            if !self.compileShader(shader, filePath: shaderPath) {
                glDeleteShader(shader)
                return false
            }

            // 5. 将着色器附着至OpenGL程序
            glAttachShader(glProgram, shader)
            glDeleteShader(shader)
        }
        
        // 6. 编译GL程序
        if !self.linkProgram(program: glProgram) {
            print("Failed to link program")
            glDeleteProgram(glProgram)
            glProgram = 0
            return false
        }
        return true
    }
        
    private func compileShader(_ shader: GLuint, filePath: String) -> Bool {
        // 1. 为着色器填充源码
        var shaderSource: UnsafePointer<GLchar>?
        do {
            shaderSource = try NSString(contentsOfFile: filePath, encoding: String.Encoding.utf8.rawValue).utf8String
        } catch {
            print("Error when compile shader")
        }
        glShaderSource(shader, 1, &shaderSource, nil)
        // 2. 编译着色器
        glCompileShader(shader)
        
        // 3. 查询着色器编译错误日志
        var status: GLint = 0
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
        if status == 0 {
            var logLength: GLint = 0
            glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
            var infoLogChars = [GLchar](repeating: 0, count: Int(logLength))
            glGetShaderInfoLog(shader, logLength, nil, &infoLogChars)
            let infoLogString = String(utf8String: infoLogChars) ?? ""
            print("Compile Shader Failed at \n" + filePath + "\nWith Log\n" + infoLogString)
            return false
        }
        return true
    }

    func linkProgram(program: GLuint) -> Bool {
        glLinkProgram(program)
        var status: GLint = 0
        glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
        if status == 0 {
            var logLength: GLint = 0
            glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength)
            var logChars = [GLchar](repeating: 0, count: Int(logLength))
            glGetProgramInfoLog(program, GLsizei(logLength), nil, &logChars)
            let logString = String(utf8String: logChars) ?? ""
            print("Compile program failed with log \n" + logString)
            return false
        }
        
        return true
    }
        
    override func draw(_ dirtyRect: NSRect) {
        // 1. 清空颜色和深度缓存
        var blackColor: [GLfloat] = [0.1, 0.1, 0.1, 1]
        glClearBufferfv(GLenum(GL_COLOR), 0, &blackColor)
        var defaultDepth: GLfloat = 1
        glClearBufferfv(GLenum(GL_DEPTH), 0, &defaultDepth)
        
        // 2. 设置OpenGL程序
        glUseProgram(self.glProgram)
        
        // 3. 为统一变量赋值
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_1D), self.toonTexture)
        glUniform1i(self.uniformsLocation.tex_toon, 0)
        
        let translateMatrix = GLKMatrix4MakeTranslation(0, 0, -3)
        let yRotateMatrix = GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Float(self.renderDuration * 13.75)))
        let zRotateMatrix = GLKMatrix4MakeZRotation(GLKMathDegreesToRadians(Float(self.renderDuration * 7.75)))
        let xRotateMatrix = GLKMatrix4MakeXRotation(GLKMathDegreesToRadians(Float(self.renderDuration * 15.3)))
        var mv_matrix = GLKMatrix4Multiply(translateMatrix, GLKMatrix4Multiply(yRotateMatrix, GLKMatrix4Multiply(zRotateMatrix, xRotateMatrix)))
        withUnsafePointer(to: &mv_matrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.uniformsLocation.mv_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }
        
        var proj_matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(60),
                                                    Float(NSWidth(self.frame) / NSHeight(self.frame)),
                                                    0.1, 1000)
        withUnsafePointer(to: &proj_matrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.uniformsLocation.proj_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }
        
        // 4. 绘制场景
        ModelManager.shareManager.render()
        
        // 5. 清空OpenGL指令缓存，使渲染引擎尽快执行已经发布的渲染指令，同时发布窗口缓存的数据已经做好合并进入系统桌面缓存的准备
        glFlush()
        
        // 6. 复原纹理顶点绑定状态
        glBindTexture(GLenum(GL_TEXTURE_1D), 0)
    }
}
