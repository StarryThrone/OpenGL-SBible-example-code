//
//  GLCoreProfileView.m
//  ConfigureEnvironment
//
//  Created by 陈杰 on 26/10/2017.
//  Copyright © 2017 陈杰. All rights reserved.
//

#import "GLCoreProfileView.h"
#import <OpenGL/OpenGL.h>
#import <GLKit/GLKit.h>
#import "TextureManager.h"
#import "TDModelManger.h"

typedef NS_ENUM(NSUInteger, GLCoreProfileViewRenderMode) {
    GLCoreProfileViewRenderModeA,
    GLCoreProfileViewRenderModeB,
    GLCoreProfileViewRenderModeC
};

#define MAX_SCENE_WIDTH 1024
#define MAX_SCENE_HEIGHT 1024
#define SPHERE_COUNT 32

@interface GLCoreProfileView()
{
    GLuint filterFrameBufferObject[2];
    GLuint filterTexture[2];
}

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) GLCoreProfileViewRenderMode renderMode;

@property (atomic, assign) GLuint vertexArrayObject;
// 绘制原始图像场景，和高亮部分图像场景的GL程序
@property (atomic, assign) GLuint sceneProgram;
// 场景程序的帧缓存对象
@property (atomic, assign) GLuint sceneFrameBufferObject;
// 场景程序的基础图像纹理
@property (atomic, assign) GLuint sceneBasicTexture;
// 场景程序的高亮细节纹理
@property (atomic, assign) GLuint sceneBrightPassTexture;
// 场景程序的深度纹理
@property (atomic, assign) GLuint sceneDepthTexture;
// 场景程序矩阵统一闭包缓存对象
@property (atomic, assign) GLuint sceneTransformUBO;
// 场景程序材质统一闭包缓存对象
@property (atomic, assign) GLuint sceneMaterialUBO;
// 场景程序辉光处理低值
@property (atomic, assign) GLint sceneBloomThreshMinLocation;
@property (atomic, assign) float bloom_thresh_min;
// 场景程序辉光处理高值
@property (atomic, assign) GLint sceneBloomThreshMaxLocation;
@property (atomic, assign) float bloom_thresh_max;

// 处理高亮细节纹理的滤镜程序
@property (atomic, assign) GLuint filterProgram;

// 混合基础图像纹理和高亮细节纹理的程序
@property (atomic, assign) GLuint resolveProgram;
@property (atomic, assign) GLint resolveExposureLocation;
@property (atomic, assign) float exposure;
@property (atomic, assign) GLint resolveBloomFactorLocation;
@property (atomic, assign) float bloom_factor;
@property (atomic, assign) GLint resolveSceneFactorLocation;
// 基础图像纹理索引
@property (atomic, assign) GLint resolveHDRImageLocation;
// 高亮细节纹理索引
@property (atomic, assign) GLint resolveBloomImageLocation;

// 其他控制绘制效果的属性
@property (atomic, assign) BOOL showBloom;
@property (atomic, assign) BOOL showScene;
@property (atomic, assign) BOOL showPreFilter;

@end

@implementation GLCoreProfileView
#pragma mark - lifecycle methods
- (instancetype)initWithCoder:(NSCoder *)decoder {
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
    NSOpenGLContext *openGLContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    
    
    if (self = [super initWithCoder:decoder]) {
        [self initializeProperties];
        [self setOpenGLContext:openGLContext];
        [self.openGLContext makeCurrentContext];
        GLint sync = 1;
        CGLSetParameter(CGLGetCurrentContext(), kCGLCPSwapInterval, &sync);
        
        _lifeTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(lifeTimerUpdate) userInfo:nil repeats:YES];
        _paused = NO;
    
        __weak __typeof(self) weakself = self;
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull aEvent) {
            [weakself keyDown:aEvent];
            return aEvent;
        }];
        
    }
    return self;
}

- (void)initializeProperties {
    _exposure = 1.0f;
    _bloom_factor = 1.0f;
    _showBloom = YES;
    _showScene = YES;
    _bloom_thresh_min = 0.8f;
    _bloom_thresh_max = 1.2f;
    _showPreFilter = NO;
}

