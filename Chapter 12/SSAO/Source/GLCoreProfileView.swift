//
//  GLCoreProfileView.swift
//  SSAO
//
//  Created by chenjie on 2019/12/6.
//  Copyright © 2019 chenjie. All rights reserved.
//

import GLKit

// 由于Swift语言特性，结构体中的两个数组内存空间连续，因此拆成两个结构体向OpenGL的BlockBuffer传递数据
// 环境光遮蔽计算时使用的随机向量，用于采样方向
fileprivate struct SampleVectors {
    var vectors = [GLKVector4](repeating: GLKVector4Make(0, 0, 0, 0), count: 256)
}
// 环境光遮蔽计算时使用的随机种子向量，用于确定采样步长
fileprivate struct SampleSeedVectors {
    var randomSeedVectors = [GLKVector4](repeating: GLKVector4Make(0, 0, 0, 0), count: 256)
}

// 普通渲染时需要使用到的统一变量索引
fileprivate struct RenderUniformsLocation {
    // 矩阵
    var mv_matrix: GLint = 0
    var proj_matrix: GLint = 0
    
    // 材质属性
    var light_pos: GLint = 0
    var diffuse_albedo: GLint = 0
    var specular_albedo: GLint = 0
    var specular_power: GLint = 0
    
    // 着色系数
    var shading_level: GLint = 0
}

// 环境光遮蔽时需要使用到的统一变量索引
fileprivate struct SSAOUniformsLocation {
    // 纹理
    var sColor: GLint = 0
    var sNormalDepth: GLint = 0
    
    // 环境光效果控制
    var ssao_level: GLint = 0
    var object_level: GLint = 0
    var ssao_radius: GLint = 0
    var point_count: GLint = 0
    var randomize_points: GLint = 0
}

class GLCoreProfileView: NSOpenGLView {
    //MARK:- Public properties
    // 除去暂停后实际渲染的时间
    var renderDuration: TimeInterval = 0
    // 环境光遮蔽查询时步长系数
    var ssaoRadius: Float = 0.05
    // 环境光遮蔽查询时使用的随机向量数
    var randomVectorCount: UInt = 10
    // 环境光遮蔽查询时是否对每个片段使用随机步长
    var randomStepLength = true
    // 是否开启光照着色
    var showShading = true
    // 是否开启环境光
    var showAo = true
    
    //MARK:- Private Properties
    // 场景渲染程序
    private var renderProgram: GLuint = 0
    private var renderUniformsLocation = RenderUniformsLocation()
    private var renderFrambuffer: GLuint = 0
    private var renderFrambufferTextures = [GLuint](repeating: 0, count: 3)
    private var modelManagerDragon: ModelManager?
    private var modelManagerCube: ModelManager?

    // 环境光渲染程序
    private var ssaoProgram: GLuint = 0
    private var ssaoUniformsLocation = SSAOUniformsLocation()
    private var ssaoVAO: GLuint = 0
    private var vectorBuffer: GLuint = 0
    private var randomSeedVectorBuffer: GLuint = 0
    
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
        glDeleteProgram(self.renderProgram)
        glDeleteFramebuffers(1, &self.renderFrambuffer)
        glDeleteTextures(3, &self.renderFrambufferTextures)
        
        glDeleteProgram(self.ssaoProgram)
        glDeleteVertexArrays(1, &self.ssaoVAO)
        glDeleteBuffers(1, &self.vectorBuffer)
        glDeleteBuffers(1, &self.randomSeedVectorBuffer)
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

        // 2. 准备场景渲染程序所需要的资源
        // 2.1 准备帧缓存对象
        glGenFramebuffers(1, &self.renderFrambuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.renderFrambuffer)

