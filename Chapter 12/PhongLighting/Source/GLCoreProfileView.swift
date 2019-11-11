//
//  GLCoreProfileView.swift
//  PhongLighting
//
//  Created by chenjie on 2019/11/8.
//  Copyright © 2019 chenjie. All rights reserved.
//

import GLKit

struct UniformsBlock {
    var viewMatrix: GLKMatrix4
    var modelViewMatrix: GLKMatrix4
    var projectionMatrix: GLKMatrix4
}

struct UniformLocation {
    var ambientColorLocation: GLint
    var diffuseAlbedoLocation: GLint
    var specularAlbedoLocation: GLint
    var specularPowerLocation: GLint
}

class GLCoreProfileView: NSOpenGLView {
    //MARK:- Public properties
    // 除去暂停后实际渲染的时间
    var renderDuration: TimeInterval = 0
    var per_vertex = false
    var many_objects = false

    //MARK:- Private Properties    
    private var perFragmentProgram: GLuint = 0
    private var perVertexProgram: GLuint = 0
    private var uniformsBuffer: GLuint = 0
    private var perfragmentUniformsLocation: UniformLocation!
    private var perVertexUnifromsLocation: UniformLocation!
    
    //MARK:- Life Cycles
    override init?(frame frameRect: NSRect, pixelFormat format: NSOpenGLPixelFormat?) {
        super.init(frame: frameRect, pixelFormat: format)
        
        self.prepareOpenGLContex()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        if !self.preparePerVertexProgram() {
            return
        }
        if !self.preparePerFragmentProgram() {
            return
        }
                
        // 2. 为统一变量准备缓存
        glGenBuffers(1, &self.uniformsBuffer)
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, self.uniformsBuffer)
        glBufferData(GLenum(GL_UNIFORM_BUFFER), MemoryLayout<UniformsBlock>.stride, nil, GLenum(GL_DYNAMIC_DRAW))
        glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, 0)

        // 3. 加载模型
        let successed = ModelManager.shareManager.loadObject(fileName: "sphere.sbm")
        if !successed {
            return
        }
        
        // 4. 开启面剔除和深度检测
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_DEPTH_TEST))
        glDepthFunc(GLenum(GL_LEQUAL))
    }
    
    private func preparePerFragmentProgram() -> Bool {
        let shaders = ["perFragmentVS" : GLenum(GL_VERTEX_SHADER), "perFragmentFS" : GLenum(GL_FRAGMENT_SHADER)]
        let successed = self.prepareGLProgram(&self.perFragmentProgram, shaders: shaders)
        if successed {
            self.perfragmentUniformsLocation = self.unifromLocation(inProgram: self.perFragmentProgram)
            
            let matrixUniformBlockIndex = glGetUniformBlockIndex(self.perFragmentProgram, "transformMatrixs")
            glUniformBlockBinding(self.perFragmentProgram, matrixUniformBlockIndex, 0)
        }
        return successed
    }
    
    private func preparePerVertexProgram() -> Bool {
        let shaders = ["perVertexVS" : GLenum(GL_VERTEX_SHADER), "perVertexFS" : GLenum(GL_FRAGMENT_SHADER)]
        let successed = self.prepareGLProgram(&self.perVertexProgram, shaders: shaders)
        if successed {
            self.perVertexUnifromsLocation = self.unifromLocation(inProgram: self.perVertexProgram)
            
            let matrixUniformBlockIndex = glGetUniformBlockIndex(self.perVertexProgram, "transformMatrixs")
            glUniformBlockBinding(self.perVertexProgram, matrixUniformBlockIndex, 0)
        }
        return successed
    }
    
    private func unifromLocation(inProgram program: GLuint) -> UniformLocation {
        let ambientColorLocation = glGetUniformLocation(program, "ambient")
        let diffuseAlbedoLocation = glGetUniformLocation(program, "diffuseAlbedo")
        let specularAlbedoLocation = glGetUniformLocation(program, "specularAlbedo")
        let specularPowerLocation = glGetUniformLocation(program, "specularPower")
        let uniformLocation = UniformLocation(ambientColorLocation: ambientColorLocation, diffuseAlbedoLocation: diffuseAlbedoLocation, specularAlbedoLocation: specularAlbedoLocation, specularPowerLocation: specularPowerLocation)
        return uniformLocation
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
                print("Can not find shader file at" + shaderInfo.key)
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
        let grayColor:[GLfloat] = [0.1, 0.1, 0.1, 0]
        glClearBufferfv(GLenum(GL_COLOR), 0, grayColor)
        var defaultDepth:GLfloat = 1;
        glClearBufferfv(GLenum(GL_DEPTH), 0, &defaultDepth)

        // 2. 设置OpenGL程序
        if self.per_vertex {
            glUseProgram(self.perVertexProgram)
        } else {
            glUseProgram(self.perFragmentProgram)
        }

        let viewPosition = GLKVector3(v: (0, 0, 20))
        let viewMatrix = GLKMatrix4MakeLookAt(viewPosition.x, viewPosition.y, viewPosition.z,
                                              0, 0, 0,
                                              0, 1, 0)

        if self.many_objects {
            for j in 0...6 {
                for i in 0...6 {
                    // 3. 填充放射矩阵缓存数据
                    glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, self.uniformsBuffer)
                    guard let blockAddress = glMapBufferRange(GLenum(GL_UNIFORM_BUFFER), 0, MemoryLayout<UniformsBlock>.size, GLbitfield(GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT)) else { return }
                    let blockTypeAddress = blockAddress.bindMemory(to: UniformsBlock.self, capacity: 1)

                    let modelMatrix = GLKMatrix4MakeTranslation(Float(i) * 2.75 - 8.25, 6.75 - Float(j) * 2.25, 0)
                    let modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix)
                    let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50),
                                                                     Float(NSWidth(self.bounds) / NSHeight(self.bounds)),
                                                                     0.1,
                                                                     1000)
                    let uniformBlocl = UniformsBlock(viewMatrix: viewMatrix, modelViewMatrix: modelViewMatrix, projectionMatrix: projectionMatrix)
                    blockTypeAddress.pointee = uniformBlocl
                    glUnmapBuffer(GLenum(GL_UNIFORM_BUFFER))

                    // 4. 填充材质属性数据
                    var specularAlbedo = [GLfloat](repeating: (Float(i) + 1) / 9, count: 3)
                    let specularPower = GLfloat(powf(2, Float(j) + 2))
                    if self.per_vertex {
                        glUniform3fv(self.perVertexUnifromsLocation.specularAlbedoLocation, 1, &specularAlbedo)
                        glUniform1f(self.perVertexUnifromsLocation.specularPowerLocation, specularPower)
                    } else {
                        glUniform3fv(self.perfragmentUniformsLocation.specularAlbedoLocation, 1, &specularAlbedo)
                        glUniform1f(self.perfragmentUniformsLocation.specularPowerLocation, specularPower)
                    }

                    // 5. 渲染
                    ModelManager.shareManager.render()
                    
                    // 6. 复原OpenGL上下文相关绑定点状态
                    glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, 0)
                }
            }
        } else {
            // 3. 填充放射矩阵缓存数据
            glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, self.uniformsBuffer)
            guard let blockAddress = glMapBufferRange(GLenum(GL_UNIFORM_BUFFER), 0, MemoryLayout<UniformsBlock>.stride, GLbitfield(GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT)) else { return }
            let blockTypeAddress = blockAddress.bindMemory(to: UniformsBlock.self, capacity: 1)
            
            let modelMatrix = GLKMatrix4MakeScale(7, 7, 7)
            let modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix)
            let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50),
                                                             Float(NSWidth(self.bounds) / NSHeight(self.bounds)),
                                                             0.1,
                                                             1000)
            let unifromBlock = UniformsBlock(viewMatrix: viewMatrix, modelViewMatrix: modelViewMatrix, projectionMatrix: projectionMatrix)
            blockTypeAddress.pointee = unifromBlock
            glUnmapBuffer(GLenum(GL_UNIFORM_BUFFER))

            // 4. 填充材质属性数据
            var specularAlbedo: [GLfloat] = [1, 1, 1]
            let specularPower: Float = 30
            if self.per_vertex {
                glUniform3fv(self.perVertexUnifromsLocation.specularAlbedoLocation, 1, &specularAlbedo)
                glUniform1f(self.perVertexUnifromsLocation.specularPowerLocation, specularPower)
            } else {
                glUniform3fv(self.perfragmentUniformsLocation.specularAlbedoLocation, 1, &specularAlbedo)
                glUniform1f(self.perfragmentUniformsLocation.specularPowerLocation, specularPower)
            }

            // 5. 渲染
            ModelManager.shareManager.render()
            
            // 6. 复原OpenGL上下文相关绑定点状态
            glBindBufferBase(GLenum(GL_UNIFORM_BUFFER), 0, 0)
        }
        glFlush()
    }
}
