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

@property (atomic, assign) GLuint program1;
@property (atomic, assign) GLuint program2;
@property (atomic, assign) GLuint vao;
@property (atomic, assign) GLuint vertexAttributeBuffer;
@property (atomic, assign) GLuint indexBuffer;

@property (atomic, assign) GLuint frameBufferObject;
@property (atomic, assign) GLuint colorTexture;
@property (atomic, assign) GLuint depthTexture;

@property (atomic, assign) GLint mvMatrixLocation1;
@property (atomic, assign) GLint projMatrixLocation1;
@property (atomic, assign) GLint mvMatrixLocation2;
@property (atomic, assign) GLint projMatrixLocation2;
@property (atomic, assign) GLint textureLocation;

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
    
    glGenVertexArrays(1, &_vao);
    glBindVertexArray(self.vao);

    static const GLfloat vertex_data[] = {
        // Position                 Tex Coord
        -0.5f, -0.5f,  0.5f,      0.0f, 1.0f,
        -0.5f, -0.5f, -0.5f,      0.0f, 0.0f,
        0.5f, -0.5f, -0.5f,      1.0f, 0.0f,

        0.5f, -0.5f, -0.5f,      1.0f, 0.0f,
        0.5f, -0.5f,  0.5f,      1.0f, 1.0f,
        -0.5f, -0.5f,  0.5f,      0.0f, 1.0f,

        0.5f, -0.5f, -0.5f,      0.0f, 0.0f,
        0.5f,  0.5f, -0.5f,      1.0f, 0.0f,
        0.5f, -0.5f,  0.5f,      0.0f, 1.0f,

        0.5f,  0.5f, -0.5f,      1.0f, 0.0f,
        0.5f,  0.5f,  0.5f,      1.0f, 1.0f,
        0.5f, -0.5f,  0.5f,      0.0f, 1.0f,

        0.5f,  0.5f, -0.5f,      1.0f, 0.0f,
        -0.5f,  0.5f, -0.5f,      0.0f, 0.0f,
        0.5f,  0.5f,  0.5f,      1.0f, 1.0f,

        -0.5f,  0.5f, -0.5f,      0.0f, 0.0f,
        -0.5f,  0.5f,  0.5f,      0.0f, 1.0f,
        0.5f,  0.5f,  0.5f,      1.0f, 1.0f,

        -0.5f,  0.5f, -0.5f,      1.0f, 0.0f,
        -0.5f, -0.5f, -0.5f,      0.0f, 0.0f,
        -0.5f,  0.5f,  0.5f,      1.0f, 1.0f,

        -0.5f, -0.5f, -0.5f,      0.0f, 0.0f,
        -0.5f, -0.5f,  0.5f,      0.0f, 1.0f,
        -0.5f,  0.5f,  0.5f,      1.0f, 1.0f,

        -0.5f,  0.5f, -0.5f,      0.0f, 1.0f,
        0.5f,  0.5f, -0.5f,      1.0f, 1.0f,
        0.5f, -0.5f, -0.5f,      1.0f, 0.0f,

        0.5f, -0.5f, -0.5f,      1.0f, 0.0f,
        -0.5f, -0.5f, -0.5f,      0.0f, 0.0f,
        -0.5f,  0.5f, -0.5f,      0.0f, 1.0f,

        -0.5f, -0.5f,  0.5f,      0.0f, 0.0f,
        0.5f, -0.5f,  0.5f,      1.0f, 0.0f,
        0.5f,  0.5f,  0.5f,      1.0f, 1.0f,

        0.5f,  0.5f,  0.5f,      1.0f, 1.0f,
        -0.5f,  0.5f,  0.5f,      0.0f, 1.0f,
        -0.5f, -0.5f,  0.5f,      0.0f, 0.0f,
    };
    glGenBuffers(1, &_vertexAttributeBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexAttributeBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_data), vertex_data, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), NULL);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (GLvoid *)(3 * sizeof(GLfloat)));
    glEnableVertexAttribArray(1);

    static const GLushort vertex_indices[] = {
        0, 1, 2,    2, 1, 3,    2, 3, 4,    4, 3, 5,
        4, 5, 6,    6, 5, 7,    6, 7, 0,    0, 7, 1,
        6, 0, 2,    2, 4, 6,    7, 5, 3,    7, 3, 1
    };
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(vertex_indices), vertex_indices, GL_STATIC_DRAW);

    glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    
    glGenFramebuffers(1, &_frameBufferObject);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferObject);
   
    glGenTextures(1, &_colorTexture);
    glBindTexture(GL_TEXTURE_2D, _colorTexture);
    size_t pixelDataSize = 512 * 512 * 4 * sizeof(GLubyte);
    void *pixelData = (void *)malloc(pixelDataSize);
    memset(pixelData, 0xFF, pixelDataSize);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 512, 512, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixelData);
    free(pixelData);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, self.colorTexture, 0);
    
    size_t depthDataSize = 512 * 512 * 4 * sizeof(GLubyte);
    void *depthData = (void *)malloc(depthDataSize);
    memset(depthData, 0x00, depthDataSize);
    glGenTextures(1, &_depthTexture);
    glBindTexture(GL_TEXTURE_2D, self.depthTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32F, 512, 512, 0, GL_DEPTH_COMPONENT, GL_UNSIGNED_BYTE, depthData);
    free(depthData);
    glFramebufferTexture(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, self.depthTexture, 0);
        
    static const GLenum drawBuffers[] = {GL_COLOR_ATTACHMENT0};
    glDrawBuffers(1, drawBuffers);
}