- (void)keyDown:(NSEvent *)event {
    if ([event.characters isEqualToString:@"f"]) {
        
    } else if ([event.characters isEqualToString:@"d"]) {

    } else if ([event.characters isEqualToString:@"w"]) {
    } else if ([event.characters isEqualToString:@"p"]) {
        self.paused = !self.paused;
    } else if ([event.characters isEqualToString:@"+"]) {

    } else if ([event.characters isEqualToString:@"-"]) {

    }
    NSLog(@"%@",event.characters);
}

- (void)dealloc {
    [_lifeTimer invalidate];
    _lifeTimer = nil;

//    glDeleteBuffers(1, &_patchBuffer);
//    glDeleteBuffers(1, &_cageIndicesBuffer);
//    glDeleteVertexArrays(1, &_vertexArray);
//    glDeleteProgram(_tessProgram);
//    glDeleteProgram(_deawCpProgram);
}

- (void)prepareOpenGL {
    [super prepareOpenGL];
    
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [self loadShaders];
    
    glGenVertexArrays(1, &_vertexArrayObject);
    glBindVertexArray(self.vertexArrayObject);
    
    // 1. 准备场景纹理帧缓存对象
    glGenFramebuffers(1, &_sceneFrameBufferObject);
    glBindFramebuffer(GL_FRAMEBUFFER, self.sceneFrameBufferObject);
    // 准备基础图像纹理
    glGenTextures(1, &_sceneBasicTexture);
    glBindTexture(GL_TEXTURE_2D, self.sceneBasicTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, MAX_SCENE_WIDTH, MAX_SCENE_HEIGHT, 0, GL_RGBA, GL_FLOAT, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, self.sceneBasicTexture, 0);
    // 准备高亮细节纹理
    glGenTextures(1, &_sceneBrightPassTexture);
    glBindTexture(GL_TEXTURE_2D, self.sceneBrightPassTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, MAX_SCENE_WIDTH, MAX_SCENE_HEIGHT, 0, GL_RGBA, GL_FLOAT, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, self.sceneBrightPassTexture, 0);
    // 准备深度纹理
    glGenTextures(1, &_sceneDepthTexture);
    glBindTexture(GL_TEXTURE_2D, self.sceneDepthTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32F, MAX_SCENE_WIDTH, MAX_SCENE_HEIGHT, 0, GL_DEPTH_COMPONENT, GL_FLOAT, NULL);
    glFramebufferTexture(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, self.sceneDepthTexture, 0);
    static const GLenum buffers[] = { GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1 };
    glDrawBuffers(2, buffers);
    // 判断帧缓存状态
    GLenum sceneFrameBufferObjectStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (sceneFrameBufferObjectStatus != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"ee");
    }
    
    // 2. 准备场景程序片段着色器中需要使用到的闭包缓存
    // 准备矩阵缓存
    glGenBuffers(1, &_sceneTransformUBO);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, self.sceneTransformUBO);
    glBufferData(GL_UNIFORM_BUFFER, (2 + SPHERE_COUNT) * sizeof(GLKMatrix4), NULL, GL_DYNAMIC_DRAW);
    
    // 应该使用这种简洁的数据结构，但是这样在着色器中无法取到specular_power的只，需要进一步查明原因
    //    typedef struct _material {
    //        GLKVector3 diffuse_color;
    //        unsigned int : 32; // pad
    //        GLKVector3 specular_color;
    //        float specular_power;
    //        GLKVector3 ambient_color;
    //        unsigned int : 32; // pad
    //    } material;
    // 准备材质缓存并填充数据
    typedef struct _material {
        GLKVector3 diffuse_color;
        unsigned int : 32; // pad
        GLKVector3 specular_color;
        unsigned int : 32; // pad
        GLKVector3 specular_power;
        unsigned int : 32; // pad
        GLKVector3 ambient_color;
        unsigned int : 32; // pad
    } material;
    glGenBuffers(1, &_sceneMaterialUBO);
    glBindBufferBase(GL_UNIFORM_BUFFER, 1, self.sceneMaterialUBO);
    glBufferData(GL_UNIFORM_BUFFER, SPHERE_COUNT * sizeof(material), NULL, GL_STATIC_DRAW);
    material *m = (material *)glMapBufferRange(GL_UNIFORM_BUFFER, 0, SPHERE_COUNT * sizeof(material), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    float ambient = 0.002f;
    for (int i = 0; i < SPHERE_COUNT; i++) {
        float fi = M_PI * i / 8.0f;
        m[i].diffuse_color = GLKVector3Make(sinf(fi) * 0.5f + 0.5f,
                                            sinf(fi + 1.345f) * 0.5f + 0.5f,
                                            sinf(fi + 2.567f) * 0.5f + 0.5f);
        m[i].specular_color = GLKVector3Make(2.8f, 2.8f, 2.9f);
        m[i].specular_power = GLKVector3Make(30.0f, 30.0f, 30.0f);;
        float ambientColor = ambient * 0.025f;
        m[i].ambient_color = GLKVector3Make(ambientColor , ambientColor, ambientColor);
        ambient *= 1.5f;
    }
    glUnmapBuffer(GL_UNIFORM_BUFFER);
    
    // 3. 加载场景程序绘制所需要的模型
    [[TDModelManger shareManager] loadObjectWithFileName:@"sphere.sbm"];
    
    // 4. 准备滤镜程序的帧缓存对象
    glGenFramebuffers(2, &filterFrameBufferObject[0]);
    glGenTextures(2, &filterTexture[0]);
    for (int i = 0; i < 2; i++) {
        glBindFramebuffer(GL_FRAMEBUFFER, filterFrameBufferObject[i]);
        glBindTexture(GL_TEXTURE_2D, filterTexture[i]);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, i ? MAX_SCENE_WIDTH : MAX_SCENE_HEIGHT, i ? MAX_SCENE_HEIGHT : MAX_SCENE_WIDTH, 0, GL_RGBA, GL_FLOAT, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, filterTexture[i], 0);
        glDrawBuffers(1, buffers);
        
        // 判断帧缓存状态
        GLenum filterFrameBufferObjectStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (filterFrameBufferObjectStatus != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"ee");
        }
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

