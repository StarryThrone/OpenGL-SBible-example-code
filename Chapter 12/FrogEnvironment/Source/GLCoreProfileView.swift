//
//  GLCoreProfileView.swift
//  FrogEnvironment
//
//  Created by chenjie on 2019/12/1.
//  Copyright © 2019 chenjie. All rights reserved.
//

import GLKit

fileprivate struct UniformLocation {
    var mv_matrix: GLint = 0
    var proj_matrix: GLint = 0
    var mvp_matrix: GLint = 0

    // 高度纹理贴图的变量位置
    var tex_displacement: GLint = 0
    // 颜色纹理贴图的变量位置
    var tex_color: GLint = 0
    
    // 陡峭系数变量位置
    var dmap_depth: GLint = 0
    // 雾效果开启标示变量位置
    var enable_fog: GLint = 0
    // 雾颜色变量位置
    var fog_color: GLint = 0
}

class GLCoreProfileView: NSOpenGLView {
    //MARK:- Public properties
    // 除去暂停后实际渲染的时间
    var renderDuration: TimeInterval = 0
    // 开启雾化效果
    var enableFog = true
    // 开启坡度加剧
    var enableDisplacement = true
    // 坡度加剧系数
    var dampDepth: GLfloat = 6
    // 显示网格骨架
    var viewWireFrame = false
    
    //MARK:- Private Properties
    private var glProgram: GLuint = 0
    private var uniformsLocation = UniformLocation()
    private var vertexAttributesObject: GLuint = 0
    private var displacementTexture: GLuint = 0
    private var colorTexture: GLuint = 0

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
        glDeleteVertexArrays(1, &self.vertexAttributesObject)
        glDeleteTextures(1, &self.displacementTexture)
        glDeleteTextures(1, &self.colorTexture)
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
        let displacementTextureLoaded = TextureManager.shareManager.loadObject(fileName: "terragen1.ktx", toTexture: &self.displacementTexture, atIndex: GL_TEXTURE0)
        if !displacementTextureLoaded {
            print("Load displacement texture failed.")
            return
        }
        
        let colorTextureLoaded = TextureManager.shareManager.loadObject(fileName: "terragen_color.ktx", toTexture: &self.colorTexture, atIndex: GL_TEXTURE1)
        if !colorTextureLoaded {
            print("Load color texture failed.")
            return
        }

        // 3. 设置曲面细分的块大小
        glPatchParameteri(GLenum(GL_PATCH_VERTICES), 4)
        // 4. 开启面剔除和深度测试
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_DEPTH_TEST))
        glDepthFunc(GLenum(GL_LEQUAL))

        // 5. 准备顶点属性数组对象
        glGenVertexArrays(1, &self.vertexAttributesObject)
    }

    private func prepareOpenGLProgram() -> Bool {
        // 1. 准备阴影制作的OpenGL程序
        let shaders = ["VertexShader" : GLenum(GL_VERTEX_SHADER),
                       "TesselationControlShader" : GLenum(GL_TESS_CONTROL_SHADER),
                       "TesselationEvaluateShader" : GLenum(GL_TESS_EVALUATION_SHADER),
                       "FragmentShader" : GLenum(GL_FRAGMENT_SHADER)]
        let successed = self.prepareGLProgram(&self.glProgram, shaders: shaders)
        if !successed {
            return false
        }
        
        // 2. 获取统一变量的位置
        self.uniformsLocation.mv_matrix = glGetUniformLocation(self.glProgram, "mv_matrix")
        self.uniformsLocation.proj_matrix = glGetUniformLocation(self.glProgram, "proj_matrix")
        self.uniformsLocation.mvp_matrix = glGetUniformLocation(self.glProgram, "mvp_matrix")
        self.uniformsLocation.tex_displacement = glGetUniformLocation(self.glProgram, "tex_displacement")
        self.uniformsLocation.tex_color = glGetUniformLocation(self.glProgram, "tex_color")
        self.uniformsLocation.dmap_depth = glGetUniformLocation(self.glProgram, "dmap_depth")
        self.uniformsLocation.enable_fog = glGetUniformLocation(self.glProgram, "enable_fog")
        self.uniformsLocation.fog_color = glGetUniformLocation(self.glProgram, "fog_color")
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
        var blackColor: [GLfloat] = [0.85, 0.95, 1, 1]
        glClearBufferfv(GLenum(GL_COLOR), 0, &blackColor)
        var defaultDepth: GLfloat = 1
        glClearBufferfv(GLenum(GL_DEPTH), 0, &defaultDepth)
        
        // 2. 设置OpenGL程序
        glUseProgram(self.glProgram)
        
        // 3. 为统一变量赋值
        let timeFactor = Float(self.renderDuration * 0.03)
        let r = sinf(timeFactor * 5.37) * 15 + 16
        let h = cosf(timeFactor * 4.79) * 2 + 3.2
        var mv_matrix = GLKMatrix4MakeLookAt(sinf(timeFactor) * r, h, cosf(timeFactor) * r,
                                             0, 0, 0,
                                             0, 1, 0)
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
        
        var mvp_Matrix = GLKMatrix4Multiply(proj_matrix, mv_matrix)
        withUnsafePointer(to: &mvp_Matrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.uniformsLocation.mvp_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }
        
        glUniform1f(self.uniformsLocation.dmap_depth, (self.enableDisplacement ? self.dampDepth : 0))
        glUniform1i(self.uniformsLocation.enable_fog, (self.enableFog ? 1 : 0))
        
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.displacementTexture)
        glUniform1i(self.uniformsLocation.tex_displacement, 0)
        glActiveTexture(GLenum(GL_TEXTURE1))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.colorTexture)
        glUniform1i(self.uniformsLocation.tex_color, 1)
        
        // 4. 设置多边形绘制模式
        if self.viewWireFrame {
            glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(GL_LINE))
        } else {
            glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(GL_FILL))
        }
        
        // 5. 设置顶点属性数组对象
        glBindVertexArray(self.vertexAttributesObject)
        
        // 6. 绘制场景
        glDrawArraysInstanced(GLenum(GL_PATCHES), 0, 4, 64*64)

        // 7. 清空OpenGL指令缓存，使渲染引擎尽快执行已经发布的渲染指令，同时发布窗口缓存的数据已经做好合并进入系统桌面缓存的准备
        glFlush()
        
        // 8. 复原纹理顶点绑定状态
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        glActiveTexture(GLenum(GL_TEXTURE1))
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
    }
}