- (void)reshape {
    [super reshape];
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect bounds = [self bounds];
    GLKMatrix4 projectMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0f), NSWidth(bounds) / NSHeight(bounds), 0.1f, 1000.0f);
    
    static double last_time = 0.0;
    static double total_time = 0.0;
    if (!_paused) {
        total_time += (_lifeDuration - last_time);
    }
    last_time = _lifeDuration;
    CGFloat progressTime = _lifeDuration * 0.5;
    GLKMatrix4 mvMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -3.0f);
    mvMatrix = GLKMatrix4Translate(mvMatrix,
                                   sinf(progressTime) * 0.5f,
                                   sinf(1.5f * progressTime) * 0.5f,
                                   sinf(1.5f * progressTime) * cosf(1.5f * progressTime) * 2.0f);
    mvMatrix = GLKMatrix4Rotate(mvMatrix, GLKMathDegreesToRadians(45.0f), 0.0f, 1.0f, 0.0f);
    mvMatrix = GLKMatrix4Rotate(mvMatrix, GLKMathDegreesToRadians(45.0f), 1.0f, 0.0f, 0.0f);
    
    // 绘制第一个立方体
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBufferObject);
    glViewport(0, 0, 512, 512);
    static const GLfloat green[] = { 0.0f, 0.1f, 0.0f, 1.0f};
    glClearBufferfv(GL_COLOR, 0, green);
    static const GLfloat one = 1.0f;
    glClearBufferfv(GL_DEPTH, 0, &one);
    
    glUseProgram(self.program1);
    glUniformMatrix4fv(self.projMatrixLocation1, 1, GL_FALSE, projectMatrix.m);
    glUniformMatrix4fv(self.mvMatrixLocation1, 1, GL_FALSE, mvMatrix.m);
    glDrawArrays(GL_TRIANGLES, 0, 36);

    // 绘制第二个立方体
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
    static const GLfloat blue[] = { 0.0f, 0.0f, 0.3f, 1.0f };
    glClearBufferfv(GL_COLOR, 0, blue);
    glClearBufferfv(GL_DEPTH, 0, &one);
    glUseProgram(self.program2);
    glUniformMatrix4fv(self.projMatrixLocation2, 1, GL_FALSE, projectMatrix.m);
    glUniformMatrix4fv(self.mvMatrixLocation2, 1, GL_FALSE, mvMatrix.m);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.colorTexture);
    glUniform1i(self.textureLocation, 0);
    glDrawArrays(GL_TRIANGLES, 0, 36);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    glFlush();
}

#pragma mark - private methods
- (BOOL)loadShaders {
    // Program1
    GLuint vertex_lineShader, frag_lineShader1;
    NSString *vs_linePath = [[NSBundle mainBundle] pathForResource:@"linesadjacencyVS" ofType:@"glsl"];
    NSString *fs_linePath1 = [[NSBundle mainBundle] pathForResource:@"linesadjacencyFS1" ofType:@"glsl"];
    
    if (![self compileShader:&vertex_lineShader type:GL_VERTEX_SHADER filePath:vs_linePath]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&frag_lineShader1 type:GL_FRAGMENT_SHADER filePath:fs_linePath1]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    self.program1 = glCreateProgram();
    glAttachShader(self.program1, vertex_lineShader);
    glAttachShader(self.program1, frag_lineShader1);
    
    GLuint shaders2[] = {vertex_lineShader, frag_lineShader1};
    for (int i = 0; i < 3; i++) {
        GLuint deleteShader = shaders2[i];
        glDeleteShader(deleteShader);
        deleteShader = 0;
    }
    
    if (![self linkProgram:self.program1]) {
        NSLog(@"Failed to link _tessProgram");
        if (self.program1 != 0) {
            glDeleteProgram(self.program1);
            self.program1 = 0;
        }
        return NO;
    }
    
    self.mvMatrixLocation1 = glGetUniformLocation(self.program1, "mv_matrix");
    self.projMatrixLocation1 = glGetUniformLocation(self.program1, "proj_matrix");
    
    // Program2
    GLuint frag_lineShader2;
    NSString *fs_linePath2 = [[NSBundle mainBundle] pathForResource:@"linesadjacencyFS2" ofType:@"glsl"];
    if (![self compileShader:&vertex_lineShader type:GL_VERTEX_SHADER filePath:vs_linePath]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&frag_lineShader2 type:GL_FRAGMENT_SHADER filePath:fs_linePath2]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    self.program2 = glCreateProgram();
    glAttachShader(self.program2, vertex_lineShader);
    glAttachShader(self.program2, frag_lineShader2);
    
    GLuint shaders2new[] = {vertex_lineShader, frag_lineShader2};
    for (int i = 0; i < 3; i++) {
        GLuint deleteShader = shaders2new[i];
        glDeleteShader(deleteShader);
        deleteShader = 0;
    }
    
    if (![self linkProgram:self.program2]) {
        NSLog(@"Failed to link _tessProgram");
        if (self.program2 != 0) {
            glDeleteProgram(self.program2);
            self.program2 = 0;
        }
        return NO;
    }
    
    self.mvMatrixLocation2 = glGetUniformLocation(self.program2, "mv_matrix");
    self.projMatrixLocation2 = glGetUniformLocation(self.program2, "proj_matrix");
    self.textureLocation = glGetUniformLocation(self.program2, "tex");
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



