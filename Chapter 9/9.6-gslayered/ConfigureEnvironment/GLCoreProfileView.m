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

@interface GLCoreProfileView()

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) BOOL paused;

@property (atomic, assign) GLuint programGSLayers;
@property (atomic, assign) GLuint programShowLayers;

@property (atomic, assign) GLuint transformUBO;
@property (atomic, assign) GLuint layeredFBO;
@property (atomic, assign) GLuint colorArrayTexture;
@property (atomic, assign) GLuint depthArrayTexture;

@property (atomic, assign) GLint colorArrayTextureLocation;

@end

@implementation GLCoreProfileView
#pragma mark - lifecycle methods
- (instancetype)initWithCoder:(NSCoder *)decoder {
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
    NSOpenGLContext *openGLContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    
    if (self = [super initWithCoder:decoder]) {
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
    
    // 加载模型
    [[TDModelManger shareManager] loadObjectWithFileName:@"torus.sbm"];
    
    // 开启面剔除特性
    glEnable(GL_CULL_FACE);
    
    // 准备一致闭包变量缓存
    glGenBuffers(1, &_transformUBO);
    glBindBuffer(GL_UNIFORM_BUFFER, _transformUBO);
    glBufferData(GL_UNIFORM_BUFFER, sizeof(GLKMatrix4) * 17, NULL, GL_DYNAMIC_DRAW);
    
    // 准备FBO
    glGenFramebuffers(1, &_layeredFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, _layeredFBO);
   
    glGenTextures(1, &_colorArrayTexture);
    glBindTexture(GL_TEXTURE_2D_ARRAY, _colorArrayTexture);
    size_t pixelDataSize = 512 * 512 * 4 * sizeof(GLubyte) * 16;
    void *pixelData = (void *)malloc(pixelDataSize);
    memset(pixelData, 0xFF, pixelDataSize);
    glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, 512, 512, 16, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixelData);
    free(pixelData);
    glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, self.colorArrayTexture, 0);
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    size_t depthDataSize = 512 * 512 * 4 * sizeof(GLubyte) * 16;
    void *depthData = (void *)malloc(depthDataSize);
    memset(depthData, 0x00, depthDataSize);
    glGenTextures(1, &_depthArrayTexture);
    glBindTexture(GL_TEXTURE_2D_ARRAY, self.depthArrayTexture);
    glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_DEPTH_COMPONENT32F, 512, 512, 16, 0, GL_DEPTH_COMPONENT, GL_UNSIGNED_BYTE, depthData);
    free(depthData);
    glFramebufferTexture(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, self.depthArrayTexture, 0);

    // 检查FBO完整性
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status == GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"ee");
    }
    
    // 设置绘制附件索引
    static const GLenum drawBuffers[] = {GL_COLOR_ATTACHMENT0};
    glDrawBuffers(1, drawBuffers);
}

- (void)reshape {
    [super reshape];
}

- (void)drawRect:(NSRect)dirtyRect {
    static double last_time = 0.0;
    static double total_time = 0.0;
    if (!_paused) {
        total_time += (_lifeDuration - last_time);
    }
    last_time = _lifeDuration;
    CGFloat progressTime = _lifeDuration * 0.5;
    
    // 为一致闭包变量赋值
    typedef struct TRANSFORM_BUFFER_S {
        GLKMatrix4 proj_matrix;
        GLKMatrix4 mv_matrix[16];
    } TRANSFORM_BUFFER;
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, self.transformUBO);
    TRANSFORM_BUFFER *buffer = (TRANSFORM_BUFFER *)glMapBufferRange(GL_UNIFORM_BUFFER, 0, sizeof(TRANSFORM_BUFFER), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    buffer->proj_matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0f), 1.0f, 0.1f, 1000.0f);
    for (int i = 0; i < 16; i++) {
        float fi = (float)(i + 12) / 16.0f;
        GLKMatrix4 mv_Matrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -4.0f);
        mv_Matrix = GLKMatrix4Rotate(mv_Matrix, GLKMathDegreesToRadians(progressTime * 25.0f * fi), 0.0f, 0.0f, 1.0f);
        mv_Matrix = GLKMatrix4Rotate(mv_Matrix, GLKMathDegreesToRadians(progressTime * 30.0f * fi), 1.0f, 0.0f, 0.0f);
        buffer->mv_matrix[i] = mv_Matrix;
    }
    glUnmapBuffer(GL_UNIFORM_BUFFER);
    
    // 绘制纹理
    glBindFramebuffer(GL_FRAMEBUFFER, self.layeredFBO);
    glViewport(0, 0, 512, 512);
    static const GLfloat black[] = { 0.0f, 0.0f, 0.0f, 1.0f };
    glClearBufferfv(GL_COLOR, 0, black);
    static const GLfloat one = 1.0f;
    glClearBufferfv(GL_DEPTH, 0, &one);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    
    glUseProgram(self.programGSLayers);
    [[TDModelManger shareManager] render];
    
    // 将纹理绘制到屏幕上
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDrawBuffer(GL_BACK);
    static const GLfloat gray[] =  { 0.1f, 0.1f, 0.1f, 1.0f };
    glClearBufferfv(GL_COLOR, 0, gray);
    glClearBufferfv(GL_DEPTH, 0, &one);
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));

    glUseProgram(self.programShowLayers);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D_ARRAY, self.colorArrayTexture);
    glUniform1i(self.colorArrayTextureLocation, 0);
    glDisable(GL_DEPTH_TEST);
    glBindVertexArray([TDModelManger shareManager].vao);
    glDrawArraysInstanced(GL_TRIANGLE_FAN, 0, 4, 16);
    
    glBindTexture(GL_TEXTURE_2D_ARRAY, 0);
    glFlush();
}

