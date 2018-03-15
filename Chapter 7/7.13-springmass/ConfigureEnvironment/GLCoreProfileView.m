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

union _GLKIVector4 {
    struct { int x, y, z, w; };
    struct { int r, g, b, a; };
    struct { int s, t, p, q; };
    int v[4];
} __attribute__((aligned(16)));
typedef union _GLKIVector4 GLKIVector4;

GLKIVector4 GLKIVector4Make(int x, int y, int z, int w) {
    GLKIVector4 v = { x, y, z, w };
    return v;
}

enum {
    POINTS_X            = 50,
    POINTS_Y            = 50,
    POINTS_TOTAL        = (POINTS_X * POINTS_Y),
    CONNECTIONS_TOTAL   = (POINTS_X - 1) * POINTS_Y + (POINTS_Y - 1) * POINTS_X,
};

typedef NS_ENUM(NSUInteger, BUFFER_TYPE_t) {
    POSITION_A,
    POSITION_B,
    VELOCITY_A,
    VELOCITY_B,
    CONNECTION
};

@interface GLCoreProfileView() {
@private
    GLuint vertexArray[2];
    GLuint vertexArrayBuffer[5];
    GLuint positionTbo[2];
}

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) NSInteger iterationPerFrame;
@property (nonatomic, assign) NSInteger iterationIndex;
@property (nonatomic, assign) BOOL drawPoints;
@property (nonatomic, assign) BOOL drawLines;

@property (nonatomic, assign) GLuint updateProgram;
@property (nonatomic, assign) GLuint renderProgram;

@property (nonatomic, assign) GLuint indexBuffer;

@property (nonatomic, assign) GLint textureVertextLoc;
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
        _iterationPerFrame = 16;
        _iterationIndex = 0;
        _drawPoints = YES;
        _drawLines = YES;
    }
    return self;
}

- (void)dealloc {
    [_lifeTimer invalidate];
    _lifeTimer = nil;
    
    glDeleteVertexArrays(2, vertexArray);
    glDeleteProgram(_updateProgram);
    glDeleteProgram(_renderProgram);
    glDeleteBuffers(5, vertexArrayBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    glDeleteTextures(2, positionTbo);
}

- (void)prepareOpenGL {
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [self loadShaders];
    
    GLKVector4 *initialPositions = (GLKVector4 *)malloc(sizeof(GLKVector4)*POINTS_TOTAL);
    GLKVector3 *initialVelocities = (GLKVector3 *)malloc(sizeof(GLKVector4)*POINTS_TOTAL);
    GLKIVector4 *connectionVectors = (GLKIVector4 *)malloc(sizeof(GLKIVector4)*POINTS_TOTAL);
    
    int n = 0;
    for (int j = 0; j < POINTS_Y; j++) {
        float fj = (float)j/(float)POINTS_Y;
        for (int i = 0; i < POINTS_X; i++) {
            float fi = (float)i / (float)POINTS_X;
            initialPositions[n] = GLKVector4Make((fi - 0.5f) * (float)POINTS_X,
                                                 (fj - 0.5f) * (float)POINTS_Y,
                                                 0.6f*sinf(fi)*cosf(fj),
                                                 1.0f);
            initialVelocities[n] = GLKVector3Make(0.0f, 0.0f, 0.0f);
            connectionVectors[n] = GLKIVector4Make(-1, -1, -1, -1);
            
            if (j != (POINTS_Y - 1)) {
                if (i != 0) {
                    connectionVectors[n].x = n - 1;
                }
                if (j != 0) {
                    connectionVectors[n].y = n - POINTS_X;
                }
                if (i != (POINTS_X - 1)) {
                    connectionVectors[n].z = n + 1;
                }
                if (j != (POINTS_Y - 1)) {
                    connectionVectors[n].w = n + POINTS_X;
                }
            }
            n++;
        }
    }
    
    glGenVertexArrays(2, vertexArray);
    glGenBuffers(5, vertexArrayBuffer);
    
    for (int i = 0; i < 2; i++) {
        glBindVertexArray(vertexArray[i]);
        glBindBuffer(GL_ARRAY_BUFFER, vertexArrayBuffer[POSITION_A + i]);
        glBufferData(GL_ARRAY_BUFFER, POINTS_TOTAL * sizeof(GLKVector4), initialPositions, GL_DYNAMIC_COPY);
        glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, NULL);
        glEnableVertexAttribArray(0);
        
        glBindBuffer(GL_ARRAY_BUFFER, vertexArrayBuffer[VELOCITY_A + i]);
        glBufferData(GL_ARRAY_BUFFER, POINTS_TOTAL*sizeof(GLKVector3), initialVelocities, GL_DYNAMIC_COPY);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 0, NULL);
        glEnableVertexAttribArray(1);
        
        glBindBuffer(GL_ARRAY_BUFFER, vertexArrayBuffer[CONNECTION]);
        glBufferData(GL_ARRAY_BUFFER, POINTS_TOTAL * sizeof(GLKIVector4), connectionVectors, GL_STATIC_COPY);
        glVertexAttribIPointer(2, 4, GL_INT, 0, NULL);
        glEnableVertexAttribArray(2);
    }
    
    free(initialPositions);
    free(initialVelocities);
    free(connectionVectors);
    
    glGenTextures(2, positionTbo);
    glBindTexture(GL_TEXTURE_BUFFER, positionTbo[0]);
    glTexBuffer(GL_TEXTURE_BUFFER, GL_RGBA32F, vertexArrayBuffer[POSITION_A]);
    glBindTexture(GL_TEXTURE_BUFFER, positionTbo[1]);
    glTexBuffer(GL_TEXTURE_BUFFER, GL_RGBA32F, vertexArrayBuffer[POSITION_B]);
    
    // lines的缓存中记录所有连线两端顶点索引值，先记录所有横线，再记录所有竖线，横线从左到右，竖线从上到下
    int lines = (POINTS_X - 1) * POINTS_Y + (POINTS_Y - 1) * POINTS_X;
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, lines * 2 * sizeof(int), NULL, GL_STATIC_DRAW);
    int *e = (int *)glMapBufferRange(GL_ELEMENT_ARRAY_BUFFER, 0, lines * 2 * sizeof(int), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    for (int j = 0; j < POINTS_Y; j++) {
        for (int i = 0; i < POINTS_X - 1; i++) {
            *e++ = i + j * POINTS_X;
            *e++ = 1 + i + j * POINTS_X;
        }
    }
    for (int i = 0; i < POINTS_X; i++) {
        for (int j = 0; j < POINTS_Y - 1; j++) {
            *e++ = i + j * POINTS_X;
            *e++ = POINTS_X + i + j * POINTS_X;
        }
    }
    
    glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    glUseProgram(_updateProgram);
    glEnable(GL_RASTERIZER_DISCARD);
    for (NSInteger i = _iterationPerFrame; i != 0; i--) {
        glBindVertexArray(vertexArray[_iterationIndex & 1]);
        glBindTexture(GL_TEXTURE_BUFFER, positionTbo[_iterationIndex & 1]);
        glUniform1i(_textureVertextLoc, 0);
        // 此处对索引+1包装转换反馈用的是另一组缓存来存储数据
        _iterationIndex++;
        glBindBufferBase(GL_TRANSFORM_FEEDBACK_BUFFER, 0, vertexArrayBuffer[POSITION_A + (_iterationIndex & 1)]);
        glBindBufferBase(GL_TRANSFORM_FEEDBACK_BUFFER, 1, vertexArrayBuffer[VELOCITY_A + (_iterationIndex & 1)]);
        glBeginTransformFeedback(GL_POINTS);
        glDrawArrays(GL_POINTS, 0, POINTS_TOTAL);
        glEndTransformFeedback();
    }
    glDisable(GL_RASTERIZER_DISCARD);
    
    static const GLfloat black[] = {0.0f, 0.0f, 0.0f, 0.0f};
    glClearBufferfv(GL_COLOR, 0, black);
    
    glUseProgram(_renderProgram);
    if (_drawPoints) {
        glPointSize(4.0f);
        glDrawArrays(GL_POINTS, 0, POINTS_TOTAL);
    }
    if (_drawLines) {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
        glDrawElements(GL_LINES, CONNECTIONS_TOTAL*2, GL_UNSIGNED_INT, NULL);
    }
    glFlush();
}

