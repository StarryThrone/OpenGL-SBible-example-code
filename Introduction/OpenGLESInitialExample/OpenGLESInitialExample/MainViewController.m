//
//  MainViewController.m
//  OpenGLESInitialExample
//
//  Created by chenjie on 2019/4/2.
//  Copyright © 2019 starrythrone. All rights reserved.
//

#import "MainViewController.h"

@interface MainViewController ()

@property (atomic, assign) GLuint program;
@property (atomic, assign) GLuint vertexArray;

@end

@implementation MainViewController

#pragma mark - Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    GLKView *view = (GLKView *)self.view;
    view.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    view.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    view.drawableStencilFormat = GLKViewDrawableStencilFormat8;
    view.drawableMultisample = GLKViewDrawableMultisample4X;
    [EAGLContext setCurrentContext:view.context];
    // Set animation frame rate
    self.preferredFramesPerSecond = 60;
    [self prepareOpenGL];
}

#pragma mark - Override
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    glClearColor(0.0f, 0.0f, 0.1f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glUseProgram(_program);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glFlush();
}

#pragma mark - Private Methods
- (void)printAllSupportedExtensions {
    int max = 0;
    glGetIntegerv(GL_NUM_EXTENSIONS, &max);
    NSMutableSet *extensions = [NSMutableSet set];
    for (int i = 0; i < max; i++) {
        [extensions addObject:@((char *)glGetStringi(GL_EXTENSIONS, i))];
    }
    NSLog(@"%@", extensions);
}

- (void)prepareOpenGL {
    [self loadShaders];
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
}

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
    
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        if (vertexShader != 0) {
            glDeleteShader(vertexShader);
            vertexShader = 0;
        }
        if (fragShader != 0) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program != 0) {
            glDeleteProgram(_program);
            _program = 0;
        }
        return NO;
    }
    
    if (vertexShader != 0) {
        glDetachShader(_program, vertexShader);
        glDeleteShader(vertexShader);
    }
    if (fragShader != 0) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
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

@end
