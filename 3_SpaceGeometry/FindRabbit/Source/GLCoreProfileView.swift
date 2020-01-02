//
//  GLCoreProfileView.swift
//  FindRabbit
//
//  Created by chenjie on 2019/12/30.
//  Copyright © 2019 chenjie. All rights reserved.
//

import GLKit
import Accelerate

private struct MapProgramUniformsLocation {
    var vpMatrix: GLint = 0
    var floorTexture: GLint = 0
}

private struct RabbitProgramUniformsLocation {
    var viewMatrix: GLint = 0
    var perspectiveMatrix: GLint = 0
}

class GLCoreProfileView: NSOpenGLView {
    //MARK:- Public properties
    // 除去暂停后实际渲染的时间
    var renderDuration: TimeInterval = 0
    // 当前观察点在世界坐标系xz平面的位置，其每个分量的取值范围都是[-64, 64]
    var location = CGPoint(x: 0, y: 0)
    // 当前视线的观察方向，取值范围为[0, 360)
    var course: Float = 0
    // 当前视线的俯仰角，取值范围为[0, 90]
    var verticalViewAngle: Float = 0
    // 相机观察方向，单位向量
    var viewDirection = simd_float3(x: 0, y: 0, z: -1)

    //MARK:- Private Properties
    private var mapProgram: GLuint = 0
    private var mapProgramVAO: GLuint = 0
    private var mapProgramFloorTexture: GLuint = 0
    private var mapProgramUniformsLocation = MapProgramUniformsLocation()
    
    private var rabbitProgram: GLuint = 0
    private var rabbitUniformBlockBuffer: GLuint = 0
    private var rabbitProgramUnifromsLocation = RabbitProgramUniformsLocation()
    // 每个兔子模型映射到世界坐标系时的平移矩阵
    private var rabbitTranslationMatrixs = [GLKMatrix4]()
    
    //MARK:- Life Cycles
    override init?(frame frameRect: NSRect, pixelFormat format: NSOpenGLPixelFormat?) {
        super.init(frame: frameRect, pixelFormat: format)
        // 禁用Retina屏幕显示
        self.wantsBestResolutionOpenGLSurface = false

        self.prepareOpenGLContex()
        
        // 准备渲染所必须的数据
        for _ in 0..<64 {
            let translationMatrix = GLKMatrix4MakeTranslation(Float.random(in: -64...64), Float.random(in: 0...5), Float.random(in: -64...64))
            self.rabbitTranslationMatrixs.append(translationMatrix)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        glDeleteProgram(self.mapProgram)
        glDeleteVertexArrays(1, &self.mapProgramVAO)
        glDeleteTextures(1, &self.mapProgramFloorTexture)
        
        glDeleteProgram(self.rabbitProgram)
        glDeleteBuffers(1, &self.rabbitUniformBlockBuffer)
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
        
        // 2. 加载地图程序所需要的纹理
        let textureLoaded = TextureManager.shareManager.loadObject(fileName: "floor.ktx", toTexture: &self.mapProgramFloorTexture, atIndex: GL_TEXTURE0)
        if !textureLoaded {
            print("Load texture failed")
            return
        }

        // 3. 创建地图程序所需要使用到的VAO对象
        glGenVertexArrays(1, &self.mapProgramVAO)
        
        // 4. 加载兔子程序所需要使用到的模型
        let modelLoaded = ModelManager.shareManager.loadObject(fileName: "bunny_1k.sbm")
        if !modelLoaded {
            print("Load model failed")
        }
        
        // 5. 准备地图程序所需要使用到的统一闭包缓存
        glGenBuffers(1, &self.rabbitUniformBlockBuffer)
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, self.rabbitUniformBlockBuffer)
        glBufferData(GLenum(GL_UNIFORM_BUFFER), MemoryLayout<GLKMatrix4>.stride * 64, nil, GLenum(GL_DYNAMIC_DRAW))
    }