- (void)reshape {
    [super reshape];
    
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    static double last_time = 0.0;
    static double total_time = 0.0;
    if (!_paused) {
        total_time += (_lifeDuration - last_time);
    }
    last_time = _lifeDuration;
    
    // 1.首先绘制场景程序，完成基础场景图像、和高亮细节纹理的渲染
    glBindFramebuffer(GL_FRAMEBUFFER, self.sceneFrameBufferObject);
    glViewport(0, 0, MAX_SCENE_WIDTH, MAX_SCENE_HEIGHT);
    // 清空颜色和深度缓存
    static const GLfloat black[] = { 0.0f, 0.0f, 0.0f, 1.0f };
    glClearBufferfv(GL_COLOR, 0, black);
    glClearBufferfv(GL_COLOR, 1, black);
    static const GLfloat one = 1.0f;
    glClearBufferfv(GL_DEPTH, 0, &one);
    
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);

    glUseProgram(self.sceneProgram);
    
    // 为矩阵统一闭包缓存赋值
    typedef struct _transform {
        GLKMatrix4 mat_proj;
        GLKMatrix4 mat_view;
        GLKMatrix4 mat_model[SPHERE_COUNT];
    } transform;
    glBindBuffer(GL_UNIFORM_BUFFER, self.sceneTransformUBO);
    transform *m = (transform *)glMapBufferRange(GL_UNIFORM_BUFFER, 0, sizeof(transform), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    m->mat_proj = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0f), MAX_SCENE_WIDTH/MAX_SCENE_HEIGHT, 1.0f, 1000.0f);
    m->mat_view = GLKMatrix4MakeTranslation(0.0f, 0.0f, -20.0f);
    for (int i = 0; i < SPHERE_COUNT; i++) {
        float fi = M_PI * i / 16.0f;
        float r = (i & 2) ? 0.6f : 1.5f;
        m->mat_model[i] = GLKMatrix4MakeTranslation(cosf(GLKMathDegreesToRadians(total_time) + fi) * 5.0f * r,
                                                    sinf(GLKMathDegreesToRadians(total_time) + fi * 4.0f) * 4.0f,
                                                    sinf(GLKMathDegreesToRadians(total_time) + fi) * 5.0f * r);
    }
    glUnmapBuffer(GL_UNIFORM_BUFFER);
    // 设置辉光效果的阈值
    glUniform1f(self.sceneBloomThreshMinLocation, self.bloom_thresh_min);
    glUniform1f(self.sceneBloomThreshMaxLocation, self.bloom_thresh_max);
    // 绘制模型，渲染场景
    glBindVertexArray([TDModelManger shareManager].vao);
    [[TDModelManger shareManager] renderWithInstanceCount:SPHERE_COUNT];
    
    // 2. 使用滤镜程序对场景程序渲染的高亮细节纹理再处理，通过两次渲染实现类似卷积的思想对纹理进行模糊处理
    glDisable(GL_DEPTH_TEST);
    // 通过卷积的思想对筛选出的亮度数据进行模糊处理，其卷积核为25*25的矩阵
    glUseProgram(self.filterProgram);
    glBindVertexArray(self.vertexArrayObject);
    // 纹理垂直方向模糊
    glBindFramebuffer(GL_FRAMEBUFFER, filterFrameBufferObject[0]);
    glBindTexture(GL_TEXTURE_2D, self.sceneBrightPassTexture);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    // 纹理水平方向模糊
    glBindFramebuffer(GL_FRAMEBUFFER, filterFrameBufferObject[1]);
    glBindTexture(GL_TEXTURE_2D, filterTexture[0]);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    // 3. 使用解析程序将场景程序渲染的基础图像纹理，和滤镜程序渲染好的高亮细节纹理混合，并且提高曝光度，得到最后的图像
    glUseProgram(self.resolveProgram);
    glUniform1f(self.resolveExposureLocation, self.exposure);
    if (self.showPreFilter) {
        glUniform1f(self.resolveBloomFactorLocation, 0.0f);
        glUniform1f(self.resolveSceneFactorLocation, 1.0f);
    } else {
        glUniform1f(self.resolveBloomFactorLocation, self.showBloom ? self.bloom_factor : 0.0f);
        glUniform1f(self.resolveSceneFactorLocation, self.showScene ? 1.0f : 0.0f);
    }
    // 开启窗口帧缓存
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
    glClearBufferfv(GL_COLOR, 0, black);
    // 绑定原始图像纹理
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, self.showPreFilter ? self.sceneBrightPassTexture : self.sceneBasicTexture);
    glUniform1i(self.resolveHDRImageLocation, 1);
    // 绑定模糊处理后的高亮细节纹理
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, filterTexture[1]);
    glUniform1i(self.resolveBloomImageLocation, 0);
    // 渲染图像
    glBindVertexArray(self.vertexArrayObject);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    // 交互缓存
    glFlush();
}

