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

typedef struct UNIFORMS_S {
    GLint mvp_matrix;
    GLint mv_matrix;
    GLint proj_matrix;
    GLint damp_depth;
    GLint enable_fog;
    GLint colorTexLoc;
    GLint displamentTexLoc;
} UNIFORMS;

@interface GLCoreProfileView()

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) BOOL paused;

@property (atomic, assign) GLuint vertexArray;
@property (atomic, assign) GLuint program;

@property (atomic, assign) UNIFORMS uniforms;
@property (atomic, assign) GLuint displacementTex;
@property (atomic, assign) GLuint colorTex;

@property (atomic, assign) BOOL enableDisplacement;
@property (atomic, assign) BOOL enableFog;
@property (atomic, assign) BOOL wireFrame;
@property (atomic, assign) GLfloat dampDepth;

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
        
        _enableDisplacement = YES;
        _enableFog = YES;
        _wireFrame = NO;
        _dampDepth = 6.0f;
        
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
        self.enableFog = !self.enableFog;
    } else if ([event.characters isEqualToString:@"d"]) {
        self.enableDisplacement = !self.enableDisplacement;
    } else if ([event.characters isEqualToString:@"w"]) {
        self.wireFrame = !self.wireFrame;
    } else if ([event.characters isEqualToString:@"p"]) {
        self.paused = !self.paused;
    } else if ([event.characters isEqualToString:@"+"]) {
        self.dampDepth += 0.1f;
    } else if ([event.characters isEqualToString:@"-"]) {
        self.dampDepth -= 0.1f;
    }
    NSLog(@"%@",event.characters);
}

- (void)dealloc {
    [_lifeTimer invalidate];
    _lifeTimer = nil;
    
    glDeleteTextures(1, &_displacementTex);
    glDeleteTextures(1, &_colorTex);
    glDeleteVertexArrays(1, &_vertexArray);
    glDeleteProgram(_program);
}

- (void)prepareOpenGL {
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    [self loadShaders];

    glPatchParameteri(GL_PATCH_VERTICES, 4);
    glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    
    glActiveTexture(GL_TEXTURE0);
    [[TextureManager shareManager] loadObjectWithFileName:@"terragen1.ktx" toTextureID:&_displacementTex];
    glActiveTexture(GL_TEXTURE1);
    [[TextureManager shareManager] loadObjectWithFileName:@"terragen_color.ktx" toTextureID:&_colorTex];
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    static const GLfloat black[] = { 0.85f, 0.95f, 1.0f, 1.0f };
    static const GLfloat one = 1.0f;
    static double last_time = 0.0f;
    static double total_time = 0.0f;
    
    if (!_paused) {
        total_time += (_lifeDuration - last_time);
    }
    last_time = _lifeDuration;
    
    float t = total_time * 0.03f;
    float r = sinf(t * 5.37f) * 15.0f + 16.0f;
    float h = cosf(t * 4.79f) * 2.0f + 3.2;
    
    glClearBufferfv(GL_COLOR, 0, black);
    glClearBufferfv(GL_DEPTH, 0, &one);
    
    GLKMatrix4 mv_matrix = GLKMatrix4MakeLookAt(sinf(t) * r, h, cosf(t) * r,
                                                0.0f, 0.0f, 0.0f,
                                                0.0f, 1.0f, 0.0f);
    NSRect bounds = [self bounds];
    GLKMatrix4 proj_matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(60.0f), NSWidth(bounds)/NSHeight(bounds), 0.1f, 1000.0f);
    
    glUseProgram(_program);
    glUniformMatrix4fv(_uniforms.mv_matrix, 1, GL_FALSE, mv_matrix.m);
    glUniformMatrix4fv(_uniforms.proj_matrix, 1, GL_FALSE, proj_matrix.m);
    glUniformMatrix4fv(_uniforms.mvp_matrix, 1, GL_FALSE, GLKMatrix4Multiply(proj_matrix, mv_matrix).m);
    glUniform1f(_uniforms.damp_depth, _enableDisplacement ? _dampDepth : 0.0f);
    glUniform1i(_uniforms.enable_fog, _enableFog ? 1 : 0);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _displacementTex);
    glUniform1i(_uniforms.displamentTexLoc, 0);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _colorTex);
    glUniform1i(_uniforms.colorTexLoc, 1);
    
    if (_wireFrame) {
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    } else {
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    }
    glDrawArraysInstanced(GL_PATCHES, 0, 4, 64*64);
    glFlush();
}

#pragma mark - public methods

#pragma mark - private methods
- (BOOL)loadShaders {
    GLuint vertexShader, tcShader, teShader, fragShader;
    NSString *vsPath = [[NSBundle mainBundle] pathForResource:@"dispmapVS" ofType:@"glsl"];
    NSString *tcsPath = [[NSBundle mainBundle] pathForResource:@"dispmapTCS" ofType:@"glsl"];
    NSString *tesPath = [[NSBundle mainBundle] pathForResource:@"dispmapTES" ofType:@"glsl"];
    NSString *fsPath = [[NSBundle mainBundle] pathForResource:@"dispmapFS" ofType:@"glsl"];
    
    if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER filePath:vsPath]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&tcShader type:GL_TESS_CONTROL_SHADER filePath:tcsPath]) {
        NSLog(@"Failed to compile GL_TESS_CONTROL_SHADER");
    }
    if (![self compileShader:&teShader type:GL_TESS_EVALUATION_SHADER filePath:tesPath]) {
        NSLog(@"Failed to compile GL_TESS_EVALUATION_SHADER");
    }
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER filePath:fsPath]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    _program = glCreateProgram();
    glAttachShader(_program, vertexShader);
    glAttachShader(_program, tcShader);
    glAttachShader(_program, teShader);
    glAttachShader(_program, fragShader);
    GLuint shaders[] = {vertexShader, tcShader, teShader, fragShader};
    for (int i = 0; i < 4; i++) {
        GLuint deleteShader = shaders[i];
        glDeleteShader(deleteShader);
        deleteShader = 0;
    }
    
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program");
        if (_program != 0) {
            glDeleteProgram(_program);
            _program = 0;
        }
        return NO;
    }
    _uniforms.mvp_matrix = glGetUniformLocation(_program, "mvp_matrix");
    _uniforms.mv_matrix = glGetUniformLocation(_program, "mv_matrix");
    _uniforms.proj_matrix = glGetUniformLocation(_program, "proj_matrix");
    _uniforms.damp_depth = glGetUniformLocation(_program, "dmap_depth");
    _uniforms.enable_fog = glGetUniformLocation(_program, "enable_fog");
    _uniforms.colorTexLoc = glGetUniformLocation(_program, "tex_color");
    _uniforms.displamentTexLoc = glGetUniformLocation(_program, "tex_displacement");
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



