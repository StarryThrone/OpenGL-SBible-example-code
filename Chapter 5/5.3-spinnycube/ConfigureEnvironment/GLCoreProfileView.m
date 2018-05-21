//
//  GLCoreProfileView.m
//  ConfigureEnvironment
//
//  Created by 陈杰 on 26/10/2017.
//  Copyright © 2017 陈杰. All rights reserved.
//


#import "GLCoreProfileView.h"
//#import <OpenGL/gl3.h>
#import <OpenGL/OpenGL.h>
#import <GLKit/GLKit.h>

@interface GLCoreProfileView()
@property (atomic, strong) NSTimer *lifeTimer;
@property (atomic, assign) CGFloat lifeDuration;

@property (atomic, assign) GLuint program;
@property (atomic, assign) GLuint vertexArray;
@property (atomic, assign) GLuint vertexArrayBuffer;

@property (atomic, assign) GLint mv_location;
@property (atomic, assign) GLint proj_location;
@property (atomic, assign) GLKMatrix4 mv_Matrix;
@property (atomic, assign) GLKMatrix4 proj_Matrix;
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
        
        _lifeTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(lifeTimerUpdate) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)dealloc {
    [_lifeTimer invalidate];
    _lifeTimer = nil;
    
    glDeleteVertexArrays(1, &_vertexArray);
    glDeleteProgram(_program);
    glDeleteBuffers(1, &_vertexArrayBuffer);
}

- (void)prepareOpenGL {
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [self loadShaders];
    
    static const GLfloat vertex_positions[] = {
        -0.25f,  0.25f, -0.25f,      -0.25f, -0.25f, -0.25f,     0.25f, -0.25f, -0.25f,
        0.25f, -0.25f, -0.25f,       0.25f,  0.25f, -0.25f,      -0.25f,  0.25f, -0.25f,

        -0.25f, -0.25f, 0.25f,       0.25f, -0.25f, 0.25f,       0.25f, -0.25f, -0.25f,
        0.25f, -0.25f, -0.25f,       -0.25f, -0.25f, -0.25f,     -0.25f, -0.25f, 0.25f,

        0.25f, 0.25f, 0.25f,         0.25f, 0.25f, -0.25f,       0.25f, -0.25f, -0.25f,
        0.25f, -0.25f, -0.25f,       0.25f, -0.25, 0.25f,        0.25f, 0.25f, 0.25f,

        -0.25f, -0.25f, 0.25f,       -0.25f, 0.25f, 0.25f,       -0.25f, -0.25f, -0.25f,
        -0.25f, 0.25f, -0.25f,       -0.25f, -0.25f, -0.25f,     -0.25f, 0.25f, 0.25f,

        0.25f, 0.25f, 0.25f,         0.25f, -0.25f, 0.25f,       -0.25f, -0.25f, 0.25f,
        -0.25f, -0.25f, 0.25f,       -0.25f, 0.25f, 0.25f,       0.25f, 0.25f, 0.25f,

        -0.25f,  0.25f, -0.25f,       0.25f,  0.25f, -0.25f,      0.25f,  0.25f,  0.25f,
        0.25f,  0.25f,  0.25f,        -0.25f,  0.25f,  0.25f,     -0.25f,  0.25f, -0.25f
    };
    
    // Now generate some data and put it in a buffer object
    glGenBuffers(1, &_vertexArrayBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexArrayBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_positions), vertex_positions, GL_STATIC_DRAW);
    
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    
    // Set up our vertex attribute
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    
    glEnable(GL_DEPTH_TEST);
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
    GLfloat aspect = NSWidth(bounds)/NSHeight(bounds);
    _proj_Matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0), aspect, 0.1f, 1000.0f);
}

- (void)drawRect:(NSRect)dirtyRect {
    static const GLfloat green[] = { 0.0f, 0.15f,
        0.0f, 1.0f };
    static const GLfloat depth = 1.0f;
    glClearBufferfv(GL_COLOR, 0, green);
    glClearBufferfv(GL_DEPTH, 0, &depth);
    
    glUseProgram(_program);
    glUniformMatrix4fv(_proj_location, 1, GL_FALSE, _proj_Matrix.m);
    for (int i = 0; i < 24; i++) {
        GLfloat f = _lifeDuration*0.3f + i;
        GLKMatrix4 xRotateMatrix = GLKMatrix4MakeRotation(_lifeDuration*GLKMathDegreesToRadians(21.0f), 1.0f, 0.0f, 0.0f);
        GLKMatrix4 yRotateMatrix = GLKMatrix4MakeRotation(_lifeDuration*M_PI_4, 0.0f, 1.0f, 0.0f);
        GLKMatrix4 translateMatrix = GLKMatrix4MakeTranslation(sinf(2.1f*f)*2.0f, cosf(1.7f*f)*2.0f, sinf(1.3f*f)*cosf(1.5f*f)*2.0f);
        GLKMatrix4 modelWroldMatrix = GLKMatrix4Multiply(GLKMatrix4Multiply(translateMatrix, yRotateMatrix), xRotateMatrix);
        GLKMatrix4 viewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -7.0f);
        _mv_Matrix = GLKMatrix4Multiply(viewMatrix, modelWroldMatrix);
        glUniformMatrix4fv(_mv_location, 1, GL_FALSE, _mv_Matrix.m);
        glDrawArrays(GL_TRIANGLES, 0, 36);
    }
    glFlush();
}

#pragma mark - public methods

#pragma mark - private methods
- (BOOL)loadShaders {
    GLuint vertexShader;
    GLuint fragShader;
    NSString *vertexShaderPathName;
    NSString *fragShaderPathName;
    
    _program = glCreateProgram();
    
    vertexShaderPathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER filePath:vertexShaderPathName]) {
        NSLog(@"Failed to compile vertex shader");
    }
    
    fragShaderPathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER filePath:fragShaderPathName]) {
        NSLog(@"Failed to compile fragment shader");
    }
    
    glAttachShader(_program, vertexShader);
    glAttachShader(_program, fragShader);

    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
    
    if (vertexShader != 0) {
        glDeleteShader(vertexShader);
        vertexShader = 0;
    }
    if (fragShader != 0) {
        glDeleteShader(fragShader);
        fragShader = 0;
    }
    
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        if (_program != 0) {
            glDeleteProgram(_program);
            _program = 0;
        }
        return NO;
    }

    _mv_location = glGetUniformLocation(_program, "mv_matrix");
    _proj_location = glGetUniformLocation(_program, "proj_matrix");
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



