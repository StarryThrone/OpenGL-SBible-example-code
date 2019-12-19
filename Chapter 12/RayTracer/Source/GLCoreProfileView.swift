//
//  GLCoreProfileView.swift
//  RayTracer
//
//  Created by chenjie on 2019/12/13.
//  Copyright © 2019 chenjie. All rights reserved.
//

import GLKit

let MaxRecursionDepth = 5
let MaxFBWidth = 2048
let MaxFBHeight = 1024

private struct PrepareUniformsLocation {
    var yAspect: GLint = 0
}

private struct RayTracerUniformsLocation {
    // 纹理
    var tex_origin: GLint = 0
    var tex_direction: GLint = 0
    var tex_color: GLint = 0
    
    // 统一闭包
    var SPHERES: GLuint = 0
    var PLANES: GLuint = 0
    var LIGHTS: GLuint = 0
    
    // 其他统一变量
    var num_spheres: GLint = 0
    var num_planes: GLint = 0
    var num_lights: GLint = 0
    var viewMatrix: GLint = 0
}

private struct Sphere {
    var centerRadius = GLKVector4Make(0, 0, 0, 0)
    var color = GLKVector4Make(0, 0, 0, 0)
}

private struct Plane {
    var normal = GLKVector3Make(0, 0, 0)
    var d: GLfloat = 0
}

private struct Light {
    var position = GLKVector3Make(0, 0, 0)
    private var pad: UInt32 = 0
}

enum DebugMode: UInt {
    case none = 0
    case reflected = 1
    case refracted = 2
    case reflectedColor = 3
    case refractedColor = 4
}

class GLCoreProfileView: NSOpenGLView {
    //MARK:- Public properties
    // 除去暂停后实际渲染的时间
    var renderDuration: TimeInterval = 0
    var debugMode = DebugMode.none
    var debugDepth = 1
    // TODO： 多次光线追踪还需要完善
    var maxDepth = 1
    
    //MARK:- Private Properties
    // 光线追踪准备程序
    private var prepareProgram: GLuint = 0
    private var prepareUniformsLocation = PrepareUniformsLocation()
    
    // 光线追踪计算程序
    private var rayTracerProgram: GLuint = 0
    private var rayTracerUniformsLocation = RayTracerUniformsLocation()
    
    // 光线追踪结果渲染程序
    private var blitProgram: GLuint = 0
    private var blitTex_compositeLocation: GLint = 0
    
    // 统一闭包变量缓存对象
    private var sphereBuffer: GLuint = 0
    private var planeBuffer: GLuint = 0
    private var lightBuffer: GLuint = 0
    // 顶点属性数组对象
    private var vao: GLuint = 0
    // 帧缓存和纹理对象
    private var rayFramebuffers = [GLuint](repeating: 0, count: MaxRecursionDepth)
    private var compositeTexture: GLuint = 0
    private var positionTextures = [GLuint](repeating: 0, count: MaxRecursionDepth)
    private var reflectedTextures = [GLuint](repeating: 0, count: MaxRecursionDepth)
    private var refractedTextures = [GLuint](repeating: 0, count: MaxRecursionDepth)
    private var reflectionIntensityTextures = [GLuint](repeating: 0, count: MaxRecursionDepth)
    private var refractionIntensityTextures = [GLuint](repeating: 0, count: MaxRecursionDepth)
    
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
        //TODO
        // 释放OpenGL对象
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

        // 2. 准备统一闭包缓存对象
        glGenBuffers(1, &self.sphereBuffer)
        glBindBuffer(GLenum(GL_UNIFORM_BUFFER), self.sphereBuffer)
        glBufferData(GLenum(GL_UNIFORM_BUFFER), 128 * MemoryLayout<Sphere>.size, nil, GLenum(GL_DYNAMIC_DRAW))
        
        glGenBuffers(1, &self.planeBuffer)
        glBindBuffer(GLenum(GL_UNIFORM_BUFFER), self.planeBuffer)
        glBufferData(GLenum(GL_UNIFORM_BUFFER), 128 * MemoryLayout<Plane>.size, nil, GLenum(GL_DYNAMIC_DRAW))
        
