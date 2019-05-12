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
    GLCoreProfileViewRenderModeNaive,
    GLCoreProfileViewRenderModeExposure,
    GLCoreProfileViewRenderModeAdaptive
};

@interface GLCoreProfileView()

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) GLCoreProfileViewRenderMode renderMode;

@property (atomic, assign) GLuint vertexArrayObject;
@property (atomic, assign) GLuint naiveProgram;
@property (atomic, assign) GLuint exposureProgram;
@property (atomic, assign) GLuint adaptiveProgram;
@property (atomic, assign) GLuint sourceTexture;
@property (atomic, assign) GLuint lutTexture;

@property (atomic, assign) GLint naiveTextureLocation;
@property (atomic, assign) GLint exposureTextureLocation;
@property (atomic, assign) GLint adaptiveTextureLocation;
@property (atomic, assign) GLint exposureExposureLocation;

@end

@implementation GLCoreProfileView
#pragma mark - lifecycle methods
- (instancetype)initWithCoder:(NSCoder *)decoder {
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
        // 开启8重采样
        NSOpenGLPFAMultisample,
        NSOpenGLPFASampleBuffers, (NSOpenGLPixelFormatAttribute)1,
        NSOpenGLPFASamples, (NSOpenGLPixelFormatAttribute)8,
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
    
    glGenVertexArrays(1, &_vertexArrayObject);
    glBindVertexArray(self.vertexArrayObject);
    
    [[TextureManager shareManager] loadObjectWithFileName:@"treelights_2k.ktx" toTextureID:&_sourceTexture];
    
    static const GLfloat exposureLUT[20] = { 11.0f, 6.0f, 3.2f, 2.8f, 2.2f, 1.90f, 1.80f, 1.80f, 1.70f, 1.70f,  1.60f, 1.60f, 1.50f, 1.50f, 1.40f, 1.40f, 1.30f, 1.20f, 1.10f, 1.00f };
    glGenTextures(1, &_lutTexture);
    glBindTexture(GL_TEXTURE_1D, self.lutTexture);
    glTexImage1D(GL_TEXTURE_1D, 0, GL_R32F, 20, 0, GL_RED, GL_FLOAT, exposureLUT);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
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
    
    static const GLfloat black[] = { 0.0f, 0.25, 0.0f, 1.0f };
    glClearBufferfv(GL_COLOR, 0, black);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_1D, _lutTexture);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _sourceTexture);
    
    self.renderMode = GLCoreProfileViewRenderModeAdaptive;
    switch (self.renderMode) {
        case GLCoreProfileViewRenderModeNaive:
            glUseProgram(self.naiveProgram);
            glUniform1i(self.naiveTextureLocation, 0);
            break;
        case GLCoreProfileViewRenderModeExposure:
            glUseProgram(self.exposureProgram);
            glUniform1i(self.exposureTextureLocation, 0);
            CGFloat exposure = sin(total_time) * 10.0 + 10;
            NSLog(@"%.2f", exposure);
            glUniform1f(self.exposureExposureLocation, exposure);
            break;
        case GLCoreProfileViewRenderModeAdaptive:
            glUseProgram(self.adaptiveProgram);
            glUniform1i(self.adaptiveTextureLocation, 0);
            break;
    }
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glFlush();
}

#pragma mark - private methods
- (BOOL)loadShaders {
    // Create naive program
    GLuint vertex_Shader, frag_Shader;
    NSString *vs_Path = [[NSBundle mainBundle] pathForResource:@"toneMapVS" ofType:@"glsl"];
    NSString *fs_Path = [[NSBundle mainBundle] pathForResource:@"toneMapNaiveFS" ofType:@"glsl"];
    
    if (![self compileShader:&vertex_Shader type:GL_VERTEX_SHADER filePath:vs_Path]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&frag_Shader type:GL_FRAGMENT_SHADER filePath:fs_Path]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    self.naiveProgram = glCreateProgram();
    glAttachShader(self.naiveProgram, vertex_Shader);
    glAttachShader(self.naiveProgram, frag_Shader);
    glDeleteShader(frag_Shader);
    frag_Shader = 0;
    
    if (![self linkProgram:self.naiveProgram]) {
        NSLog(@"Failed to link naiveProgram");
        if (self.naiveProgram != 0) {
            glDeleteProgram(self.naiveProgram);
            self.naiveProgram = 0;
        }
        return NO;
    }
    
    self.naiveTextureLocation = glGetUniformLocation(self.naiveProgram, "s");
    
    // Create Exposure Program
    fs_Path = [[NSBundle mainBundle] pathForResource:@"toneMapExposureFS" ofType:@"glsl"];
    if (![self compileShader:&frag_Shader type:GL_FRAGMENT_SHADER filePath:fs_Path]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    self.exposureProgram = glCreateProgram();
    glAttachShader(self.exposureProgram, vertex_Shader);
    glAttachShader(self.exposureProgram, frag_Shader);
    glDeleteShader(frag_Shader);
    frag_Shader = 0;
    
    if (![self linkProgram:self.exposureProgram]) {
        NSLog(@"Failed to link exposureProgram");
        if (self.exposureProgram != 0) {
            glDeleteProgram(self.exposureProgram);
            self.exposureProgram = 0;
        }
        return NO;
    }
    
    self.exposureTextureLocation = glGetUniformLocation(self.exposureProgram, "hdr_image");
    self.exposureExposureLocation = glGetUniformLocation(self.exposureProgram, "exposure");
    
    // Create Adaptive Program
    fs_Path = [[NSBundle mainBundle] pathForResource:@"toneMapAdaptiveFS" ofType:@"glsl"];
    if (![self compileShader:&frag_Shader type:GL_FRAGMENT_SHADER filePath:fs_Path]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    self.adaptiveProgram = glCreateProgram();
    glAttachShader(self.adaptiveProgram, vertex_Shader);
    glAttachShader(self.adaptiveProgram, frag_Shader);
    glDeleteShader(vertex_Shader);
    vertex_Shader = 0;
    glDeleteShader(frag_Shader);
    frag_Shader = 0;
    
    if (![self linkProgram:self.adaptiveProgram]) {
        NSLog(@"Failed to link exposureProgram");
        if (self.adaptiveProgram != 0) {
            glDeleteProgram(self.adaptiveProgram);
            self.adaptiveProgram = 0;
        }
        return NO;
    }
    
    self.adaptiveTextureLocation = glGetUniformLocation(self.adaptiveProgram, "hdr_image");
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



