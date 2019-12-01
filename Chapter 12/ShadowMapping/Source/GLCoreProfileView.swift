//
//  GLCoreProfileView.swift
//  ShadowMapping
//
//  Created by chenjie on 2019/11/23.
//  Copyright © 2019 chenjie. All rights reserved.
//

import GLKit

fileprivate let DepthTextureSize = 4096

enum RenderMode: UInt {
    // 渲染全彩场景，添加漫反射色和反射色
    case Full = 0
    // 渲染单色场景，不添加漫反射色和反射色
    case Light = 1
    // 渲染深度信息
    case Depth = 2
}

fileprivate struct SceneRenderFactor {
    var lightPosition = GLKVector3Make(0, 0, 0)
    var viewPosition = GLKVector3Make(0, 0, 0)
    var lightProjectMatrix = GLKMatrix4Identity
    var lightViewMatrix = GLKMatrix4Identity
    var cameraProjectionMatrix = GLKMatrix4Identity
    var cameraViewMatrix = GLKMatrix4Identity
    var modelMatrixs = [GLKMatrix4]()
}

fileprivate struct SceneProgramUniformLocation {
    var mv_matrix: GLint = 0
    var proj_matrix: GLint = 0
    var shadow_matrix: GLint = 0
    
    var shadow_tex: GLint = 0
    
    var light_pos: GLint = 0
    var diffuse_albedo: GLint = 0
    var specular_albedo: GLint = 0
    var specular_power: GLint = 0
    var full_shading: GLint = 0
}

class GLCoreProfileView: NSOpenGLView {
    //MARK:- Public properties
    // 除去暂停后实际渲染的时间
    var renderDuration: TimeInterval = 0
    var renderMode = RenderMode.Full
    
    //MARK:- Private Properties
    // 深度采集程序，深度数据用于场景渲染时计算阴影效果
    private var makeDepthProgram: GLuint = 0
    private var makeDepthMvpUniformLocation: GLint = 0
    private var makeDepthFramebuffer: GLuint = 0
    private var makeDepthColorTexture: GLuint = 0
    private var makeDepthDepthTexture: GLuint = 0
    
    // 深度渲染程序，用于Debug查看深度采集程序获得的数据
    private var showDepthProgram: GLuint = 0
    private var showDepthTexDepthUniformLocation: GLint = 0
    private var showDepthVertexAttributesObject: GLuint = 0
    
    // 场景渲染程序，渲染整个场景，根据选择的RenderMode，可能得到不同的结果
    private var sceneProgram: GLuint = 0
    private var sceneUniformsLocation = SceneProgramUniformLocation()
    
    private var modelManagers = [ModelManager]()
        
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
        glDeleteProgram(self.makeDepthProgram)
        glDeleteFramebuffers(1, &self.makeDepthFramebuffer)
        glDeleteTextures(1, &self.makeDepthColorTexture)
        glDeleteTextures(1, &self.makeDepthDepthTexture)
        
        glDeleteProgram(self.showDepthProgram)
        glDeleteVertexArrays(1, &self.showDepthVertexAttributesObject)
        
        glDeleteProgram(self.sceneProgram)
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
        
        // 2. 加载模型
        let modelNames = ["dragon.sbm", "sphere.sbm", "cube.sbm", "torus.sbm"]
        for index in 0..<modelNames.count {
            let modelManager = ModelManager()
            let modelLoadSuccessed = modelManager.loadObject(fileName: modelNames[index])
            if !modelLoadSuccessed {
                print("Load model failed.")
                return
            }
            self.modelManagers.append(modelManager)
        }

        
        // 3.1 准备阴影制作程序makeDepthProgram的帧缓存
        glGenFramebuffers(1, &self.makeDepthFramebuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.makeDepthFramebuffer)