#pragma mark - public methods

#pragma mark - private methods
- (BOOL)loadShaders {
    GLuint vertexShader;
    GLuint fragShader;
    NSString *verShaderPathName;
    NSString *fraShaderPathName;
    
    _updateProgram = glCreateProgram();
    verShaderPathName = [[NSBundle mainBundle] pathForResource:@"update" ofType:@"vsh"];
    if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER filePath:verShaderPathName]) {
        NSLog(@"Failed to compile vertex shader");
    }
    fraShaderPathName = [[NSBundle mainBundle] pathForResource:@"update" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER filePath:fraShaderPathName]) {
        NSLog(@"Failed to compile fragment shader");
    }
    
    glAttachShader(_updateProgram, vertexShader);
    glAttachShader(_updateProgram, fragShader);
    
    static const char *tf_varyings[] = {
        "tf_position_mass",
        "tf_velocity"
    };
    glTransformFeedbackVaryings(_updateProgram, 2, tf_varyings, GL_SEPARATE_ATTRIBS);
    
    if (![self linkProgram:_updateProgram]) {
        NSLog(@"Failed to link program: %d", _updateProgram);
        if (_updateProgram != 0) {
            glDeleteProgram(_updateProgram);
            _updateProgram = 0;
        }
        return NO;
    }
    
    _textureVertextLoc = glGetUniformLocation(_updateProgram, "tex_position");
    
    _renderProgram = glCreateProgram();
    verShaderPathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER filePath:verShaderPathName]) {
        NSLog(@"Failed to compile vertex shader");
    }
    fraShaderPathName = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER filePath:fraShaderPathName]) {
        NSLog(@"Failed to compile fragment shader");
    }
    
    glAttachShader(_renderProgram, vertexShader);
    glAttachShader(_renderProgram, fragShader);
    
    if (vertexShader != 0) {
        glDeleteShader(vertexShader);
        vertexShader = 0;
    }
    if (fragShader != 0) {
        glDeleteShader(fragShader);
        fragShader = 0;
    }
    
    if (![self linkProgram:_renderProgram]) {
        NSLog(@"Failed to link program: %d", _renderProgram);
        if (_renderProgram != 0) {
            glDeleteProgram(_renderProgram);
            _renderProgram = 0;
        }
        return NO;
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