    private func prepareOpenGLProgram() -> Bool {
        // 1. 准备地图OpenGL程序
        let mapShaders = ["MapVertexShader" : GLenum(GL_VERTEX_SHADER),
                          "MapFragmentShader" : GLenum(GL_FRAGMENT_SHADER)]
        let mapProgramSuccessed = self.prepareGLProgram(&self.mapProgram, shaders: mapShaders)
        if !mapProgramSuccessed {
            return false
        }

        self.mapProgramUniformsLocation.vpMatrix = glGetUniformLocation(self.mapProgram, "vpMatrix")
        self.mapProgramUniformsLocation.floorTexture = glGetUniformLocation(self.mapProgram, "floorTexture")
        
        // 2. 准备兔子OpenGL程序
        let rabbitShaders = ["RabbitVertexShader" : GLenum(GL_VERTEX_SHADER),
                             "RabbitFragmentShader" : GLenum(GL_FRAGMENT_SHADER)]
        let rabbitProgramSuccessed = self.prepareGLProgram(&self.rabbitProgram, shaders: rabbitShaders)
        if !rabbitProgramSuccessed {
            return false
        }
        
        self.rabbitProgramUnifromsLocation.viewMatrix = glGetUniformLocation(self.rabbitProgram, "viewMatrix")
        self.rabbitProgramUnifromsLocation.perspectiveMatrix = glGetUniformLocation(self.rabbitProgram, "perspectiveMatrix")
        let uniformBlockIndex = glGetUniformBlockIndex(self.rabbitProgram, "ModelMatrixs")
        glUniformBlockBinding(self.rabbitProgram, uniformBlockIndex, 0)
        
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
        // 1. 绘制地板
        // 1.1 禁用面剔除和深度测试
        glDisable(GLenum(GL_CULL_FACE))
        glDisable(GLenum(GL_DEPTH_TEST))
        
        // 1.2 清空颜色缓存
        var blackColor: [GLfloat] = [0.1, 0.1, 0.1, 1]
        glClearBufferfv(GLenum(GL_COLOR), 0, &blackColor)
        
        // 1.3 设置OpenGL程序
        glUseProgram(self.mapProgram)
        
        // 1.4 为统一变量赋值
        // 为观察投影矩阵赋值
        let eyePosition = simd_float3(x: Float(self.location.x), y: 1, z: Float(self.location.y))
        let poi = eyePosition + self.viewDirection
        var viewMatrix = GLKMatrix4MakeLookAt(eyePosition.x, eyePosition.y, eyePosition.z,
                                              poi.x, poi.y, poi.z,
                                              0, 1, 0)
        var perspectiveMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50),
                                                          Float(NSWidth(self.frame)/NSHeight(self.frame)),
                                                          0.1, 1000)
        var vpMatrix = GLKMatrix4Multiply(perspectiveMatrix, viewMatrix)
        withUnsafePointer(to: &vpMatrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.mapProgramUniformsLocation.vpMatrix, 1, GLboolean(GL_FALSE), $0)
            }
        }
        
        // 为地板纹理赋值
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), self.mapProgramFloorTexture)
        glUniform1i(self.mapProgramUniformsLocation.floorTexture, 0)

        // 1.5 设置地图OpenGL程序需要使用的VAO对象
        glBindVertexArray(self.mapProgramVAO)

        // 1.6 绘制128*128个地砖
        glDrawArraysInstanced(GLenum(GL_TRIANGLE_STRIP), 0, 4, 128 * 128)
        
        // 2. 绘制64个兔子模型
        // 2.1 开启面剔除和深度测试
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_DEPTH_TEST))
        glDepthFunc(GLenum(GL_LEQUAL))
        
        // 2.2 设置深度缓存默认值
        var defaultDepth: GLfloat = 1
        glClearBufferfv(GLenum(GL_DEPTH), 0, &defaultDepth)
        
        // 2.3 设置OpenGL程序
        glUseProgram(self.rabbitProgram)
        
        // 2.4 为统一变量赋值
        // 填充模型矩阵的统一闭包数据
        var matrixData = [GLKMatrix4]()
        for index in 0..<64 {
            let rotationMatrix = GLKMatrix4MakeYRotation(Float(self.renderDuration))
            let modelMatrix = GLKMatrix4Multiply(self.rabbitTranslationMatrixs[index], rotationMatrix)
            matrixData.append(modelMatrix)
        }
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, self.rabbitUniformBlockBuffer)
        guard let dataAdress = glMapBufferRange(GLenum(GL_UNIFORM_BUFFER), 0, MemoryLayout<GLKMatrix4>.stride * 64, GLbitfield(GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT)) else {
            return
        }
        dataAdress.initializeMemory(as: GLKMatrix4.self, from: &matrixData, count: 64)
        glUnmapBuffer(GLenum(GL_UNIFORM_BUFFER))
        
        // 设置观察矩阵
        withUnsafePointer(to: &viewMatrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.rabbitProgramUnifromsLocation.viewMatrix, 1, GLboolean(GL_FALSE), $0)
            }
        }
        
        // 设置投影矩阵
        withUnsafePointer(to: &perspectiveMatrix.m) {
            $0.withMemoryRebound(to: GLfloat.self, capacity: 16) {
                glUniformMatrix4fv(self.rabbitProgramUnifromsLocation.perspectiveMatrix, 1, GLboolean(GL_FALSE), $0)
            }
        }

        // 2.5 绘制模型
        ModelManager.shareManager.render(instanceCount: 64)

        // 3. 清空OpenGL指令缓存，使渲染引擎尽快执行已经发布的渲染指令，同时发布窗口缓存的数据已经做好合并进入系统桌面缓存的准备
        glFlush()
    }
}
