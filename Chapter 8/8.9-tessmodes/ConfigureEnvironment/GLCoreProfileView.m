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

@interface GLCoreProfileView() {
@private
    GLuint programs[4];
}

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) BOOL paused;

@property (atomic, assign) GLuint vertexArray;

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
    }
    return self;
}

- (void)dealloc {
    [_lifeTimer invalidate];
    _lifeTimer = nil;
    
    for (int i = 0; i < 4 ; i++) {
        glDeleteProgram(programs[i]);
    }
    glDeleteVertexArrays(1, &_vertexArray);
}

- (void)prepareOpenGL {
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [self loadShaders];
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    glPatchParameteri(GL_PATCH_VERTICES, 4);
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    static const GLfloat black[] = {0.0f, 0.0f, 0.0f, 1.0f};
    glClearBufferfv(GL_COLOR, 0, black);
    glUseProgram(programs[2]);
    glDrawArrays(GL_PATCHES, 0, 4);

    glFlush();
}

#pragma mark - public methods

#pragma mark - private methods
- (BOOL)loadShaders {
    NSString *verShaderPathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];;
    
    NSArray *tShaderNames = @[@"ShaderQuad", @"ShaderTri", @"ShaderLine"];
    NSMutableArray *tcShaderPathesTemp = [[NSMutableArray alloc] initWithCapacity:5];
    NSMutableArray *teShaderPathesTemp = [[NSMutableArray alloc] initWithCapacity:5];
    for (NSString *tcShaderName in tShaderNames) {
        NSString *tcShaderPath = [[NSBundle mainBundle] pathForResource:tcShaderName ofType:@"tcsh"];
        NSString *teShaderPath = [[NSBundle mainBundle] pathForResource:tcShaderName ofType:@"tesh"];
        [tcShaderPathesTemp addObject:tcShaderPath];
        [teShaderPathesTemp addObject:teShaderPath];
    }
    NSArray *tcShaderPathes = tcShaderPathesTemp.copy;
    NSArray *teShaderPathes = teShaderPathesTemp.copy;
    
    NSString *fragShaderPathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];;
    
    GLuint vertexShader = 0, tcShader = 0, teShader = 0, fragShader = 0;

    for (int i = 0; i < tShaderNames.count; i++) {
        programs[i] = glCreateProgram();
        if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER filePath:verShaderPathName]) {
            NSLog(@"Failed to compile vertex shader");
        }
        
        if (![self compileShader:&tcShader type:GL_TESS_CONTROL_SHADER filePath:tcShaderPathes[i]]) {
            NSLog(@"Failed to compile vertex shader");
        }
        
        if (![self compileShader:&teShader type:GL_TESS_EVALUATION_SHADER filePath:teShaderPathes[i]]) {
            NSLog(@"Failed to compile vertex shader");
        }
        
        if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER filePath:fragShaderPathName]) {
            NSLog(@"Failed to compile vertex shader");
        }
        
        glAttachShader(programs[i], vertexShader);
        glAttachShader(programs[i], tcShader);
        glAttachShader(programs[i], teShader);
        glAttachShader(programs[i], fragShader);
        
        if (![self linkProgram:programs[i]]) {
            NSLog(@"Failed to link program: %d", programs[i]);
            if (programs[i] != 0) {
                glDeleteProgram(programs[i]);
                programs[i] = 0;
            }
            return NO;
        }
    }
    
    if (vertexShader != 0) {
        glDeleteShader(vertexShader);
        vertexShader = 0;
    }
    if (tcShader != 0) {
        glDeleteShader(tcShader);
        vertexShader = 0;
    }
    if (teShader != 0) {
        glDeleteShader(teShader);
        vertexShader = 0;
    }
    if (fragShader != 0) {
        glDeleteShader(fragShader);
        fragShader = 0;
    }
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