#pragma mark - private methods
- (BOOL)loadShaders {
    // programGSLayers
    GLuint gslayersShaders[3];
    GLushort gslayerShaderTypes[3] = {GL_VERTEX_SHADER, GL_GEOMETRY_SHADER, GL_FRAGMENT_SHADER};
    NSString *gslayersVSShaderPath = [[NSBundle mainBundle] pathForResource:@"gslayersVS" ofType:@"glsl"];
    NSString *gslayersGSShaderPath = [[NSBundle mainBundle] pathForResource:@"gslayersGS" ofType:@"glsl"];
    NSString *gslayersFSShaderPath = [[NSBundle mainBundle] pathForResource:@"gslayersFS" ofType:@"glsl"];
    NSArray *gslayerShaderPathes = @[gslayersVSShaderPath, gslayersGSShaderPath, gslayersFSShaderPath];
    
    for (int i = 0; i < 3; i++) {
        if (![self compileShader:&gslayersShaders[i] type:gslayerShaderTypes[i] filePath:gslayerShaderPathes[i]]) {
            NSLog(@"Failed to compile shader at %@", gslayerShaderPathes[i]);
        }
    }
    
    self.programGSLayers = glCreateProgram();
    for (int i = 0; i < 3; i++) {
        glAttachShader(self.programGSLayers, gslayersShaders[i]);
        glDeleteShader(gslayersShaders[i]);
        gslayersShaders[i] = 0;
    }
    
    if (![self linkProgram:self.programGSLayers]) {
        NSLog(@"Failed to link programGSLayers");
        if (self.programGSLayers != 0) {
            glDeleteProgram(self.programGSLayers);
            self.programGSLayers = 0;
        }
        return NO;
    }
    
    // programShowLayers
    GLuint showlayersShaders[2];
    GLushort showlayersShaderTypes[2] = {GL_VERTEX_SHADER, GL_FRAGMENT_SHADER};
    NSString *showlayersVSShaderPath = [[NSBundle mainBundle] pathForResource:@"showlayersVS" ofType:@"glsl"];
    NSString *showlayersFSShaderPath = [[NSBundle mainBundle] pathForResource:@"showlayersFS" ofType:@"glsl"];
    NSArray *showlayersShaderPathes = @[showlayersVSShaderPath, showlayersFSShaderPath];
    
    for (int i = 0; i < 2; i++) {
        if (![self compileShader:&showlayersShaders[i] type:showlayersShaderTypes[i] filePath:showlayersShaderPathes[i]]) {
            NSLog(@"Failed to compile shader at %@", showlayersShaderPathes[i]);
        }
    }
    
    self.programShowLayers = glCreateProgram();
    for (int i = 0; i < 3; i++) {
        glAttachShader(self.programShowLayers, showlayersShaders[i]);
        glDeleteShader(showlayersShaders[i]);
        showlayersShaders[i] = 0;
    }
    
    if (![self linkProgram:self.programShowLayers]) {
        NSLog(@"Failed to link programGSLayers");
        if (self.programShowLayers != 0) {
            glDeleteProgram(self.programShowLayers);
            self.programShowLayers = 0;
        }
        return NO;
    }

    self.colorArrayTextureLocation = glGetUniformLocation(self.programShowLayers, "tex");
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



