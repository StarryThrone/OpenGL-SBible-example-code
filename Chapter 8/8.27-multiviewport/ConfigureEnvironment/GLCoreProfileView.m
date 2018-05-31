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

@property (atomic, assign) GLuint program;
@property (atomic, assign) GLuint vertexArray;
@property (atomic, assign) GLuint position_buffer;
@property (atomic, assign) GLuint index_buffer;
@property (atomic, assign) GLuint uniform_buffer;

@property (atomic, assign) GLint transformBlockIndex;
@property (atomic, assign) GLint transformBlockLocation;

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
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [self loadShaders];

    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    
    static const GLushort vertex_indices[] = {
        0, 1, 2,
        2, 1, 3,
        2, 3, 4,
        4, 3, 5,
        4, 5, 6,
        6, 5, 7,
        6, 7, 0,
        0, 7, 1,
        6, 0, 2,
        2, 4, 6,
        7, 5, 3,
        7, 3, 1
    };
    
    static const GLfloat vertex_positions[] = {
        -0.25f, -0.25f, -0.25f,
        -0.25f,  0.25f, -0.25f,
        0.25f, -0.25f, -0.25f,
        0.25f,  0.25f, -0.25f,
        0.25f, -0.25f,  0.25f,
        0.25f,  0.25f,  0.25f,
        -0.25f, -0.25f,  0.25f,
        -0.25f,  0.25f,  0.25f,
    };
    
    glGenBuffers(1, &_position_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, _position_buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_positions), vertex_positions, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(0);
    
    glGenBuffers(1, &_index_buffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _index_buffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(vertex_indices), vertex_indices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_uniform_buffer);
    glBindBuffer(GL_UNIFORM_BUFFER, _uniform_buffer);
    glBufferData(GL_UNIFORM_BUFFER, 4 * sizeof(GLKMatrix4), NULL, GL_DYNAMIC_DRAW);
    
    glEnable(GL_CULL_FACE);
    // glFrontFace(GL_CW);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
}

- (void)reshape {
//    NSRect bounds = [self bounds];
//    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
    [self updateViewPorts];
}

- (void)drawRect:(NSRect)dirtyRect {
    static const GLfloat black[] = { 0.0f, 0.0f, 0.0f, 1.0f };
    glClearBufferfv(GL_COLOR, 0, black);
    static const GLfloat one = 1.0f;
    glClearBufferfv(GL_DEPTH, 0, &one);
    
    [self updateViewPorts];
    
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, _uniform_buffer);
    NSRect bounds = [self bounds];
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0f), NSWidth(bounds)/NSHeight(bounds), 0.1f, 1000.0f);
    GLKMatrix4 *mv_matrix_array = (GLKMatrix4 *)glMapBufferRange(GL_UNIFORM_BUFFER, 0, 4 * sizeof(GLKMatrix4), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    float f = _lifeDuration * 0.3;
    
    for (int i = 0; i < 4; i++) {
        GLKMatrix4 rotateX = GLKMatrix4MakeRotation(GLKMathDegreesToRadians((float)f * 81.0f * (float)(i + 1)), 1.0f, 0.0f, 0.0f);
        GLKMatrix4 rotateY = GLKMatrix4MakeRotation(GLKMathDegreesToRadians((float)f * 45.0f * (float)(i + 1)), 0.0f, 1.0f, 0.0f);
        GLKMatrix4 translation = GLKMatrix4MakeTranslation(0.0f, 0.0f, -1.0f);
        GLKMatrix4 mvMatrix = GLKMatrix4Multiply(translation, GLKMatrix4Multiply(rotateY, rotateX));
        GLKMatrix4 mvpMatrix = GLKMatrix4Multiply(projectionMatrix, mvMatrix);
        mv_matrix_array[i] = GLKMatrix4MakeWithArray(mvpMatrix.m);
    }
    glUnmapBuffer(GL_UNIFORM_BUFFER);
    
    glUseProgram(_program);
    glDrawElements(GL_TRIANGLES, 36, GL_UNSIGNED_SHORT, 0);
    glFlush();
}

#pragma mark - public methods

#pragma mark - private methods
- (BOOL)loadShaders {
    GLuint vertex_lineShader, ge_lineShader, frag_lineShader;
    NSString *vs_linePath = [[NSBundle mainBundle] pathForResource:@"linesadjacencyVS" ofType:@"glsl"];
    NSString *ge_linePath = [[NSBundle mainBundle] pathForResource:@"linesadjacencyGS" ofType:@"glsl"];
    NSString *fs_linePath = [[NSBundle mainBundle] pathForResource:@"linesadjacencyFS" ofType:@"glsl"];
    
    if (![self compileShader:&vertex_lineShader type:GL_VERTEX_SHADER filePath:vs_linePath]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&ge_lineShader type:GL_GEOMETRY_SHADER filePath:ge_linePath]) {
        NSLog(@"Failed to compile GL_TESS_CONTROL_SHADER");
    }
    if (![self compileShader:&frag_lineShader type:GL_FRAGMENT_SHADER filePath:fs_linePath]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    _program = glCreateProgram();
    glAttachShader(_program, vertex_lineShader);
    glAttachShader(_program, ge_lineShader);
    glAttachShader(_program, frag_lineShader);
    
    GLuint shaders2[] = {vertex_lineShader, ge_lineShader, frag_lineShader};
    for (int i = 0; i < 3; i++) {
        GLuint deleteShader = shaders2[i];
        glDeleteShader(deleteShader);
        deleteShader = 0;
    }
    
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link _tessProgram");
        if (_program != 0) {
            glDeleteProgram(_program);
            _program = 0;
        }
        return NO;
    }
    _transformBlockLocation = glGetUniformLocation(_program, "transform_block");
    _transformBlockIndex = glGetUniformBlockIndex(_program, "transform_block");
    glUniformBlockBinding(_program, _transformBlockIndex, 0);
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

- (void)updateViewPorts {
    NSRect bounds = [self bounds];
    // Each rectangle will be 8/16 of the screen
    float viewport_width = (float)(8 * NSWidth(bounds)) / 16.0f;
    float viewport_height = (float)(8 * NSHeight(bounds)) / 16.0f;
    // Four rectangles - lower left first...
    glViewportIndexedf(0, 0, 0, viewport_width, viewport_height);
    // Lower right...
    glViewportIndexedf(1, NSWidth(bounds) - viewport_width, 0, viewport_width, viewport_height);
    // Upper left...
    glViewportIndexedf(2, 0, NSHeight(bounds) - viewport_height, viewport_width, viewport_height);
    // Upper right...
    glViewportIndexedf(3, NSWidth(bounds) - viewport_width, NSHeight(bounds) - viewport_height, viewport_width, viewport_height);
}

#pragma mark - listening methods
- (void)lifeTimerUpdate {
    _lifeDuration += _lifeTimer.timeInterval;
    // _lifeDuration为程序运行时间
    [self drawRect:self.bounds];
}

#pragma mark - accessor methods

@end



