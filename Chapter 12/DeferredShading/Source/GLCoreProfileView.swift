//
//  GLCoreProfileView.swift
//  DeferredShading
//
//  Created by chenjie on 2019/12/3.
//  Copyright © 2019 chenjie. All rights reserved.
//

import GLKit

let GBufferWidth: GLsizei = 2048
let GBufferHeight: GLsizei = 2048
let NumberOfLights: GLsizei = 64
let NumberOfInstances: Int = 225


private struct LightAttribute {
    var position = GLKVector3Make(0, 0, 0)
    var pad0: uint32 = 0
    var color = GLKVector3Make(0, 0, 0)
    var pad1: uint32 = 0
}

class GLCoreProfileView: NSOpenGLView {
    //MARK:- Public properties
    // 除去暂停后实际渲染的时间
    var renderDuration: TimeInterval = 0
    
    //MARK:- Private Properties
    private var renderProgram: GLuint = 0
    private var renderTextureLocation: GLint = 0
    
    private var renderNMProgram: GLuint = 0
    private var renderNMDiffuseLocation: GLint = 0
    private var renderNMNormalLocation: GLint = 0
    
    private var lightProgram: GLuint = 0
    private var lightGBufferTex0Location: GLint = 0
    private var lightGBuggerTex1Location: GLint = 0
    private var lightNumberOfLightsLocation: GLint = 0

    private var visProgram: GLuint = 0
    private var visGBufferTex0Location: GLint = 0
    private var visGBufferTex1Location: GLint = 0
    private var visNumberOfLightsLocation: GLint = 0
    private var visModeLocation: GLint = 0
    
    private var gFramebuffer: GLuint = 0
    private var gBufferTextures = [GLuint](repeating: 0, count: 3)
    private var modelNormalTexture: GLuint = 0
    private var modelColorTexture: GLuint = 0
    private var lightUBuffer: GLuint = 0
    private var renderTransformUBuffer: GLuint = 0
    private var quadVertexAttributeObject: GLuint = 0
    
    private var use_nm = false
    private var enableVS = false

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
        
        // 2.
        glGenFramebuffers(1, &self.gFramebuffer)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.gFramebuffer)

        glGenTextures(3, &self.gBufferTextures)
//        glActiveTexture(T##texture: GLenum##GLenum)
        glBindTexture(GLenum(GL_TEXTURE_2D), self.gBufferTextures[0])
        var texture0Data = [uint32](repeating: 0, count: Int(GBufferWidth * GBufferHeight * 4))
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA32UI, GBufferWidth, GBufferHeight, 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_INT), &texture0Data)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), self.gBufferTextures[0], 0)

        glBindTexture(GLenum(GL_TEXTURE_2D), self.gBufferTextures[1])
        var texture1Data = [GLfloat](repeating: 0, count: Int(GBufferWidth * GBufferHeight * 4))
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA32F, GBufferWidth, GBufferHeight, 0, GLenum(GL_RGBA), GLenum(GL_FLOAT), &texture1Data)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT1), self.gBufferTextures[1], 0)

        glBindTexture(GLenum(GL_TEXTURE_2D), self.gBufferTextures[2])
        var texture2Data = [GLfloat](repeating: 0, count: Int(GBufferWidth * GBufferHeight))
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_DEPTH_COMPONENT32F, GBufferWidth, GBufferHeight, 0, GLenum(GL_DEPTH_COMPONENT), GLenum(GL_FLOAT), &texture2Data)
        glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), self.gBufferTextures[2], 0)

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0);

        
        // 3. 加载模型
        let modelLoaded = ModelManager.shareManager.loadObject(fileName: "ladybug.sbm")
        if !modelLoaded {
            print("Load model failed.")
            return
        }
        
        // 4. 加载纹理
        let normalTextureLoaded = TextureManager.shareManager.loadObject(fileName: "ladybug_nm.ktx", toTexture: &self.modelNormalTexture, atIndex: GL_TEXTURE0)
        if !normalTextureLoaded {
            print("Load ladybug_nm.ktx texture failed.")
            return
        }
        
        let colorTextureLoaded = TextureManager.shareManager.loadObject(fileName: "ladybug_co.ktx", toTexture: &self.modelColorTexture, atIndex: GL_TEXTURE1)
        if !colorTextureLoaded {
            print("Load ladybug_co.ktx texture failed.")
            return
        }
        
        // 5.
        glGenBuffers(1, &self.lightUBuffer)
        glBindBuffer(GLenum(GL_UNIFORM_BUFFER), self.lightUBuffer)
        glBufferData(GLenum(GL_UNIFORM_BUFFER), MemoryLayout<LightAttribute>.stride * Int(NumberOfLights), nil, GLenum(GL_DYNAMIC_DRAW))

        glGenBuffers(1, &self.renderTransformUBuffer)
        glBindBuffer(GLenum(GL_UNIFORM_BUFFER), self.renderTransformUBuffer)
        glBufferData(GLenum(GL_UNIFORM_BUFFER), (NumberOfInstances + 2) * MemoryLayout<GLKMatrix4>.stride, nil, GLenum(GL_DYNAMIC_DRAW))
        
        // 6.
        glGenVertexArrays(1, &self.quadVertexAttributeObject)
        glBindVertexArray(self.quadVertexAttributeObject)
        
        // 7. 开启面剔除和深度测试