        // 2.2 准备纹理对象
        glGenTextures(3, &self.renderFrambufferTextures)
        // 2.2.1 准备颜色纹理
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.renderFrambufferTextures[0])
        var texture0Data = [GLfloat](repeating: 0, count: Int(2048 * 2048 * 3))
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGB16F, 2048, 2048, 0, GLenum(GL_RGB), GLenum(GL_FLOAT), &texture0Data)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), self.renderFrambufferTextures[0], 0)

        // 2.2.2 准备片段法向量-深度需要使用到的纹理
        glBindTexture(GLenum(GL_TEXTURE_2D), self.renderFrambufferTextures[1])
        var texture1Data = [GLfloat](repeating: 0, count: Int(2048 * 2048 * 4))
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA32F, 2048, 2048, 0, GLenum(GL_RGBA), GLenum(GL_FLOAT), &texture1Data)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT1), self.renderFrambufferTextures[1], 0)

        // 2.2.3 准备深度纹理
        glBindTexture(GLenum(GL_TEXTURE_2D), self.renderFrambufferTextures[2])
        var texture2Data = [GLfloat](repeating: 0, count: Int(2048 * 2048))
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_DEPTH_COMPONENT32F, 2048, 2048, 0, GLenum(GL_DEPTH_COMPONENT), GLenum(GL_FLOAT), &texture2Data)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), self.renderFrambufferTextures[2], 0)
        
        // 2.3 检查帧缓存对象的完整性
        let framebufferStatus = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
        if framebufferStatus != GL_FRAMEBUFFER_COMPLETE {
            print("Frame buffer is not complete, please check for details...")
            return
        }

        // 2.4 设置帧缓存对象的颜色写入附件
        var drawBuffers = [GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_COLOR_ATTACHMENT1)]
        glDrawBuffers(2, &drawBuffers)

        // 2.5 还原帧缓存对象的绑定状态为默认值
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        
        // 2.6 加载模型对象
        self.modelManagerDragon = ModelManager()
        let dragonModelLoaded = modelManagerDragon!.loadObject(fileName: "dragon.sbm")
        if !dragonModelLoaded {
            print("Load dragon model failed.")
            return
        }

        self.modelManagerCube = ModelManager()
        let cubeModelLoaded = modelManagerCube!.loadObject(fileName: "cube.sbm")
        if !cubeModelLoaded {
            print("Load cube model failed.")
            return
        }

        // 3. 准备环境光渲染程序所需要的资源
        // 3.1 准备顶点数组对象
        glGenVertexArrays(1, &self.ssaoVAO)

        // 3.2 填充统一闭包的数据
        // 3.2.1 填充随机向量闭包数据
        var sampleVectorsData = SampleVectors()
        for index in 0..<256 {
            var vector = SIMD4(Float(0), 0, 0, 0)
            // TODO： 原书例子这里确保了每个向量的长度都大1再标准化，这个点可以再详细看
            repeat {
                let vectorX = Float.random(in: -1...1)
                let vectorY = Float.random(in: -1...1)
                // 为了绘图方便，舍弃z轴负半轴向量，此时得到文章中的图
                // 如果需要观察真是效果，请解开该行代码注释
//                let vectorZ = Float.random(in: -1...1)
                let vectorZ = Float.random(in: 0...1)
                vector = SIMD4(vectorX, vectorY, vectorZ, 0)
            } while (length(vector) > 1)
            vector = normalize(vector)
            sampleVectorsData.vectors[index] = GLKVector4Make(vector.x, vector.y, vector.z, vector.w)
        }
        glGenBuffers(1, &self.vectorBuffer)
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, self.vectorBuffer)
        glBufferData(GLenum(GL_UNIFORM_BUFFER), MemoryLayout<GLKVector4>.stride * 256, &sampleVectorsData.vectors, GLenum(GL_STATIC_DRAW))
        
        // 3.2.2 填充随机种子向量闭包数据
        var sampleSeedVectorsData = SampleSeedVectors()
        for index in 0..<256 {
            let seedVectorX = Float.random(in: 0...1)
            let seedVectorY = Float.random(in: 0...1)
            let seedVectorZ = Float.random(in: 0...1)
            let seedVectorW = Float.random(in: 0...1)
            sampleSeedVectorsData.randomSeedVectors[index] = GLKVector4Make(seedVectorX, seedVectorY, seedVectorZ, seedVectorW)
        }
        glGenBuffers(1, &self.randomSeedVectorBuffer)
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 1, self.randomSeedVectorBuffer)
        glBufferData(GLenum(GL_UNIFORM_BUFFER), MemoryLayout<GLKVector4>.stride * 256, &sampleSeedVectorsData.randomSeedVectors, GLenum(GL_STATIC_DRAW))
    }

    private func prepareOpenGLProgram() -> Bool {
        // 1.准备场景渲染程序
        let renderShaders = ["render.vs" : GLenum(GL_VERTEX_SHADER),
                             "render.fs" : GLenum(GL_FRAGMENT_SHADER)]
        let renderSuccessed = self.prepareGLProgram(&self.renderProgram, shaders: renderShaders)
        if !renderSuccessed {
            return false
        }
        self.renderUniformsLocation.mv_matrix = glGetUniformLocation(self.renderProgram, "mv_matrix")
        self.renderUniformsLocation.proj_matrix = glGetUniformLocation(self.renderProgram, "proj_matrix")
        self.renderUniformsLocation.light_pos = glGetUniformLocation(self.renderProgram, "light_pos")
        self.renderUniformsLocation.diffuse_albedo = glGetUniformLocation(self.renderProgram, "diffuse_albedo")
        self.renderUniformsLocation.specular_albedo = glGetUniformLocation(self.renderProgram, "specular_albedo")
        self.renderUniformsLocation.specular_power = glGetUniformLocation(self.renderProgram, "specular_power")
        self.renderUniformsLocation.shading_level = glGetUniformLocation(self.renderProgram, "shading_level")
        
        // 2. 准备环境光渲染程序
        let ssaoShaders = ["ssao.vs" : GLenum(GL_VERTEX_SHADER),
                           "ssao.fs" : GLenum(GL_FRAGMENT_SHADER)]
        let ssaoSuccessed = self.prepareGLProgram(&self.ssaoProgram, shaders: ssaoShaders)
        if !ssaoSuccessed {
            return false
        }
        self.ssaoUniformsLocation.sColor = glGetUniformLocation(self.ssaoProgram, "sColor")
        self.ssaoUniformsLocation.sNormalDepth = glGetUniformLocation(self.ssaoProgram, "sNormalDepth")
        self.ssaoUniformsLocation.ssao_level = glGetUniformLocation(self.ssaoProgram, "ssao_level")
        self.ssaoUniformsLocation.object_level = glGetUniformLocation(self.ssaoProgram, "object_level")
        self.ssaoUniformsLocation.ssao_radius = glGetUniformLocation(self.ssaoProgram, "ssao_radius")
        self.ssaoUniformsLocation.point_count = glGetUniformLocation(self.ssaoProgram, "point_count")
        self.ssaoUniformsLocation.randomize_points = glGetUniformLocation(self.ssaoProgram, "randomize_points")
        
        let pointsUniformBlockIndex = glGetUniformBlockIndex(self.ssaoProgram, "SAMPLE_POINTS")
        glUniformBlockBinding(self.ssaoProgram, pointsUniformBlockIndex, 0)
                
        let vectorsUniformBlockIndex = glGetUniformBlockIndex(self.ssaoProgram, "SAMPLE_VEVTORS")
        glUniformBlockBinding(self.ssaoProgram, vectorsUniformBlockIndex, 1)
        
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
        // 1. 绘制场景
        // 1.1 绑定场景渲染帧缓存对象，接收数据
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.renderFrambuffer)

        // 1.2 开启深度测试和面剔除
        glEnable(GLenum(GL_DEPTH_TEST))
        glDepthFunc(GLenum(GL_LEQUAL))
        glEnable(GLenum(GL_CULL_FACE))

        // 1.3 清空颜色和深度缓存
        var blackColor: [GLfloat] = [0, 0, 0, 0]
        glClearBufferfv(GLenum(GL_COLOR), 0, &blackColor)
        glClearBufferfv(GLenum(GL_COLOR), 1, &blackColor)
        var defaultDepth: [GLfloat] = [1, 1, 1, 1]
        glClearBufferfv(GLenum(GL_DEPTH), 0, &defaultDepth)

        // 1.4 设置OpenGL程序
        glUseProgram(self.renderProgram)

        // 1.5 为统一变量赋值
        var projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50),
                                                         Float(NSWidth(self.frame) / NSHeight(self.frame)),
                                                         0.1, 1000)
        withUnsafePointer(to: &projectionMatrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.renderUniformsLocation.proj_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }

        let lookAtMatrix = GLKMatrix4MakeLookAt(0, 3, 15,
                                                0, 0, 0,
                                                0, 1, 0)
        let translateMatrixDragon = GLKMatrix4MakeTranslation(0, -5, 0)
        let rotateMatrixDragon = GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Float(self.renderDuration * 5)))
        let modelMatrixDragon = GLKMatrix4Multiply(translateMatrixDragon, rotateMatrixDragon)
        var modelViewMatrixDragon = GLKMatrix4Multiply(lookAtMatrix, modelMatrixDragon)
        withUnsafePointer(to: &modelViewMatrixDragon.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.renderUniformsLocation.mv_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }

        glUniform1f(self.renderUniformsLocation.shading_level, (self.showShading ? (self.showAo ? 0.7 : 1.0) : 0))

        // 1.6 渲染中国龙模型
        self.modelManagerDragon!.render()

        // 1.7 覆盖统一变量的值
        let translateMatrixCube = GLKMatrix4MakeTranslation(0, -4.5, 0)
        let rotateYMatrixCube = GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Float(self.renderDuration * 5)))
        let scaleMatrixCube = GLKMatrix4MakeScale(4000, 0.1, 4000)
        let modelMatrixCube = GLKMatrix4Multiply(translateMatrixCube, GLKMatrix4Multiply(rotateYMatrixCube, scaleMatrixCube))
        var modelViewMatrixCube = GLKMatrix4Multiply(lookAtMatrix, modelMatrixCube)
        withUnsafePointer(to: &modelViewMatrixCube.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.renderUniformsLocation.mv_matrix, 1, GLboolean(GL_FALSE), $0)
            }
        }

        // 1.8 渲染立方体模型
        self.modelManagerCube!.render()

        // 2. 绘制环境光场景
        // 2.1 复原帧缓存绑定状态
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        
        // 2.2 禁用深度测试和面剔除
        glDisable(GLenum(GL_DEPTH_TEST))
        glDisable(GLenum(GL_CULL_FACE))
        
        // 2.3 清空颜色缓存
        glClearBufferfv(GLenum(GL_COLOR), 0, &blackColor)

        // 2.4 设置OpenGL程序
        glUseProgram(self.ssaoProgram)

        // 2.5 为统一变量赋值
        glUniform1f(self.ssaoUniformsLocation.ssao_radius, self.ssaoRadius * Float(NSWidth(self.frame)) / 1000)
        glUniform1f(self.ssaoUniformsLocation.ssao_level, (self.showAo ? (self.showShading ? 0.3 : 1) : 0))
        glUniform1i(self.ssaoUniformsLocation.randomize_points, (self.randomStepLength ? 1 : 0))
        glUniform1ui(self.ssaoUniformsLocation.point_count, GLuint(self.randomVectorCount))

        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.renderFrambufferTextures[0])
        glUniform1i(self.ssaoUniformsLocation.sColor, 0)
        glActiveTexture(GLenum(GL_TEXTURE1))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.renderFrambufferTextures[1])
        glUniform1i(self.ssaoUniformsLocation.sNormalDepth, 1)

        // 2.6 绑定顶点数组对象
        glBindVertexArray(self.ssaoVAO)

        // 2.7 绘制场景
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)

        // 3. 清空OpenGL指令缓存，使渲染引擎尽快执行已经发布的渲染指令，同时发布窗口缓存的数据已经做好合并进入系统桌面缓存的准备
        glFlush()

        // 4. 复原纹理绑定状态为默认值
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        glActiveTexture(GLenum(GL_TEXTURE1))
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
    }
}
