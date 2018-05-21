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
#import "TDModelManger.h"
#import "TextureManager.h"

#define B 0x00, 0x00, 0x00, 0x00
#define W 0xFF, 0xFF, 0xFF, 0xFF

static unsigned int seed = 0x13371337;
static inline float random_float() {
    float res;
    unsigned int tmp;
    seed *= 16807;
    tmp = seed ^ (seed >> 4) ^ (seed << 15);
    *((unsigned int *) &res) = (tmp >> 9) | 0x3F800000;
    return (res - 1.0f);
}

@interface GLCoreProfileView() {
@private
    float           droplet_x_offset[256];
    float           droplet_rot_speed[256];
    float           droplet_fall_speed[256];
}

@property (atomic, strong) NSTimer *lifeTimer;
@property (atomic, assign) CGFloat lifeDuration;

@property (atomic, assign) GLuint program;
@property (atomic, assign) GLuint vertexArray;
@property (atomic, assign) GLuint vertexArrayBuffer;
@property (atomic, assign) GLuint rainBuffer;

@property (atomic, assign) GLuint texture0;

@property (atomic, assign) GLint alien_index_loc;
@property (atomic, assign) GLint textureLoc;
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
    glDeleteTextures(1, &_texture0);
}

- (void)prepareOpenGL {

    
    
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    [self loadShaders];
    
    [[TextureManager shareManager] loadObjectWithFileName:@"aliens.ktx" toTextureID:&_texture0];
    glBindTexture(GL_TEXTURE_2D_ARRAY, _texture0);
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    
    glGenBuffers(1, &_rainBuffer);
    glBindBuffer(GL_UNIFORM_BUFFER, _rainBuffer);
    glBufferData(GL_UNIFORM_BUFFER, 256*16, NULL, GL_DYNAMIC_DRAW);
    
    for (int i = 0; i < 256; i++) {
        droplet_x_offset[i] = random_float() * 2.0f - 1.0f;
        droplet_rot_speed[i] = (random_float() + 0.5f) * ((i & 1) ? -3.0f : 3.0f);
        droplet_fall_speed[i] = random_float() + 0.2f;
    }
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    static const GLfloat green[] = { 0.0f, 0.1f, 0.0f, 1.0f };
    glClearBufferfv(GL_COLOR, 0, green);
    glUseProgram(_program);

    glBindBufferBase(GL_UNIFORM_BUFFER, 0, _rainBuffer);
    GLKVector4 *droplet = (GLKVector4 *)glMapBufferRange(GL_UNIFORM_BUFFER, 0, 256*16, GL_MAP_WRITE_BIT|GL_MAP_INVALIDATE_BUFFER_BIT);
    for (int i = 0; i < 256; i++) {
        droplet[i].x = droplet_x_offset[i];
        droplet[i].y = 2.0f - fmodf((_lifeDuration + i) * droplet_fall_speed[i], 4.31f);
        droplet[i].z = _lifeDuration * droplet_rot_speed[i];
        droplet[i].w = 0.0f;
    }
    glUnmapBuffer(GL_UNIFORM_BUFFER);
    
    for (int alien_index = 0; alien_index < 60; alien_index++) {
        glVertexAttribI1i(_alien_index_loc, alien_index);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
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
    
    _alien_index_loc = glGetAttribLocation(_program, "alien_index");
    _textureLoc = glGetUniformLocation(_program, "tex_aliens");
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