        glGenBuffers(1, &self.lightBuffer)
        glBindBuffer(GLenum(GL_UNIFORM_BUFFER), self.lightBuffer)
        glBufferData(GLenum(GL_UNIFORM_BUFFER), 128 * MemoryLayout<Light>.size, nil, GLenum(GL_DYNAMIC_DRAW))
                
        // 3. 准备帧缓存对象
        glGenFramebuffers(GLsizei(MaxRecursionDepth), &self.rayFramebuffers)
        
        // 4. 准备帧缓存对象关联的纹理对象
        glGenTextures(1, &self.compositeTexture)
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.compositeTexture)
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGB16F, GLsizei(MaxFBWidth), GLsizei(MaxFBHeight), 0, GLenum(GL_RGB), GLenum(GL_UNSIGNED_BYTE), nil)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        
        glGenTextures(GLsizei(MaxRecursionDepth), &self.positionTextures)
        glGenTextures(GLsizei(MaxRecursionDepth), &self.reflectedTextures)
        glGenTextures(GLsizei(MaxRecursionDepth), &self.refractedTextures)
        glGenTextures(GLsizei(MaxRecursionDepth), &self.reflectionIntensityTextures)
        glGenTextures(GLsizei(MaxRecursionDepth), &self.refractionIntensityTextures)
        
        // 5. 将帧缓存对象和纹理对象关联
        for index in 0..<MaxRecursionDepth {
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.rayFramebuffers[index])
            
            glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), self.compositeTexture, 0)
            
            glBindTexture(GLenum(GL_TEXTURE_2D), self.positionTextures[index])
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGB32F, GLsizei(MaxFBWidth), GLsizei(MaxFBHeight), 0, GLenum(GL_RGB), GLenum(GL_FLOAT), nil)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
            glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT1), self.positionTextures[index], 0)
            
            glBindTexture(GLenum((GL_TEXTURE_2D)), self.reflectedTextures[index])
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGB16F, GLsizei(MaxFBWidth), GLsizei(MaxFBHeight), 0, GLenum(GL_RGB), GLenum(GL_FLOAT), nil)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
            glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT2), self.reflectedTextures[index], 0)
            
            glBindTexture(GLenum(GL_TEXTURE_2D), self.refractedTextures[index])
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGB16F, GLsizei(MaxFBWidth), GLsizei(MaxFBHeight), 0, GLenum(GL_RGB), GLenum(GL_FLOAT), nil)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
            glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT3), self.refractedTextures[index], 0)
            
            glBindTexture(GLenum(GL_TEXTURE_2D), self.reflectionIntensityTextures[index])
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGB16F, GLsizei(MaxFBWidth), GLsizei(MaxFBHeight), 0, GLenum(GL_RGB), GLenum(GL_FLOAT), nil)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
            glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT4), self.reflectionIntensityTextures[index], 0)
            
            glBindTexture(GLenum(GL_TEXTURE_2D), self.refractionIntensityTextures[index])
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGB16F, GLsizei(MaxFBWidth), GLsizei(MaxFBHeight), 0, GLenum(GL_RGB), GLenum(GL_FLOAT), nil)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
            glFramebufferTexture(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT5), self.refractionIntensityTextures[index], 0)
        }
        
        // 6. 重置OpenGL上下文的绑定状态
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
                
        // 7. 准备顶点属性数组
        glGenVertexArrays(1, &self.vao)
        glBindVertexArray(self.vao)
    }

    private func prepareOpenGLProgram() -> Bool {
        // 1. 准备初始光线追踪程序
        let prepareShaders = ["prepare.vs" : GLenum(GL_VERTEX_SHADER),
                              "prepare.fs" : GLenum(GL_FRAGMENT_SHADER)]
        let prepareSuccessed = self.prepareGLProgram(&self.prepareProgram, shaders: prepareShaders)
        if !prepareSuccessed {
            return false
        }
        self.prepareUniformsLocation.yAspect = glGetUniformLocation(self.prepareProgram, "yAspect")

        // 2. 准备光线追踪计算程序
        let rayTracerShaders = ["raytracer.vs" : GLenum(GL_VERTEX_SHADER),
                                "raytracer.fs" : GLenum(GL_FRAGMENT_SHADER)]
        let rayTracerSuccessed = self.prepareGLProgram(&self.rayTracerProgram, shaders: rayTracerShaders)
        if !rayTracerSuccessed {
            return false
        }

        self.rayTracerUniformsLocation.tex_origin = glGetUniformLocation(self.rayTracerProgram, "tex_origin")
        self.rayTracerUniformsLocation.tex_direction = glGetUniformLocation(self.rayTracerProgram, "tex_direction")
        self.rayTracerUniformsLocation.tex_color = glGetUniformLocation(self.rayTracerProgram, "tex_color")
        self.rayTracerUniformsLocation.num_spheres = glGetUniformLocation(self.rayTracerProgram, "num_spheres")
        self.rayTracerUniformsLocation.num_planes = glGetUniformLocation(self.rayTracerProgram, "num_planes")
        self.rayTracerUniformsLocation.num_lights = glGetUniformLocation(self.rayTracerProgram, "num_lights")
        self.rayTracerUniformsLocation.viewMatrix = glGetUniformLocation(self.rayTracerProgram, "viewMatrix")

        self.rayTracerUniformsLocation.SPHERES = glGetUniformBlockIndex(self.rayTracerProgram, "SPHERES")
        glUniformBlockBinding(self.rayTracerProgram, self.rayTracerUniformsLocation.SPHERES, 0)
        self.rayTracerUniformsLocation.PLANES = glGetUniformBlockIndex(self.rayTracerProgram, "PLANES")
        glUniformBlockBinding(self.rayTracerProgram, self.rayTracerUniformsLocation.PLANES, 1)
        self.rayTracerUniformsLocation.LIGHTS = glGetUniformBlockIndex(self.rayTracerProgram, "LIGHTS")
        glUniformBlockBinding(self.rayTracerProgram, self.rayTracerUniformsLocation.LIGHTS, 2)

        // 3. 光线追踪渲染程序
        let blitShaders = ["blit.vs" : GLenum(GL_VERTEX_SHADER),
                           "blit.fs" : GLenum(GL_FRAGMENT_SHADER)]
        let blitSuccessed = self.prepareGLProgram(&self.blitProgram, shaders: blitShaders)
        if !blitSuccessed {
            return false
        }
        self.blitTex_compositeLocation = glGetUniformLocation(self.blitProgram, "tex_composite")
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
        // 1. 运行光线追踪初始化程序
        // 1.1 绑定帧缓存对象
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.rayFramebuffers[0])
        
        // 1.2 设置能够写入数据的附件
        var drawBuffers = [GLenum(GL_COLOR_ATTACHMENT0),
                           GLenum(GL_COLOR_ATTACHMENT1),
                           GLenum(GL_COLOR_ATTACHMENT2),
                           GLenum(GL_COLOR_ATTACHMENT3),
                           GLenum(GL_COLOR_ATTACHMENT4),
                           GLenum(GL_COLOR_ATTACHMENT5)]
        glDrawBuffers(6, &drawBuffers)
        
        // 1.3 清空第一个颜色附件的缓存
        var blackColor: [GLfloat] = [0, 0, 0, 0]
        glClearBufferfv(GLenum(GL_COLOR), 0, &blackColor)
        
        // 1.4 设置OpenGL程序
        glUseProgram(self.prepareProgram)
        
        // 1.5 设置统一变量的值
        glUniform1f(self.prepareUniformsLocation.yAspect, GLfloat(NSHeight(self.frame) / NSWidth(self.frame)))
        
        // 1.6 设置顶点数组缓存对象
        glBindVertexArray(self.vao)
        
        // 1.7 渲染模型
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)

        // 2. 运行光线追踪计算程序
        // 2.1 设置OpenGL程序
        glUseProgram(self.rayTracerProgram)

        // 2.2 准备球体模型统一变量闭包数据
        var sphereData = [Sphere]()
        for index in 0..<128 {
            var sphere = Sphere()
            let fi = Float(index) / 128
            sphere.centerRadius = GLKVector4Make(sinf(fi * 123 + Float(self.renderDuration * 0.0)) * 15.75,
                                                 cosf(fi * 456 + Float(self.renderDuration * 0.0)) * 15.75,
                                                 (sinf(fi * 300 + Float(self.renderDuration * 0.0)) * cosf(fi * 200 + Float(self.renderDuration * 0.0))) * 20,
                                                 fi * 2.3 + 3.5)
            var r = fi * 61
            var g = r + 0.25
            var b = g + 0.25
            r = (r - floorf(r)) * 0.8 + 0.2
            g = (g - floorf(g)) * 0.8 + 0.2
            b = (b - floorf(b)) * 0.8 + 0.2
            sphere.color = GLKVector4Make(r, g, b, 1)
            sphereData.append(sphere)
        }
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, self.sphereBuffer)
        guard let rawSphereDataAddress = glMapBufferRange(GLenum(GL_UNIFORM_BUFFER), 0, 128 * MemoryLayout<Sphere>.size, GLbitfield(GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT)) else {
            print("Cannot map memory data of sphere buffer.")
            return
        }
        rawSphereDataAddress.initializeMemory(as: Sphere.self, from: &sphereData, count: 128)
        glUnmapBuffer(GLenum(GL_UNIFORM_BUFFER))
        
        // 2.3 准备平面模型统一变量闭包数据
        var planeData = [Plane]()
        var plane1 = Plane()
        plane1.normal = GLKVector3Make(0, 0, -1)
        plane1.d = 30
        planeData.append(plane1)
        
        var plane2 = Plane()
        plane2.normal = GLKVector3Make(0, 0, 1)
        plane2.d = 30
        planeData.append(plane2)
        
        var plane3 = Plane()
        plane3.normal = GLKVector3Make(-1, 0, 0)
        plane3.d = 30
        planeData.append(plane3)
        
        var plane4 = Plane()
        plane4.normal = GLKVector3Make(1, 0, 0)
        plane4.d = 30
        planeData.append(plane4)
        
        var plane5 = Plane()
        plane5.normal = GLKVector3Make(0, -1, 0)
        plane5.d = 30
        planeData.append(plane5)
        
        var plane6 = Plane()
        plane6.normal = GLKVector3Make(0, 1, 0)
        plane6.d = 30
        planeData.append(plane6)
        
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 1, self.planeBuffer)
        guard let planeRawDataAddress = glMapBufferRange(GLenum(GL_UNIFORM_BUFFER), 0, 128 * MemoryLayout<Plane>.size, GLbitfield(GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT)) else {
            print("Cannot map memory data of plane buffer.")
            return
        }
        planeRawDataAddress.initializeMemory(as: Plane.self, from: &planeData, count: 6)
        glUnmapBuffer(GLenum(GL_UNIFORM_BUFFER))
        
        // 2.4 准备光源模型统一变量闭包数据
        var lightData = [Light]()
        for index in 0..<128 {
            let fi = 3.33 - Float(index)
            var light = Light()
            light.position = GLKVector3Make(sinf(fi * 2 - Float(self.renderDuration)) * 15.75,
                                            cosf(fi * 5 - Float(self.renderDuration)) * 5.75,
                                            sinf(fi * 3 - Float(self.renderDuration)) * cosf(fi * 2.5 - Float(self.renderDuration)) * 19.4)
            lightData.append(light)
        }
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 2, self.lightBuffer)
        guard let lightRawDataAdress = glMapBufferRange(GLenum(GL_UNIFORM_BUFFER), 0, 128 * MemoryLayout<Light>.size, GLbitfield(GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT)) else {
            print("Cannot map memory data of light buffer.")
            return
        }
        lightRawDataAdress.initializeMemory(as: Light.self, from: &lightData, count: 128)
        glUnmapBuffer(GLenum(GL_UNIFORM_BUFFER))
        
        // 2.5 设置观察矩阵统一变量的值
        let viewPosition = GLKVector3Make(sinf(Float(self.renderDuration * 0.3234)) * 28,
                                          cosf(Float(self.renderDuration * 0.4234)) * 28,
                                          cosf(Float(self.renderDuration * 0.1234)) * 28)
        let lookatPoint = GLKVector3Make(sinf(Float(self.renderDuration * 0.214)) * 8,
                                         cosf(Float(self.renderDuration * 0.153)) * 8,
                                         sinf(Float(self.renderDuration * 0.734)) * 8)
        var viewMatrix = GLKMatrix4MakeLookAt(viewPosition.x, viewPosition.y, viewPosition.z,
                                              lookatPoint.x, lookatPoint.y, lookatPoint.z,
                                              0, 1, 0)
        withUnsafePointer(to: &viewMatrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.rayTracerUniformsLocation.viewMatrix, 1, GLboolean(GL_FALSE), $0)
            }
        }

        // 2.6 循环绘制场景，多次光线追踪计算
        self.recurse(depth: 0)
        
        // 3. 运行光线追踪结果渲染程序
        // 3.1 绑定默认帧缓存对象
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
                        
        // 3.2 设置OpenGL程序
        glUseProgram(self.blitProgram)
        
        // 3.3 设置统一变量的值
        glActiveTexture(GLenum(GL_TEXTURE0))
        switch self.debugMode {
        case .none:
            glBindTexture(GLenum(GL_TEXTURE_2D), self.compositeTexture)
        case .reflected:
            glBindTexture(GLenum(GL_TEXTURE_2D), self.reflectedTextures[self.debugDepth])
        case .refracted:
            glBindTexture(GLenum(GL_TEXTURE_2D), self.refractedTextures[self.debugDepth])
        case .reflectedColor:
            glBindTexture(GLenum(GL_TEXTURE_2D), self.reflectionIntensityTextures[0])
        case .refractedColor:
            glBindTexture(GLenum(GL_TEXTURE_2D), self.refractionIntensityTextures[self.debugDepth])
        }
        glUniform1i(self.blitTex_compositeLocation, 0)
        
        // 3.4 绘制模型
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
        
        // 4. 清空OpenGL指令缓存，使渲染引擎尽快执行已经发布的渲染指令，同时发布窗口缓存的数据已经做好合并进入系统桌面缓存的准备
        glFlush()
    }
    
    private func recurse(depth: Int) {
        // 1. 绑定帧缓存，首层帧缓存用于光线追踪的准备工作，此次取帧缓存时索引+1
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.rayFramebuffers[depth] + 1)
        
        // 2. 设置可以绘制的附件
        var drawBuffers = [GLenum(GL_COLOR_ATTACHMENT0),
                           GLenum(GL_COLOR_ATTACHMENT1),
                           GLenum(GL_COLOR_ATTACHMENT2),
                           GLenum(GL_COLOR_ATTACHMENT3),
                           GLenum(GL_COLOR_ATTACHMENT4),
                           GLenum(GL_COLOR_ATTACHMENT5)]
        glDrawBuffers(6, &drawBuffers)
        
        // 3. 清除混合颜色附件为0
        var defaultColor: [GLfloat] = [0, 0, 0, 0]
        glClearBufferfv(GLenum(GL_COLOR), 0, &defaultColor)

        // 4. 启用颜色混合功能
        glEnablei(GLenum(GL_BLEND), 0)
        glBlendFunci(0, GLenum(GL_ONE), GLenum(GL_ONE))
                
        // 5. 设置统一变量
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.positionTextures[depth])
        glUniform1i(self.rayTracerUniformsLocation.tex_origin, 0)
        glActiveTexture(GLenum(GL_TEXTURE1))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.reflectedTextures[depth])
        glUniform1i(self.rayTracerUniformsLocation.tex_direction, 1)
        glActiveTexture(GLenum(GL_TEXTURE2))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.reflectionIntensityTextures[depth])
        glUniform1i(self.rayTracerUniformsLocation.tex_color, 2)
        
        // 6. 渲染模型
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
        
        // 7. 进行下一次迭代
        if depth != self.maxDepth - 1 {
            self.recurse(depth: depth + 1)
        }
        
        // 8. 禁用颜色混合模式
        glDisablei(GLenum(GL_BLEND), 0)
    }
}
