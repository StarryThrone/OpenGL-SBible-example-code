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
    GLint mvMatrixLoc;
    GLint projMatrixLoc;
    
    GLint cpDrawColorLoc;
    GLint cpMvpMatrixLoc;
} UNIFORMS;

@interface GLCoreProfileView() {
@private
    GLKVector3 patchData[16];
}

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) BOOL paused;

@property (atomic, assign) GLuint vertexArray;
@property (atomic, assign) GLuint tessProgram;
@property (atomic, assign) GLuint deawCpProgram;

@property (atomic, assign) UNIFORMS uniforms;

@property (atomic, assign) BOOL showPoints;
@property (atomic, assign) BOOL showCage;
@property (atomic, assign) BOOL enableWireFrame;

@property (atomic, assign) GLuint patchBuffer;
@property (atomic, assign) GLuint cageIndicesBuffer;

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
        
        _showPoints = YES;
        _showCage = YES;
        _enableWireFrame = YES;
        
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
        self.enableWireFrame = !self.enableWireFrame;
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

    glDeleteBuffers(1, &_patchBuffer);
    glDeleteBuffers(1, &_cageIndicesBuffer);
    glDeleteVertexArrays(1, &_vertexArray);
    glDeleteProgram(_tessProgram);
    glDeleteProgram(_deawCpProgram);
}

- (void)prepareOpenGL {
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    [self loadShaders];

    glGenBuffers(1, &_patchBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _patchBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(patchData), NULL, GL_DYNAMIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(0);
    
    static const GLushort indices[] = {
        0,  1,  1,  2,  2,  3,
        4,  5,  5,  6,  6,  7,
        8,  9,  9,  10, 10, 11,
        12, 13, 13, 14, 14, 15,
        
        0,  4,  4,  8,  8,  12,
        1,  5,  5,  9,  9,  13,
        2,  6,  6,  10, 10, 14,
        3,  7,  7,  11, 11, 15
    };
    glGenBuffers(1, &_cageIndicesBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _cageIndicesBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    
    glPatchParameteri(GL_PATCH_VERTICES, 16);
    glEnable(GL_DEPTH_TEST);
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    static const GLfloat gray[] = { 0.1f, 0.1f, 0.1f, 0.0f };
    static const GLfloat one = 1.0f;
    glClearBufferfv(GL_COLOR, 0, gray);
    glClearBufferfv(GL_DEPTH, 0, &one);
    
    static double last_time = 0.0f;
    static double total_time = 0.0f;
    if (!_paused) {
        total_time += (_lifeDuration - last_time);
    }
    last_time = _lifeDuration;
    float t = (float)total_time;
    
    static const float patch_initializer[] = {
        -1.0f,  -1.0f,  0.0f,
        -0.33f, -1.0f,  0.0f,
         0.33f, -1.0f,  0.0f,
         1.0f,  -1.0f,  0.0f,
        
        -1.0f,  -0.33f, 0.0f,
        -0.33f, -0.33f, 0.0f,
         0.33f, -0.33f, 0.0f,
         1.0f,  -0.33f, 0.0f,
        
        -1.0f,   0.33f, 0.0f,
        -0.33f,  0.33f, 0.0f,
         0.33f,  0.33f, 0.0f,
         1.0f,   0.33f, 0.0f,
        
        -1.0f,   1.0f,  0.0f,
        -0.33f,  1.0f,  0.0f,
         0.33f,  1.0f,  0.0f,
         1.0f,   1.0f,  0.0f,
    };
    
    GLKVector3 *p = (GLKVector3 *)glMapBufferRange(GL_ARRAY_BUFFER, 0, sizeof(patchData), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    memcpy(p, patch_initializer, sizeof(patch_initializer));
    for (int i = 0; i < 16; i++) {
        float fi = (float)i / 16.0f;
        p[i].z = sinf(t * (0.2f + fi * 0.3f));
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    
    glUseProgram(_tessProgram);
    NSRect bounds = [self bounds];
    GLKMatrix4 proj_matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0f), NSWidth(bounds)/NSHeight(bounds), 1.0f, 1000.0f);
    GLKMatrix4 rotateX = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(t * 17.0f), 1.0f, 0.0f, 0.0f);
    GLKMatrix4 rotateY = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(t * 10.0f), 0.0f, 1.0f, 0.0f);
    GLKMatrix4 translate = GLKMatrix4MakeTranslation(0.0f, 0.0f, -4.0f);
    GLKMatrix4 mv_matrix = GLKMatrix4Multiply(translate, GLKMatrix4Multiply(rotateY, rotateX));
    GLKMatrix4 mvp_matrix = GLKMatrix4Multiply(proj_matrix, mv_matrix);
    
    glUniformMatrix4fv(_uniforms.mvMatrixLoc, 1, GL_FALSE, mv_matrix.m);
    glUniformMatrix4fv(_uniforms.projMatrixLoc, 1, GL_FALSE, proj_matrix.m);
    
    if (_enableWireFrame) {
        glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    } else {
        glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    }
    glDrawArrays(GL_PATCHES, 0, 16);
    
    glUseProgram(_deawCpProgram);
    glUniformMatrix4fv(_uniforms.cpMvpMatrixLoc, 1, GL_FALSE, mvp_matrix.m);
    if (_showPoints) {
        glPointSize(9.0f);
        glUniform4fv(_uniforms.cpDrawColorLoc, 1, GLKVector4Make(0.2f, 0.7f, 0.9f, 1.0f).v);
        glDrawArrays(GL_POINTS, 0, 16);
    }
    
    if (_showCage) {
        glUniform4fv(_uniforms.cpDrawColorLoc, 1, GLKVector4Make(0.2f, 0.7f, 0.9f, 1.0f).v);
        glDrawElements(GL_LINES, 48, GL_UNSIGNED_SHORT, NULL);
    }
    
    glFlush();
}

