//
//  GLCoreProfileView.swift
//  PerPixelGloss
//
//  Created by chenjie on 2019/11/23.
//  Copyright © 2019 chenjie. All rights reserved.
//

import GLKit

private struct UniformsLocation {
    var mv_matrix: GLint = 0
    var proj_matrix: GLint = 0
    var tex_envmap: GLint = 0
    var tex_glossmap: GLint = 0
}

class GLCoreProfileView: NSOpenGLView {
    //MARK:- Public properties
    // 除去暂停后实际渲染的时间
    var renderDuration: TimeInterval = 0
    
    //MARK:- Private Properties
    private var glProgram: GLuint = 0
    private var uniformsLocation = UniformsLocation()
    // 环境纹理贴图
    private var environmentMapTexure: GLuint = 0
    // 模糊系数纹理贴图
    private var glossMapTexture: GLuint = 0
        
    //MARK:- Life Cycles
    override init?(frame frameRect: NSRect, pixelFormat format: NSOpenGLPixelFormat?) {
        super.init(frame: frameRect, pixelFormat: format)
        
        self.prepareOpenGLContex()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        glDeleteProgram(self.glProgram)
        glDeleteTextures(1, &self.environmentMapTexure)
        glDeleteTextures(1, &self.glossMapTexture)
    }
    
    //MARK:- Private Methods: Layout
    override func reshape() {
        super.reshape()
        
        let bounds = self.bounds
        glViewport(0, 0, GLsizei(NSWidth(bounds)), GLsizei(NSHeight(bounds)))
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
        
        // 1. 准备OpenGL程序
        if !self.prepareOpenGLProgram() {
            return
        }
        
        // 2.1 加载环境纹理素材
        let envrionmentTextureLoaded = TextureManager.shareManager.loadObject(fileName: "mountains3d.ktx", toTexture: &self.environmentMapTexure, atIndex: GL_TEXTURE0)
        if !envrionmentTextureLoaded {
            print("Load texture failed.")
            return
        }
        // 设置纹理采样参数
        glTexParameteri(GLenum(GL_TEXTURE_3D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_3D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_3D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_3D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_3D), GLenum(GL_TEXTURE_WRAP_R), GL_CLAMP_TO_EDGE)
        
        // 2.2 加载模糊系数纹理素材
        let glossTextureLoaded = TextureManager.shareManager.loadObject(fileName: "pattern1.ktx", toTexture: &self.glossMapTexture, atIndex: GL_TEXTURE1)
        if !glossTextureLoaded {
            print("Load texture failed.")
            return
        }

        // 3. 加载模型
        let modelLoaded = ModelManager.shareManager.loadObject(fileName: "torus_nrms_tc.sbm")
        if !modelLoaded {
            print("Load model failed.")
            return
        }
        
        // 4. 开启面剔除和深度缓存
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_DEPTH_TEST))
        glDepthFunc(GLenum(GL_LEQUAL))
    }

    private func prepareOpenGLProgram() -> Bool {
        // 1. 准备绘制天空盒的OpenGL程序
        let shaders = ["VertexShader" : GLenum(GL_VERTEX_SHADER), "FragmentShader" : GLenum(GL_FRAGMENT_SHADER)]
        let successed = self.prepareGLProgram(&self.glProgram, shaders: shaders)
        if !successed {
            return false
        }
        self.uniformsLocation.mv_matrix = glGetUniformLocation(self.glProgram, "mv_matrix")
        self.uniformsLocation.proj_matrix = glGetUniformLocation(self.glProgram, "proj_matrix")
        self.uniformsLocation.tex_envmap = glGetUniformLocation(self.glProgram, "tex_envmap")
        self.uniformsLocation.tex_glossmap = glGetUniformLocation(self.glProgram, "tex_glossmap")

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
            
            // 2. 创建着色器
            let shader = glCreateShader(shaderInfo.value)
            
            // 3. 编译着色器
            if !self.compileShader(shader, filePath: shaderPath) {
                glDeleteShader(shader)
                return false
            }

            // 4. 将着色器附着至OpenGL程序
            glAttachShader(glProgram, shader)
            glDeleteShader(shader)
        }
        
        // 5. 编译GL程序
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
        // 1. 清空颜色缓存和深度缓存
        let grayColor:[GLfloat] = [0.1, 0.1, 0.1, 1]
        glClearBufferfv(GLenum(GL_COLOR), 0, grayColor)
        var defaultDepth:GLfloat = 1;
        glClearBufferfv(GLenum(GL_DEPTH), 0, &defaultDepth)
        
        // 2. 设置OpenGL程序
        glUseProgram(self.glProgram)
        
        // 3. 为统一变量赋值
        var projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(60), Float(self.frame.size.width / self.frame.size.height), 0.1, 1000)
        withUnsafePointer(to: &projectionMatrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.uniformsLocation.proj_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }

        let translateMatrix = GLKMatrix4MakeTranslation(0, 0, -3)
        let yRotateMatrix = GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Float(self.renderDuration) * 13.75 / 2))
        let zRotatematrix = GLKMatrix4MakeZRotation(GLKMathDegreesToRadians(Float(self.renderDuration) * 7.75 / 2))
        let xRotateMatrix = GLKMatrix4MakeXRotation(GLKMathDegreesToRadians(Float(self.renderDuration) * 15.3 / 2))
        var mvMatrix = GLKMatrix4Multiply(GLKMatrix4Multiply(translateMatrix, GLKMatrix4Multiply(yRotateMatrix, zRotatematrix)), xRotateMatrix)
        withUnsafePointer(to: &mvMatrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.uniformsLocation.mv_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }

        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_3D), self.environmentMapTexure)
        glUniform1i(self.uniformsLocation.tex_envmap, 0)
        
        glActiveTexture(GLenum(GL_TEXTURE1))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.glossMapTexture)
        glUniform1i(self.uniformsLocation.tex_glossmap, 1)

        // 4. 渲染模型程序
        ModelManager.shareManager.render()
        
        // 5. 恢复OpenGL对象绑定状态
        glBindTexture(GLenum(GL_TEXTURE_CUBE_MAP), 0)

        // 6. 清空OpenGL指令缓存，使渲染引擎尽快执行已经发布的渲染指令，同时发布窗口缓存的数据已经做好合并进入系统桌面缓存的准备
        glFlush()
    }
}