        // 3.2 准备阴影制作程序makeDepthProgram的颜色附件
        glGenTextures(1, &self.makeDepthColorTexture)
        glBindTexture(GLenum(GL_TEXTURE_2D), self.makeDepthColorTexture)
        let textureDataSize = DepthTextureSize * DepthTextureSize * 4
        let colorTextureDataAddress = UnsafeMutableRawPointer.allocate(byteCount: textureDataSize, alignment: 1)
        let colorTextureTypedDataAddress = colorTextureDataAddress.initializeMemory(as: GLubyte.self, repeating: 0xff, count: textureDataSize)
        // 填充纹理数据
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA8, GLsizei(DepthTextureSize), GLsizei(DepthTextureSize), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), colorTextureTypedDataAddress)
        // 生成分级贴图
        glGenerateMipmap(GLenum(GL_TEXTURE_2D))
        // 设置纹理采样的过滤模式为线型混合
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        // 将颜色附件添加到帧缓存对象中
        glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), self.makeDepthColorTexture, 0)

        // 3.3 准备阴影制作程序makeDepthProgram程序的深度附件
        glGenTextures(1, &self.makeDepthDepthTexture)
        glBindTexture(GLenum(GL_TEXTURE_2D), self.makeDepthDepthTexture)
        let depthTextureDataAddress = UnsafeMutableRawPointer.allocate(byteCount: textureDataSize, alignment: 1)
        let depthTexutreTypedDataAddress = depthTextureDataAddress.initializeMemory(as: GLubyte.self, repeating: 0x00, count: textureDataSize)
        // 填充纹理数据
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_DEPTH_COMPONENT32F, GLsizei(DepthTextureSize), GLsizei(DepthTextureSize), 0, GLenum(GL_DEPTH_COMPONENT), GLenum(GL_UNSIGNED_BYTE), depthTexutreTypedDataAddress)
        // 设置纹理采样的过滤模式为线型混合
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        // 设置纹理写入的比较规则，如果计算值比纹理值小，则覆盖
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_COMPARE_MODE), GL_COMPARE_REF_TO_TEXTURE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_COMPARE_FUNC), GL_LEQUAL)
        // 将深度纹理添加到帧缓存附件中
        glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), self.makeDepthDepthTexture, 0)

        // 3.4 检查FBO完整性
        let frambufferStatus = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
        if (frambufferStatus != GL_FRAMEBUFFER_COMPLETE) {
            print("Frame buffer is not complete, please check for details...")
        }

        // 3.5 复原纹理和帧缓存绑定状态
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)

        // 4. 准备深度渲染程序showDepthProgram需要使用的顶点属性数组对象
        glGenVertexArrays(1, &self.showDepthVertexAttributesObject)
    }

    private func prepareOpenGLProgram() -> Bool {
        // 1. 准备阴影制作的OpenGL程序
        let makeDepthShaders = ["MakeDepthVertexShader" : GLenum(GL_VERTEX_SHADER), "MakeDepthFragmentShader" : GLenum(GL_FRAGMENT_SHADER)]
        let makeDepthSuccessed = self.prepareGLProgram(&self.makeDepthProgram, shaders: makeDepthShaders)
        if !makeDepthSuccessed {
            return false
        }
        self.makeDepthMvpUniformLocation = glGetUniformLocation(self.makeDepthProgram, "mvp")
        
        // 3. 准备深度渲染的OpenGL程序
        let showDepthShaders = ["ShowDepthVertexShader" : GLenum(GL_VERTEX_SHADER), "ShowDepthFragmentShader" : GLenum(GL_FRAGMENT_SHADER)]
        let showDepthSuccessed = self.prepareGLProgram(&self.showDepthProgram, shaders: showDepthShaders)
        if !showDepthSuccessed {
            return false
        }
        self.showDepthTexDepthUniformLocation = glGetUniformLocation(self.showDepthProgram, "tex_depth")

        // 3. 准备场景渲染的OpenGL程序
        let sceneShaders = ["SceneVertexShader" : GLenum(GL_VERTEX_SHADER), "SceneFragmentShader" : GLenum(GL_FRAGMENT_SHADER)]
        let sceneSuccessed = self.prepareGLProgram(&self.sceneProgram, shaders: sceneShaders)
        if !sceneSuccessed {
            return false
        }
        self.sceneUniformsLocation.mv_matrix = glGetUniformLocation(self.sceneProgram, "mv_matrix")
        self.sceneUniformsLocation.proj_matrix = glGetUniformLocation(self.sceneProgram, "proj_matrix")
        self.sceneUniformsLocation.shadow_matrix = glGetUniformLocation(self.sceneProgram, "shadow_matrix")
        self.sceneUniformsLocation.light_pos = glGetUniformLocation(self.sceneProgram, "light_pos")
        self.sceneUniformsLocation.shadow_tex = glGetUniformLocation(self.sceneProgram, "shadow_tex")
        self.sceneUniformsLocation.diffuse_albedo = glGetUniformLocation(self.sceneProgram, "diffuse_albedo")
        self.sceneUniformsLocation.specular_albedo = glGetUniformLocation(self.sceneProgram, "specular_albedo")
        self.sceneUniformsLocation.specular_power = glGetUniformLocation(self.sceneProgram, "specular_power")
        self.sceneUniformsLocation.full_shading = glGetUniformLocation(self.sceneProgram, "full_shading")
        
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
        // 1. 准备场景渲染及深度制作所需要的参数
        let renderFactor = self.makeSceneRenderFacot()
        // 2. 制作阴影纹理
        self.renderScene(mode: .Depth, factor: renderFactor)
        
        if self.renderMode == .Depth {
            // 3.1 查看深度贴图
            self.renderSceneDepthMap()
        } else {
            // 3.2 渲染场景
            self.renderScene(mode: self.renderMode, factor: renderFactor)
        }

        // 4. 清空OpenGL指令缓存，使渲染引擎尽快执行已经发布的渲染指令，同时发布窗口缓存的数据已经做好合并进入系统桌面缓存的准备
        glFlush()
    }
    
    private func makeSceneRenderFacot() -> SceneRenderFactor {
        // 1. 准备以光源为观察点的观察、投影矩阵
        let lightPosition = GLKVector3Make(20, 20, 20)
        let lightViewMatrix = GLKMatrix4MakeLookAt(lightPosition.x, lightPosition.y, lightPosition.z,
                                              0, 0, 0,
                                              0, 1, 0)
        let lightProjectMatrix = GLKMatrix4MakeFrustum(-1, 1, -1, 1, 1, 200)
        
        // 2. 准备观察点的观察、投影矩阵
        let viewPosition = GLKVector3Make(0, 0, 40)
        let cameraViewMatrix = GLKMatrix4MakeLookAt(viewPosition.x, viewPosition.y, viewPosition.z,
                                                    0, 0, 0,
                                                    0, 1, 0)
        let cameraProjectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50),
                                                               Float(NSWidth(self.frame) / NSHeight(self.frame)),
                                                               1, 200)
        // 3. 准备模型到世界坐标系的变换矩阵
        var modelMatrixs = [GLKMatrix4]()
        let timeFactor = self.renderDuration + 30
        do {
            let yRotateMatrix = GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Float(timeFactor * 14.5)))
            let xRotateMatrix = GLKMatrix4MakeXRotation(GLKMathDegreesToRadians(20))
            let translateMatrix = GLKMatrix4MakeTranslation(0, -4, 0)
            let modelMatrix = GLKMatrix4Multiply(yRotateMatrix, GLKMatrix4Multiply(xRotateMatrix, translateMatrix))
            modelMatrixs.append(modelMatrix)
        }
        do {
            let yRotateMatrix = GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Float(timeFactor * 3.7)))
            let translateMatrix = GLKMatrix4MakeTranslation(Float(sin(timeFactor * 0.37) * 12), Float(cos(timeFactor * 0.37) * 12), 0)
            let scaleMatrix = GLKMatrix4MakeScale(2, 2, 2)
            let modelMatrix = GLKMatrix4Multiply(yRotateMatrix, GLKMatrix4Multiply(translateMatrix, scaleMatrix))
            modelMatrixs.append(modelMatrix)
        }
        do {
            let yRotateMatrix = GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Float(timeFactor * 6.45)))
            let translateMatrix = GLKMatrix4MakeTranslation(Float(sin(timeFactor * 0.25) * 10), Float(cos(timeFactor * 0.25) * 10), 0)
            let zRotateMatrix = GLKMatrix4MakeZRotation(GLKMathDegreesToRadians(Float(timeFactor * 99)))
            let scaleMatrix = GLKMatrix4MakeScale(2, 2, 2)
            let modelMatrix = GLKMatrix4Multiply(yRotateMatrix, GLKMatrix4Multiply(translateMatrix, GLKMatrix4Multiply(zRotateMatrix, scaleMatrix)))
            modelMatrixs.append(modelMatrix)
        }
        do {
            let yRotateMatrix = GLKMatrix4MakeYRotation(GLKMathDegreesToRadians(Float(timeFactor * 5.25)))
            let translateMatrix = GLKMatrix4MakeTranslation(Float(sin(timeFactor * 0.51) * 14), Float(cos(timeFactor * 0.51) * 14), 0)
            let xZRotateMatrix = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(Float(timeFactor * 120.3)), 0.707106, 0, 0.707106)
            let scaleMatrix = GLKMatrix4MakeScale(2, 2, 2)
            let modelMatrix = GLKMatrix4Multiply(yRotateMatrix, GLKMatrix4Multiply(translateMatrix, GLKMatrix4Multiply(xZRotateMatrix, scaleMatrix)))
            modelMatrixs.append(modelMatrix)
        }

        var renderFactor = SceneRenderFactor()
        renderFactor.lightPosition = lightPosition
        renderFactor.viewPosition = viewPosition
        renderFactor.lightProjectMatrix = lightProjectMatrix
        renderFactor.lightViewMatrix = lightViewMatrix
        renderFactor.cameraProjectionMatrix = cameraProjectionMatrix
        renderFactor.cameraViewMatrix = cameraViewMatrix
        renderFactor.modelMatrixs = modelMatrixs
        
        return renderFactor
    }
    
    private func renderSceneDepthMap() {
        // 1. 使用系统提供的FBO对象
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        // 2. 设置绘制区域
        glViewport(0, 0, GLsizei(512), GLsizei(512))
        // 3. 清空颜色缓存
        let grayColor:[GLfloat] = [0.0, 0.0, 0.0, 1]
        glClearBufferfv(GLenum(GL_COLOR), 0, grayColor)
        // 4. 禁用面剔除和深度测试
        glDisable(GLenum(GL_CULL_FACE))
        glDisable(GLenum(GL_DEPTH_TEST))
        // 5. 设置OpenGL程序
        glUseProgram(self.showDepthProgram)

        // 6. 设置顶点数组对象
        glBindVertexArray(self.showDepthVertexAttributesObject)

        // 7. 绑定纹理数据
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.makeDepthDepthTexture)
        glUniform1i(self.showDepthTexDepthUniformLocation, 0)

        // 8. 绘制场景
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
    }
        
    private func renderScene(mode: RenderMode, factor: SceneRenderFactor) {
        if mode == .Depth {
            // 1. 制作深度贴图
            // 1.1 绑定帧缓存对象
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.makeDepthFramebuffer)
            // 1.2 设置数据写入的颜色附件
            var drawBuffers = [GLenum(GL_COLOR_ATTACHMENT0)]
            glDrawBuffers(1, &drawBuffers)
            // 1.3 设置绘制区域和深度纹理的尺寸相同
            glViewport(0, 0, GLsizei(DepthTextureSize), GLsizei(DepthTextureSize))
            
            // 1.4 清空颜色缓存
            let blackColor:[GLfloat] = [0, 0, 0, 0]
            glClearBufferfv(GLenum(GL_COLOR), 0, blackColor)
            // 1.5 开启面剔除
            glEnable(GLenum(GL_CULL_FACE))
            // 1.6 开启深度测试，并清空深度缓存
            glEnable(GLenum(GL_DEPTH_TEST))
            glDepthFunc(GLenum(GL_LEQUAL))
            var defaultDepth:GLfloat = 1;
            glClearBufferfv(GLenum(GL_DEPTH), 0, &defaultDepth)
            // 1.7 开启多边形深度位移功能，将深度贴图的深度值稍微加大，缓解在渲染场景时光线和多边形相切部分，深度值差异较小从而形成的异常条带。
            glEnable(GLenum(GL_POLYGON_OFFSET_FILL))
            glPolygonOffset(6, 6)

            // 1.8 设置OpenGL程序
            glUseProgram(self.makeDepthProgram)
        } else {
            // 2.1 绑定帧缓存对象为系统提供的FBO
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
            glDrawBuffer(GLenum(GL_BACK))
            // 2.2 设置绘制区域和窗口区域相同
            glViewport(0, 0, GLsizei(NSWidth(self.frame)), GLsizei(NSHeight(self.frame)))

            // 2.3 清空颜色缓存
            let grayColor:[GLfloat] = [0.1, 0.1, 0.1, 0]
            glClearBufferfv(GLenum(GL_COLOR), 0, grayColor)
            // 2.4 开启面剔除
            glEnable(GLenum(GL_CULL_FACE))
            // 2.5 开启深度测试，并清空深度缓存
            glEnable(GLenum(GL_DEPTH_TEST))
            var defaultDepth:GLfloat = 1;
            glClearBufferfv(GLenum(GL_DEPTH), 0, &defaultDepth)
            
            // 2.6 设置OpenGL程序
            glUseProgram(self.sceneProgram)

            // 2.7 填充统一变量的数据
            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(GLenum(GL_TEXTURE_2D), self.makeDepthDepthTexture)
            glUniform1i(self.sceneUniformsLocation.shadow_tex, 0)

            var cameraProjectionMatrix = factor.cameraProjectionMatrix
            withUnsafePointer(to: &cameraProjectionMatrix.m) {
                $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                    glUniformMatrix4fv(self.sceneUniformsLocation.proj_matrix, 1, GLboolean(GL_FALSE), $0)
                }
            }
        }
        
        let lightVPMatrix = GLKMatrix4Multiply(factor.lightProjectMatrix, factor.lightViewMatrix)
        for index in 0..<4 {
            let modelMatrix = factor.modelMatrixs[index]
            if mode == .Depth {
                // 3. 填充制作深度贴图所需要的以光源为观察点的MPV矩阵数据
                var lightMVPMatrix = GLKMatrix4Multiply(lightVPMatrix, modelMatrix)
                withUnsafePointer(to: &lightMVPMatrix.m) {
                    $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                        glUniformMatrix4fv(self.makeDepthMvpUniformLocation, 1, GLboolean(GL_FALSE), $0)
                    }
                }
            } else {
                // 4 设置场景渲染所需要的矩阵数据
                // 4.1 设置阴影坐标校正矩阵，因为投影坐标系中xyz的取值为[-1,1]，而阴影贴图中纹查询的坐标以及深度比较的坐标都为[0,1]，需该矩阵做坐标变换
                let scaleBiasMatrix = GLKMatrix4MakeWithColumns(GLKVector4Make(0.5, 0,   0,   0),
                                                                GLKVector4Make(0,   0.5, 0,   0),
                                                                GLKVector4Make(0,   0,   0.5, 0),
                                                                GLKVector4Make(0.5, 0.5, 0.5, 1))
                // 请参考着色器源码SceneFragmentShader了解何时解开该行注释
//                let scaleBiasMatrix = GLKMatrix4Identity
                let shadowSBPVMatrix = GLKMatrix4Multiply(scaleBiasMatrix, lightVPMatrix)
            
                // 4.2 设置阴影坐标变换矩阵
                var shadowMatrix = GLKMatrix4Multiply(shadowSBPVMatrix, modelMatrix)
                withUnsafePointer(to: &shadowMatrix.m) {
                    $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                        glUniformMatrix4fv(self.sceneUniformsLocation.shadow_matrix, 1, GLboolean(GL_FALSE), $0)
                    }
                }

                // 4.3 设置MVP矩阵
                var mvMatrix = GLKMatrix4Multiply(factor.cameraViewMatrix, modelMatrix)
                withUnsafePointer(to: &mvMatrix.m) {
                    $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                        glUniformMatrix4fv(self.sceneUniformsLocation.mv_matrix, 1, GLboolean(GL_FALSE), $0)
                    }
                }

                // 4.4 设置是否需要渲染全彩场景
                let renderFullScene = (mode == .Full ? 1 : 0)
                glUniform1i(self.sceneUniformsLocation.full_shading, GLint(renderFullScene))
            }
            
            // 5. 渲染模型
            self.modelManagers[index].render()
        }
        
        if mode == .Depth {
            // 6. 禁用多边形位移功能，并还原FBO绑定状态
            glDisable(GLenum(GL_POLYGON_OFFSET_FILL))
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        } else {
            // 7. 还原纹理绑定状态
            glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        }
    }
}
