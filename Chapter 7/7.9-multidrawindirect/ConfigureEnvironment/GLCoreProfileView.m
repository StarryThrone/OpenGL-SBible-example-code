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

#define NUM_DRAWS 10000

typedef struct UNIFORMLOC {
    GLint time;
    GLint view_matrix;
    GLint proj_matrix;
    GLint viewproj_matrix;
} UniformLoc;

@interface GLCoreProfileView() {

@private
    UniformLoc uniformLocs;
}

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;

@property (nonatomic, assign) GLuint program;
@property (nonatomic, assign) GLuint vertexArray;
@property (nonatomic, assign) GLuint vertexArrayBuffer;

@property (nonatomic, assign) GLuint drawIndexBuffer;
@property (nonatomic, assign) BOOL paused;

@property (nonatomic, assign) GLint drawIndexLoc;


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
    [[TDModelManger shareManager] loadObjectWithFileName:@"asteroids.sbm"];
    
    glGenBuffers(1, &_drawIndexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _drawIndexBuffer);
    NSInteger objectCount = [TDModelManger shareManager].num_sub_objects;
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLuint)*objectCount, NULL, GL_STATIC_DRAW);
    GLuint *draw_index = glMapBufferRange(GL_ARRAY_BUFFER, 0, sizeof(GLuint)*objectCount, GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_RANGE_BIT);
    for (int i = 0; i < objectCount; i++) {
        draw_index[i] = i;
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    
    glEnableVertexAttribArray(10);
    glVertexAttribIPointer(10, 1, GL_UNSIGNED_INT, 0, NULL);
    glVertexAttribDivisor(10, 1);
    
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glEnable(GL_CULL_FACE);
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    static const float one = 1.0f;
    static const float black[] = {0.0f, 0.0f, 0.0f, 0.0f};
    glClearBufferfv(GL_DEPTH, 0, &one);
    glClearBufferfv(GL_COLOR, 0, black);

    static double last_time = 0.0;
    static double total_time = 0.0;
    if (!_paused) {
        total_time += (_lifeDuration - last_time);
    }
    last_time = _lifeDuration;
    float t = total_time;

    GLKVector3 upVector = GLKVector3Normalize(GLKVector3Make(0.1f - cosf(t * 0.1f) * 0.3f, 1.0f, 0.0f));
    const GLKMatrix4 view_matrix =
    GLKMatrix4MakeLookAt(100.0f * cosf(t * 0.023f), 100.0f * cosf(t * 0.023f), 300.0f * sinf(t * 0.037f) - 600.0f,
                         0.0f, 0.0f, 260.f,
                         upVector.x, upVector.y, upVector.z);
    NSRect bounds = [self bounds];
    GLKMatrix4 proj_matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50), NSWidth(bounds)/NSHeight(bounds), 1.0f, 2000.0f);
    GLKMatrix4 viewproj_matrix = GLKMatrix4Multiply(proj_matrix, view_matrix);
    
    glUseProgram(_program);
    glUniform1f(uniformLocs.time, t);
    glUniformMatrix4fv(uniformLocs.view_matrix, 1, GL_FALSE, view_matrix.m);
    glUniformMatrix4fv(uniformLocs.proj_matrix, 1, GL_FALSE, proj_matrix.m);
    glUniformMatrix4fv(uniformLocs.viewproj_matrix, 1, GL_FALSE, viewproj_matrix.m);
    
    for (int i = 0; i < NUM_DRAWS; i++) {
        GLuint first, count;
        NSUInteger objectIndex = i % [TDModelManger shareManager].num_sub_objects;
        [[TDModelManger shareManager] getSubObjectInfoWithIndex:objectIndex first:&first count:&count];
        glUniform1ui(_drawIndexLoc, i);
        glDrawArraysInstanced(GL_TRIANGLES, first, count, 1);
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

    glBindAttribLocation(_program, GLKVertexAttribPosition, "vVertex");
    
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
    
    uniformLocs.time = glGetUniformLocation(_program, "time");
    uniformLocs.view_matrix = glGetUniformLocation(_program, "view_matrix");
    uniformLocs.proj_matrix = glGetUniformLocation(_program, "proj_matrix");
    uniformLocs.viewproj_matrix = glGetUniformLocation(_program, "viewproj_matrix");
    _drawIndexLoc = glGetUniformLocation(_program, "draw_realId");
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



