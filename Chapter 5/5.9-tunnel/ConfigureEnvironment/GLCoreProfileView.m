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

@interface GLCoreProfileView()
@property (atomic, strong) NSTimer *lifeTimer;
@property (atomic, assign) CGFloat lifeDuration;

@property (atomic, assign) GLuint program;
@property (atomic, assign) GLuint vertexArray;
@property (atomic, assign) GLuint vertexArrayBuffer;

@property (atomic, assign) GLuint texture0;
@property (atomic, assign) GLuint texture1;
@property (atomic, assign) GLuint texture2;

@property (atomic, assign) GLint textureLoc;
@property (atomic, assign) GLint mvp_loc;
@property (atomic, assign) GLint offset_loc;
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
    glDeleteTextures(1, &_texture1);
    glDeleteTextures(1, &_texture2);
}

- (void)prepareOpenGL {
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    NSLog(@"Supported compress texture format: %s", glGetString(GL_EXTENSIONS));
    [self loadShaders];
    
    [[TextureManager shareManager] loadObjectWithFileName:@"brick.ktx" toTextureID:&_texture0];
    [[TextureManager shareManager] loadObjectWithFileName:@"ceiling.ktx" toTextureID:&_texture1];
    [[TextureManager shareManager] loadObjectWithFileName:@"floor.ktx" toTextureID:&_texture2];
    
    GLuint textures[] = {_texture0, _texture1, _texture2};
    for (int i = 0; i < 3; i++) {
        glBindTexture(GL_TEXTURE_2D, textures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    }
    
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    static const GLfloat black[] = { 0.0f, 0.0f, 0.0f, 0.0f };
    glClearBufferfv(GL_COLOR, 0, black);
    glUseProgram(_program);
    
    NSRect bounds = [self bounds];
    glUniform1f(_offset_loc, _lifeDuration * 0.003f);

    GLKMatrix4 proj_matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(60.0f), NSWidth(bounds)/NSHeight(bounds), 0.1f, 100.0f);
    GLKMatrix4 scale_matrix = GLKMatrix4MakeScale(30.0f, 1.0f, 1.0f);
    GLKMatrix4 rotateYMatrix = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(90.0f), 0.0f, 1.0f, 0.0f);
    GLKMatrix4 traslateMatrix = GLKMatrix4MakeTranslation(-0.5f, 0.0f, -10.0f);
    GLuint textures[] = { _texture0, _texture2, _texture0, _texture1 };
    for (int i = 0; i < 4; i++) {
        GLKMatrix4 rotateZMatrix = GLKMatrix4MakeRotation(GLKMathDegreesToRadians(90.0f*i), 0.0f, 0.0f, 1.0f);
        GLKMatrix4 mv_matrix = GLKMatrix4Multiply(GLKMatrix4Multiply(GLKMatrix4Multiply(rotateZMatrix, traslateMatrix), rotateYMatrix), scale_matrix);
        GLKMatrix4 mvp_matrix = GLKMatrix4Multiply(proj_matrix, mv_matrix);
        glUniformMatrix4fv(_mvp_loc, 1, GL_FALSE, mvp_matrix.m);
        // 需要注意的是第一个函数中参数结束的数字必须和第三个函数的第二个参数的数字一致
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, textures[i]);
        glUniform1i(_textureLoc, 0);
        
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

    _mvp_loc = glGetUniformLocation(_program, "mvp");
    _offset_loc = glGetUniformLocation(_program, "offset");
    _textureLoc = glGetUniformLocation(_program, "tex");
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



