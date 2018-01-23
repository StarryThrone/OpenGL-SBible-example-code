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

@interface GLCoreProfileView()
@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;

@property (nonatomic, assign) GLuint program;
@property (nonatomic, assign) GLuint vertexArray;
@property (nonatomic, assign) GLuint vertexArrayBuffer;

@property (nonatomic, assign) GLuint colorTxtureID;
@property (nonatomic, assign) GLuint lengthTxtureID;
@property (nonatomic, assign) GLuint orientationTxtureID;
@property (nonatomic, assign) GLuint bendTxtureID;

@property (nonatomic, assign) GLint mvp_location;
@property (nonatomic, assign) GLint colorTextureLoc;
@property (nonatomic, assign) GLint lengthTextureLoc;
@property (nonatomic, assign) GLint orientationTextureLoc;
@property (nonatomic, assign) GLint bendTextureLoc;
@property (nonatomic, assign) GLKMatrix4 mvp_Matrix;
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
    glDeleteTextures(1, &_colorTxtureID);
    glDeleteTextures(1, &_bendTxtureID);
    glDeleteTextures(1, &_orientationTxtureID);
    glDeleteTextures(1, &_lengthTxtureID);
}

- (void)prepareOpenGL {
    NSLog(@"Version: %s", glGetString(GL_VERSION));
    NSLog(@"Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"Vendor: %s", glGetString(GL_VENDOR));
    NSLog(@"GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    [self loadShaders];
    
    static const GLfloat grass_blade[] = {
        -0.3f,      0.0f,
        0.3f,       0.0f,
        -0.20f,     1.0f,
        0.1f,       1.3f,
        -0.05f,     2.3f,
        0.0f,       3.3f
    };
    
    // Now generate some data and put it in a buffer object
    glGenVertexArrays(1, &_vertexArray);
    glBindVertexArray(_vertexArray);
    
    glGenBuffers(1, &_vertexArrayBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexArrayBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(grass_blade), grass_blade, GL_STATIC_DRAW);
    
    glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    
    [[TextureManager shareManager] loadObjectWithFileName:@"grass_length.ktx" toTextureID:&_lengthTxtureID];
    [[TextureManager shareManager] loadObjectWithFileName:@"grass_orientation.ktx" toTextureID:&_orientationTxtureID];
    [[TextureManager shareManager] loadObjectWithFileName:@"grass_color.ktx" toTextureID:&_colorTxtureID];
    [[TextureManager shareManager] loadObjectWithFileName:@"grass_bend.ktx" toTextureID:&_bendTxtureID];
    
    GLuint textures[] = {_lengthTxtureID, _orientationTxtureID, _colorTxtureID, _bendTxtureID};
    for (int i = 0; i < 4; i++) {
        glBindTexture(GL_TEXTURE_2D, textures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    }
    
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    static const GLfloat black[] = { 0.0f, 0.0f,
        0.0f, 1.0f };
    static const GLfloat depth = 1.0f;
    glClearBufferfv(GL_COLOR, 0, black);
    glClearBufferfv(GL_DEPTH, 0, &depth);
    
    // 设置观察位置，通过不断移动眼睛位置达到从草地走过的效果
    float t = _lifeDuration*0.02f;
    float r = 550.0f;
    GLKMatrix4 mv_matrix = GLKMatrix4MakeLookAt(sinf(t)*r, 25.0f, cosf(t)*r,
                                                0.0f, -50.0f, 0.0f,
                                                0.0, 1.0, 0.0);
    GLfloat aspect = NSWidth([self bounds])/NSHeight([self bounds]);
    GLKMatrix4 prj_matrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(45.0), aspect, 0.1f, 1000.0f);
    _mvp_Matrix = GLKMatrix4Multiply(prj_matrix, mv_matrix);
    
    glUseProgram(_program);
    glUniformMatrix4fv(_mvp_location, 1, GL_FALSE, _mvp_Matrix.m);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _lengthTxtureID);
    glUniform1i(_lengthTextureLoc, 1);
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, _orientationTxtureID);
    glUniform1i(_orientationTextureLoc, 2);
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, _colorTxtureID);
    glUniform1i(_colorTextureLoc, 3);
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, _colorTxtureID);
    glUniform1i(_colorTextureLoc, 4);
    
    glBindVertexArray(_vertexArray);
    glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 6, 1024*1024);
    
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

    _mvp_location = glGetUniformLocation(_program, "mvpMatrix");
    _colorTextureLoc = glGetUniformLocation(_program, "");
    _bendTextureLoc = glGetUniformLocation(_program, "");
    _orientationTextureLoc = glGetUniformLocation(_program, "");
    _lengthTextureLoc = glGetUniformLocation(_program, "");
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