//        glEnable(GLenum(GL_CULL_FACE))
//        glEnable(GLenum(GL_DEPTH_TEST))
//        glDepthFunc(GLenum(GL_LEQUAL))
    }

    private func prepareOpenGLProgram() -> Bool {
        // 1.
        let renderShaders = ["render.vs" : GLenum(GL_VERTEX_SHADER),
                             "render.fs" : GLenum(GL_FRAGMENT_SHADER)]
        let renderSuccessed = self.prepareGLProgram(&self.renderProgram, shaders: renderShaders)
        if !renderSuccessed {
            return false
        }
        self.renderTextureLocation = glGetUniformLocation(self.renderProgram, "tex_diffuse")
        
        // 2.
        let renderNMShaders = ["render-nm.vs" : GLenum(GL_VERTEX_SHADER),
                               "render-nm.fs" : GLenum(GL_FRAGMENT_SHADER)]
        let renderNMSuccessed = self.prepareGLProgram(&self.renderNMProgram, shaders: renderNMShaders)
        if !renderNMSuccessed {
            return false
        }
        self.renderNMDiffuseLocation = glGetUniformLocation(self.renderProgram, "tex_diffuse")
        self.renderNMNormalLocation = glGetUniformLocation(self.renderProgram, "tex_normal_map")
        
        // 3.
        let lightShaders = ["light.vs" : GLenum(GL_VERTEX_SHADER),
                            "light.fs" : GLenum(GL_FRAGMENT_SHADER)]
        let lightSuccessed = self.prepareGLProgram(&self.lightProgram, shaders: lightShaders)
        if !lightSuccessed {
            return false
        }
        self.lightGBufferTex0Location = glGetUniformLocation(self.renderProgram, "gbuf_tex0")
        self.lightGBuggerTex1Location = glGetUniformLocation(self.renderProgram, "gbuf_tex1")
        self.lightNumberOfLightsLocation = glGetUniformLocation(self.renderProgram, "num_lights")

        // 4.
        let visShaders = ["light.vs" : GLenum(GL_VERTEX_SHADER),
                          "render-vis.fs" : GLenum(GL_FRAGMENT_SHADER)]
        let visSuccessed = self.prepareGLProgram(&self.visProgram, shaders: visShaders)
        if !visSuccessed {
            return false
        }
        self.visGBufferTex0Location = glGetUniformLocation(self.renderProgram, "gbuf_tex0")
        self.visGBufferTex1Location = glGetUniformLocation(self.renderProgram, "gbuf_tex1")
        self.visNumberOfLightsLocation = glGetUniformLocation(self.renderProgram, "num_lights")
        self.visModeLocation = glGetUniformLocation(self.renderProgram, "vis_mode")
        
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
        //
        glBindBuffer(GLenum(GL_FRAMEBUFFER), self.gFramebuffer)
        var dreawBuffers = [GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_COLOR_ATTACHMENT1)]
        glDrawBuffers(2, &dreawBuffers)
        
        // 1. 清空颜色和深度缓存
        var uBlackColor: [GLuint] = [0, 0, 0, 0]
        glClearBufferuiv(GLenum(GL_COLOR), 0, &uBlackColor)
        var fBlackColor: [GLfloat] = [0, 0, 0, 0]
        glClearBufferfv(GLenum(GL_COLOR), 1, &fBlackColor)
        var defaultDepth: [GLfloat] = [1, 1, 1, 1]
        glClearBufferfv(GLenum(GL_DEPTH), 0, &defaultDepth)
        
        //
        var renderTransformUBufferData = [GLKMatrix4]()
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50),
                                                         Float(NSWidth(self.frame) / NSHeight(self.frame)),
                                                         0.1, 1000)
        renderTransformUBufferData.append(projectionMatrix)
        
        let d = (sinf(Float(self.renderDuration * 0.131)) + 2) * 0.15
        let eyePosition = GLKVector3Make(d * 120 * sinf(Float(self.renderDuration * 0.11)),
                                         5.5,
                                         d * 120 * cosf(Float(self.renderDuration * 0.01)))
        let viewMatrix = GLKMatrix4MakeLookAt(eyePosition.x, eyePosition.y, eyePosition.z,
                                              0, -20, 0,
                                              0, 1, 0)
        renderTransformUBufferData.append(viewMatrix)
        
        for j in 0..<15 {
            for i in 0..<15 {
                let translateMatrix = GLKMatrix4MakeTranslation((Float(i) - 7.5) * 7, 0, (Float(j) - 7.5) * 11)
                renderTransformUBufferData.append(translateMatrix)
            }
        }
        
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, self.renderTransformUBuffer)
        guard let renderTransformUBufferDataAddress = glMapBufferRange(GLenum(GL_UNIFORM_BUFFER), 0, (2 + NumberOfInstances) * MemoryLayout<GLKMatrix4>.stride, GLbitfield(GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT)) else {
            return
        }
        renderTransformUBufferDataAddress.initializeMemory(as: GLKMatrix4.self, from: &renderTransformUBufferData, count: 2 + NumberOfInstances)
        glUnmapBuffer(GLenum(GL_UNIFORM_BUFFER))

        //
        if self.use_nm {
            glUseProgram(self.renderNMProgram)
        } else {
            glUseProgram(self.renderProgram)
        }
        
        //
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.modelColorTexture)
        glActiveTexture(GLenum(GL_TEXTURE1))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.modelNormalTexture)
        
        //
        glEnable(GLenum(GL_DEPTH_TEST))
        glDepthFunc(GLenum(GL_LEQUAL))
        
        //
        ModelManager.shareManager.render(instanceCount: UInt(NumberOfInstances))
        
        //
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
//        glDrawBuffer(GLenum(GL_BACK))
        
        //
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.gBufferTextures[0])
        glActiveTexture(GLenum(GL_TEXTURE1))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.gBufferTextures[1])
        
        //
        if self.enableVS {
            glUseProgram(self.visProgram)
            glUniform1i(self.visModeLocation, 1)
        } else {
            glUseProgram(self.lightProgram)
        }
        
        //
        glDisable(GLenum(GL_DEPTH_TEST))
        
        //
        var lightUBufferData = [LightAttribute]()
        for i in 0..<NumberOfLights {
            var lightAttribute = LightAttribute()
            
            let f = (Float(i) - 7.5) * 0.1 + 0.3
            let positionX = 100 * sinf(Float(self.renderDuration * 1.1) + (5 * f)) * cosf(Float(self.renderDuration * 2.3) + (9 * f))
            let positionZ = 100 * sinf(Float(self.renderDuration * 1.5) + (6 * f)) * cosf(Float(self.renderDuration * 1.9) + (11 * f))
            let position = GLKVector3Make(positionX, 15, positionZ)
            lightAttribute.position = position
            
            let color = GLKVector3Make(cosf(f * 14) * 0.5 + 0.8,
                                       sinf(f * 17) * 0.5 + 0.8,
                                       sinf(f * 13) * cosf(f * 19) * 0.5 + 0.8)
            lightAttribute.color = color
            
            lightUBufferData.append(lightAttribute)
        }
        
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, self.lightUBuffer)
        guard let lightUBufferAddress = glMapBufferRange(GLenum(GL_UNIFORM_BUFFER), 0, MemoryLayout<LightAttribute>.stride * Int(NumberOfLights), GLbitfield(GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT)) else {
            return
        }
        lightUBufferAddress.initializeMemory(as: LightAttribute.self, from: &lightUBufferData, count: Int(NumberOfLights))
        glUnmapBuffer(GLenum(GL_UNIFORM_BUFFER))
        
        //
        glBindVertexArray(self.quadVertexAttributeObject)
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
        
        // 5. 清空OpenGL指令缓存，使渲染引擎尽快执行已经发布的渲染指令，同时发布窗口缓存的数据已经做好合并进入系统桌面缓存的准备
        glFlush()
        
        //
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
    }
}