#pragma mark - private methods
- (BOOL)loadShaders {
    GLuint vertex_Shader, frag_Shader;
    NSString *vs_Path = nil, *fs_Path = nil;
    // 1. Create Scene program
    vs_Path = [[NSBundle mainBundle] pathForResource:@"hdrBloomSceneVS" ofType:@"glsl"];
    fs_Path = [[NSBundle mainBundle] pathForResource:@"hdrBloomSceneFS" ofType:@"glsl"];
    
    if (![self compileShader:&vertex_Shader type:GL_VERTEX_SHADER filePath:vs_Path]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&frag_Shader type:GL_FRAGMENT_SHADER filePath:fs_Path]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    self.sceneProgram = glCreateProgram();
    glAttachShader(self.sceneProgram, vertex_Shader);
    glAttachShader(self.sceneProgram, frag_Shader);
    glDeleteShader(vertex_Shader);
    vertex_Shader = 0;
    glDeleteShader(frag_Shader);
    frag_Shader = 0;
    
    if (![self linkProgram:self.sceneProgram]) {
        NSLog(@"Failed to link sceneProgram");
        if (self.sceneProgram != 0) {
            glDeleteProgram(self.sceneProgram);
            self.sceneProgram = 0;
        }
        return NO;
    }
    self.sceneBloomThreshMinLocation = glGetUniformLocation(self.sceneProgram, "bloom_thresh_min");
    self.sceneBloomThreshMaxLocation = glGetUniformLocation(self.sceneProgram, "bloom_thresh_max");
    GLuint transformsBlockUnifromIndex = glGetUniformBlockIndex(self.sceneProgram, "TRANSFORM_BLOCK");
    glUniformBlockBinding(self.sceneProgram, transformsBlockUnifromIndex, 0);
    GLuint materialsBlockUniformIndex = glGetUniformBlockIndex(self.sceneProgram, "MATERIAL_BLOCK");
    glUniformBlockBinding(self.sceneProgram, materialsBlockUniformIndex, 1);

    // 2. Create naive filterProgram
    vs_Path = [[NSBundle mainBundle] pathForResource:@"hdrBloomFilterVS" ofType:@"glsl"];
    fs_Path = [[NSBundle mainBundle] pathForResource:@"hdrBloomFilterFS" ofType:@"glsl"];
    
    if (![self compileShader:&vertex_Shader type:GL_VERTEX_SHADER filePath:vs_Path]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&frag_Shader type:GL_FRAGMENT_SHADER filePath:fs_Path]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }

    self.filterProgram = glCreateProgram();
    glAttachShader(self.filterProgram, vertex_Shader);
    glAttachShader(self.filterProgram, frag_Shader);
    glDeleteShader(vertex_Shader);
    vertex_Shader = 0;
    glDeleteShader(frag_Shader);
    frag_Shader = 0;

    if (![self linkProgram:self.filterProgram]) {
        NSLog(@"Failed to link filterProgram");
        if (self.filterProgram != 0) {
            glDeleteProgram(self.filterProgram);
            self.filterProgram = 0;
        }
        return NO;
    }
    
    // 3. Create resolve program
    vs_Path = [[NSBundle mainBundle] pathForResource:@"hdrBloomResolveVS" ofType:@"glsl"];
    fs_Path = [[NSBundle mainBundle] pathForResource:@"hdrBloomResolveFS" ofType:@"glsl"];

    if (![self compileShader:&vertex_Shader type:GL_VERTEX_SHADER filePath:vs_Path]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&frag_Shader type:GL_FRAGMENT_SHADER filePath:fs_Path]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    self.resolveProgram = glCreateProgram();
    glAttachShader(self.resolveProgram, vertex_Shader);
    glAttachShader(self.resolveProgram, frag_Shader);
    glDeleteShader(vertex_Shader);
    vertex_Shader = 0;
    glDeleteShader(frag_Shader);
    frag_Shader = 0;
    
    if (![self linkProgram:self.resolveProgram]) {
        NSLog(@"Failed to link resolveProgram");
        if (self.resolveProgram != 0) {
            glDeleteProgram(self.resolveProgram);
            self.resolveProgram = 0;
        }
        return NO;
    }
    self.resolveExposureLocation = glGetUniformLocation(self.resolveProgram, "exposure");
    self.resolveBloomFactorLocation = glGetUniformLocation(self.resolveProgram, "bloom_factor");
    self.resolveSceneFactorLocation = glGetUniformLocation(self.resolveProgram, "scene_factor");
    self.resolveBloomImageLocation = glGetUniformLocation(self.resolveProgram, "bloom_image");
    self.resolveHDRImageLocation = glGetUniformLocation(self.resolveProgram, "hdr_image");

    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type filePath:(NSString *)path {
    const GLchar *shaderSource = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil].UTF8String;
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &shaderSource, nil);
    glCompileShader(*shader);
    
    GLint status = 0;
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        GLint logLen = 0;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLen);
        GLchar *infoLog = malloc(sizeof(char) * logLen);
        glGetShaderInfoLog(*shader, logLen, NULL, infoLog);
        NSLog(@"Shader at: %@", path);
        fprintf(stderr, "Info Log: %s\n", infoLog);
        
        glDeleteShader(*shader);
        return NO;
    }
    return YES;
}

- (BOOL)linkProgram:(GLuint)program {
    glLinkProgram(program);
    GLint status = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == 0) {
        GLint logLen = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLen);
        GLchar *infoLog = malloc(sizeof(char) * logLen);
        glGetProgramInfoLog(program, logLen, NULL, infoLog);
        fprintf(stderr, "Prog Info Log: %s\n", infoLog);
        return NO;
    }
    return YES;
}

#pragma mark - listening methods
- (void)lifeTimerUpdate {
    _lifeDuration += _lifeTimer.timeInterval;
    // _lifeDuration为程序运行时间
    [self drawRect:self.bounds];
}

#pragma mark - accessor methods

@end



