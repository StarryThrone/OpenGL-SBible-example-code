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

// Random number generator
static unsigned int seed = 0x13371337;
static inline float random_float() {
    float res;
    unsigned int tmp;
    
    seed *= 16807;
    
    tmp = seed ^ (seed >> 4) ^ (seed << 15);
    
    *((unsigned int *) &res) = (tmp >> 9) | 0x3F800000;
    
    return (res - 1.0f);
}

#define mStartsNumber 2000

@interface GLCoreProfileView()

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) BOOL paused;

@property (atomic, assign) GLuint vertexArrayObject;
@property (nonatomic, assign) GLuint startTexture;
@property (nonatomic, assign) GLuint startPropertyBuffer;

@property (atomic, assign) GLuint glProgram;
@property (nonatomic, assign) GLint timeLocation;
@property (nonatomic, assign) GLint proj_matrixLoation;
@property (nonatomic, assign) GLint tex_starLocation;

@end

@implementation GLCoreProfileView
#pragma mark - lifecycle methods
- (instancetype)initWithCoder:(NSCoder *)decoder {
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAStencilSize, 8,
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
    
    [[TextureManager shareManager] loadObjectWithFileName:@"star.ktx" toTextureID:&_startTexture];
    
    typedef struct _start_t {
        GLKVector3 position;
        GLKVector3 color;
    } start_t;
    glGenBuffers(1, &_startPropertyBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, self.startPropertyBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(start_t) * mStartsNumber, NULL, GL_STATIC_DRAW);
    
    start_t *starts = (start_t *)glMapBufferRange(GL_ARRAY_BUFFER, 0, sizeof(start_t) * mStartsNumber, GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    for (int i = 0; i < 1000; i++) {
        starts[i].position = GLKVector3Make((random_float() * 2.0f - 1.0f) * 100.0f,
                                            (random_float() * 2.0f - 1.0f) * 100.0f,
                                            random_float());
        starts[i].color = GLKVector3Make(0.8f + random_float() * 0.2f,
                                         0.8f + random_float() * 0.2f,
                                         0.8f + random_float() * 0.2f);
    }
    glUnmapBuffer(GL_ARRAY_BUFFER);
    
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(start_t), NULL);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(start_t), (void *)sizeof(GLKVector3));
    glEnableVertexAttribArray(1);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE);
    glEnable(GL_PROGRAM_POINT_SIZE);
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
    
    static const GLfloat black[] = {0.0f, 0.0f, 0.0f, 0.0f};
    glClearBufferfv(GL_COLOR, 0, black);
    static const GLfloat one[] = {1.0f};
    glClearBufferfv(GL_DEPTH, 0, one);
    
    glUseProgram(self.glProgram);
    float t = (float)total_time;
    t *= 0.1;
    t -= floorf(t);
    glUniform1f(self.timeLocation, t);
    NSRect bounds = [self bounds];
    GLKMatrix4 proj_matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0f), NSWidth(bounds) / NSHeight(bounds), 0.1f, 1000.0f);
    glUniformMatrix4fv(self.proj_matrixLoation, 1, GL_FALSE, proj_matrix.m);
    
    glDrawArrays(GL_POINTS, 0, mStartsNumber);
    
    glFlush();
}

#pragma mark - private methods
- (BOOL)loadShaders {
    GLuint vertex_Shader, frag_Shader;
    // 1. Create program
    NSString *vs_Path = [[NSBundle mainBundle] pathForResource:@"VS" ofType:@"glsl"];
    NSString *fs_Path = [[NSBundle mainBundle] pathForResource:@"FS" ofType:@"glsl"];
    
    if (![self compileShader:&vertex_Shader type:GL_VERTEX_SHADER filePath:vs_Path]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&frag_Shader type:GL_FRAGMENT_SHADER filePath:fs_Path]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    self.glProgram = glCreateProgram();
    glAttachShader(self.glProgram, vertex_Shader);
    glAttachShader(self.glProgram, frag_Shader);
    glDeleteShader(vertex_Shader);
    vertex_Shader = 0;
    glDeleteShader(frag_Shader);
    frag_Shader = 0;
    
    if (![self linkProgram:self.glProgram]) {
        NSLog(@"Failed to link sceneProgram");
        if (self.glProgram != 0) {
            glDeleteProgram(self.glProgram);
            self.glProgram = 0;
        }
        return NO;
    }
    self.timeLocation = glGetUniformLocation(self.glProgram, "time");
    self.proj_matrixLoation = glGetUniformLocation(self.glProgram, "proj_matrix");
    self.tex_starLocation = glGetUniformLocation(self.glProgram, "tex_star");
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



