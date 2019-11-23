//
//  GLCoreProfileView.swift
//  CubeEnvironmentMap
//
//  Created by chenjie on 2019/11/23.
//  Copyright © 2019 chenjie. All rights reserved.
//

import GLKit

fileprivate struct SkyboxProgramUniformLocation {
    var view_matrix: GLint = 0
    var tex_cubemap: GLint = 0
}

fileprivate struct ModelProgramUniformLocation {
    var mv_matrix: GLint = 0
    var proj_matrix: GLint = 0
    var tex_cubemap: GLint = 0
}

class GLCoreProfileView: NSOpenGLView {
    //MARK:- Public properties
    // 除去暂停后实际渲染的时间
    var renderDuration: TimeInterval = 0
    
    //MARK:- Private Properties
    private var skyboxGLProgram: GLuint = 0
    private var skyboxUniformsLocation = SkyboxProgramUniformLocation()
    private var skyboxVertexAttributesObject: GLuint = 0
    
    private var modelGLProgram: GLuint = 0
    private var modelUniformsLocation = ModelProgramUniformLocation()
    
    private var cubMapTexture: GLuint = 0
        
    //MARK:- Life Cycles
    override init?(frame frameRect: NSRect, pixelFormat format: NSOpenGLPixelFormat?) {
        super.init(frame: frameRect, pixelFormat: format)
        
        self.prepareOpenGLContex()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if self.skyboxGLProgram != 0 {
            glDeleteProgram(self.skyboxGLProgram)
        }
        if self.modelGLProgram != 0 {
            glDeleteProgram(self.modelGLProgram)
        }
        if self.cubMapTexture != 0 {
            glDeleteTextures(1, &self.cubMapTexture)
        }
        if self.skyboxVertexAttributesObject != 0 {
            glDeleteVertexArrays(1, &self.skyboxVertexAttributesObject)
        }
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
        
        // 2. 加载纹理素材
        //MARK: TODO 立方体贴图纹理无法正常工作
        let textureLoaded = TextureManager.shareManager.loadObject(fileName: "mountaincube.ktx", toTexture: &self.cubMapTexture, atIndex: GL_TEXTURE0)
        if !textureLoaded {
            print("Load texture failed.")
            return
        }
        // 设置纹理采样参数
        glTexParameteri(GLenum(GL_TEXTURE_CUBE_MAP), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_CUBE_MAP), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        // 开启立方体贴图纹理面结合处插值采样特性
        // 开启该特效后，在立方体纹理贴图面的连接处的纹理采样会从两个面上采样数据，并进行插值，从而消除由于欠采样而产生的明显分割线
        glEnable(GLenum(GL_TEXTURE_CUBE_MAP_SEAMLESS))

        // 3. 加载模型
        let modelLoaded = ModelManager.shareManager.loadObject(fileName: "dragon.sbm")
        if !modelLoaded {
            print("Load model failed.")
            return
        }
        
        // 4. 生成天空盒OpenGL程序需要使用的顶点数组对象
        glGenVertexArrays(1, &self.skyboxVertexAttributesObject)
    }

    private func prepareOpenGLProgram() -> Bool {
        // 1. 准备绘制天空盒的OpenGL程序
        let skyboxShaders = ["SkyboxVertexShader" : GLenum(GL_VERTEX_SHADER), "SkyboxFragmentShader" : GLenum(GL_FRAGMENT_SHADER)]
        let skyboxProgramSuccessed = self.prepareGLProgram(&self.skyboxGLProgram, shaders: skyboxShaders)
        if !skyboxProgramSuccessed {
            return false
        }
        self.skyboxUniformsLocation.view_matrix = glGetUniformLocation(self.skyboxGLProgram, "view_matrix")
        self.skyboxUniformsLocation.tex_cubemap = glGetUniformLocation(self.skyboxGLProgram, "tex_cubemap")
        
        // 2. 准备绘制模型的OpenGL程序
        let modelShaders = ["ModelVertexShader" : GLenum(GL_VERTEX_SHADER), "ModelFragmentShader" : GLenum(GL_FRAGMENT_SHADER)]
        let modelProgramSuccessed = self.prepareGLProgram(&self.modelGLProgram, shaders: modelShaders)
        if !modelProgramSuccessed {
            return false
        }
        self.modelUniformsLocation.mv_matrix = glGetUniformLocation(self.modelGLProgram, "mv_matrix")
        self.modelUniformsLocation.proj_matrix = glGetUniformLocation(self.modelGLProgram, "proj_matrix")
        self.modelUniformsLocation.tex_cubemap = glGetUniformLocation(self.modelGLProgram, "tex_cubemap")
        
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
        let grayColor:[GLfloat] = [0.2, 0.2, 0.2, 1]
        glClearBufferfv(GLenum(GL_COLOR), 0, grayColor)
        var defaultDepth:GLfloat = 1;
        glClearBufferfv(GLenum(GL_DEPTH), 0, &defaultDepth)
        
        // 2.1 设置天空盒OpenGL程序
        glUseProgram(self.skyboxGLProgram)
        
        // 2.2 为天空盒OpenGL程序的统一变量赋值
        var view_matrix = GLKMatrix4MakeLookAt(Float(15 * sin(self.renderDuration * 0.08)), 0, Float(15 * cos(self.renderDuration * 0.08)),
                                               0, 0, 0,
                                               0, 1, 0)
        withUnsafePointer(to: &view_matrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.skyboxUniformsLocation.view_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_CUBE_MAP), self.cubMapTexture)
        glUniform1i(self.skyboxUniformsLocation.tex_cubemap, 0)
        
        // 2.3 绑定天空盒OpenGL程序所需要使用到的顶点属性数组对象
        glBindVertexArray(self.skyboxVertexAttributesObject)
        
        // 2.4 关闭面剔除和深度检测，由于绘制的是全窗口的矩形，不涉及背向面和面重合现象，关闭该特性提高程序性能
        glDisable(GLenum(GL_CULL_FACE))
        glDisable(GLenum(GL_DEPTH_TEST))
        
        // 2.5 渲染天空盒程序
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
        
        // 3.1 设置模型OpenGL程序
        glUseProgram(self.modelGLProgram)

        // 3.2 为天空盒程序的统一变量赋值
        var projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(60), Float(self.frame.size.width / self.frame.size.height), 0.1, 1000)
        withUnsafePointer(to: &projectionMatrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.modelUniformsLocation.proj_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }

        let xRotateMatrix = GLKMatrix4MakeXRotation(GLKMathDegreesToRadians(Float(self.renderDuration)))
        let yRotateMatrix = GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Float(self.renderDuration) * 15))
        let translateMatrix = GLKMatrix4MakeTranslation(0, -4, 0)
        var mvMatrix = GLKMatrix4Multiply(GLKMatrix4Multiply(view_matrix, GLKMatrix4Multiply(xRotateMatrix, yRotateMatrix)), translateMatrix)
        withUnsafePointer(to: &mvMatrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.modelUniformsLocation.mv_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }

        glUniform1i(self.modelUniformsLocation.tex_cubemap, 0)

        // 3.3 开启面剔除和深度缓存
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_DEPTH_TEST))
        glDepthFunc(GLenum(GL_LEQUAL))

        // 3.4 渲染模型程序
        ModelManager.shareManager.render()
        
        // 4. 恢复OpenGL对象绑定状态
        glBindTexture(GLenum(GL_TEXTURE_CUBE_MAP), 0)

        // 5. 清空OpenGL指令缓存，使渲染引擎尽快执行已经发布的渲染指令，同时发布窗口缓存的数据已经做好合并进入系统桌面缓存的准备
        glFlush()
    }
}