#pragma mark - public methods

#pragma mark - private methods
- (BOOL)loadShaders {
    GLuint vertexShader, tcShader, teShader, fragShader;
    NSString *vsPath = [[NSBundle mainBundle] pathForResource:@"cubicbezierVS" ofType:@"glsl"];
    NSString *tcsPath = [[NSBundle mainBundle] pathForResource:@"cubicbezierTCS" ofType:@"glsl"];
    NSString *tesPath = [[NSBundle mainBundle] pathForResource:@"cubicbezierTES" ofType:@"glsl"];
    NSString *fsPath = [[NSBundle mainBundle] pathForResource:@"cubicbezierFS" ofType:@"glsl"];
    
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
    
    _tessProgram = glCreateProgram();
    glAttachShader(_tessProgram, vertexShader);
    glAttachShader(_tessProgram, tcShader);
    glAttachShader(_tessProgram, teShader);
    glAttachShader(_tessProgram, fragShader);
    GLuint tessShaders[] = {vertexShader, tcShader, teShader, fragShader};
    for (int i = 0; i < 4; i++) {
        GLuint deleteShader = tessShaders[i];
        glDeleteShader(deleteShader);
        deleteShader = 0;
    }
    
    if (![self linkProgram:_tessProgram]) {
        NSLog(@"Failed to link _tessProgram");
        if (_tessProgram != 0) {
            glDeleteProgram(_tessProgram);
            _tessProgram = 0;
        }
        return NO;
    }
    _uniforms.mvMatrixLoc = glGetUniformLocation(_tessProgram, "mv_matrix");
    _uniforms.projMatrixLoc = glGetUniformLocation(_tessProgram, "proj_matrix");
    
    vsPath = [[NSBundle mainBundle] pathForResource:@"drawControlPointsVs" ofType:@"glsl"];
    fsPath = [[NSBundle mainBundle] pathForResource:@"drawControlPointsFs" ofType:@"glsl"];
    if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER filePath:vsPath]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER drawControlPointsVs");
    }
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER filePath:fsPath]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER drawControlPointsFs");
    }
    _deawCpProgram = glCreateProgram();
    glAttachShader(_deawCpProgram, vertexShader);
    glAttachShader(_deawCpProgram, fragShader);
    GLuint deawCpShaders[] = {vertexShader, fragShader};
    for (int i = 0; i < 2; i++) {
        GLuint deleteShader = deawCpShaders[i];
        glDeleteShader(deleteShader);
        deleteShader = 0;
    }
    
    if (![self linkProgram:_deawCpProgram]) {
        NSLog(@"Failed to link _deawCpProgram");
        if (_deawCpProgram != 0) {
            glDeleteProgram(_deawCpProgram);
            _deawCpProgram = 0;
        }
        return NO;
    }
    _uniforms.cpMvpMatrixLoc = glGetUniformLocation(_deawCpProgram, "mvp_matrix");
    _uniforms.cpDrawColorLoc = glGetUniformLocation(_deawCpProgram, "draw_color");
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



