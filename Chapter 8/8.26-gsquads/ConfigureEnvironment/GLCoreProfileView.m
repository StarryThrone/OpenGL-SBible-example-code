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

@interface GLCoreProfileView() {
@private
    GLKVector3 patchData[16];
}

@property (nonatomic, strong) NSTimer *lifeTimer;
@property (nonatomic, assign) CGFloat lifeDuration;
@property (nonatomic, assign) BOOL paused;

@property (atomic, assign) GLuint program_fans;
@property (atomic, assign) GLuint program_linesadjacency;
@property (atomic, assign) NSInteger mode;
@property (atomic, assign) GLuint vertexArray;

@property (atomic, assign) GLint mvp_fansLocation;
@property (atomic, assign) GLint vid_fans_offsetLocation;

@property (atomic, assign) GLint mvp_lineLocation;
@property (atomic, assign) GLint vid_line_offsetLocation;

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
    
//    glEnable(GL_DEPTH_TEST);
//    glDepthFunc(GL_LEQUAL);
}

- (void)reshape {
    NSRect bounds = [self bounds];
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));
}

- (void)drawRect:(NSRect)dirtyRect {
    static const GLfloat backColor[] = { 0.1f, 0.3f, 0.0f, 1.0f  };
    glClearBufferfv(GL_COLOR, 0, backColor);
    
    static double last_time = 0.0;
    static double total_time = 0.0;
    if (!_paused) {
        total_time += (_lifeDuration - last_time);
    }
    last_time = _lifeDuration;
    float t = (float)total_time;
    
    NSRect bounds = [self bounds];
    GLKMatrix4 rotateX = GLKMatrix4MakeRotation(GLKMathDegreesToRadians((float)t * 30.0f*0.0), 1.0f, 0.0f, 0.0f);
    GLKMatrix4 rotateZ = GLKMatrix4MakeRotation(GLKMathDegreesToRadians((float)t * 5.0f*0.0 + 135), 0.0f, 0.0f, 1.0f);
    GLKMatrix4 translation = GLKMatrix4MakeTranslation(0.0f, 0.0f, -2.0f);
    GLKMatrix4 mvMatrix = GLKMatrix4Multiply(translation, GLKMatrix4Multiply(rotateZ, rotateX));
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(50.0f), NSWidth(bounds)/NSHeight(bounds), 0.1f, 1000.0f);
    GLKMatrix4 mvpMatrix = GLKMatrix4Multiply(projectionMatrix, mvMatrix);
    
    if (self.mode) {
        glUseProgram(_program_fans);
        glUniformMatrix4fv(_mvp_fansLocation, 1, GL_FALSE, mvpMatrix.m);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    } else {
        glUseProgram(_program_linesadjacency);
        glUniformMatrix4fv(_mvp_lineLocation, 1, GL_FALSE, mvpMatrix.m);
        glDrawArrays(GL_LINES_ADJACENCY, 0, 4);
    }

    glFlush();
}

#pragma mark - public methods

#pragma mark - private methods
- (BOOL)loadShaders {
    GLuint vertex_fansShader, frag_fansShader;
    NSString *vs_fansPath = [[NSBundle mainBundle] pathForResource:@"quadsasfansVS" ofType:@"glsl"];
    NSString *fs_fansPath = [[NSBundle mainBundle] pathForResource:@"quadsasfansFS" ofType:@"glsl"];
    
    if (![self compileShader:&vertex_fansShader type:GL_VERTEX_SHADER filePath:vs_fansPath]) {
        NSLog(@"Failed to compile GL_VERTEX_SHADER");
    }
    if (![self compileShader:&frag_fansShader type:GL_FRAGMENT_SHADER filePath:fs_fansPath]) {
        NSLog(@"Failed to compile GL_FRAGMENT_SHADER");
    }
    
    _program_fans = glCreateProgram();
    glAttachShader(_program_fans, vertex_fansShader);
    glAttachShader(_program_fans, frag_fansShader);
    GLuint shaders[] = {vertex_fansShader, frag_fansShader};
    for (int i = 0; i < 2; i++) {
        GLuint deleteShader = shaders[i];
        glDeleteShader(deleteShader);
        deleteShader = 0;
    }
    
    if (![self linkProgram:_program_fans]) {
        NSLog(@"Failed to link _tessProgram");
        if (_program_fans != 0) {
            glDeleteProgram(_program_fans);
            _program_fans = 0;
        }
        return NO;
    }
    _mvp_fansLocation = glGetUniformLocation(_program_fans, "mvp");
    _vid_fans_offsetLocation = glGetUniformLocation(_program_fans, "vid_offset");
    
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
    
    _program_linesadjacency = glCreateProgram();
    glAttachShader(_program_linesadjacency, vertex_lineShader);
    glAttachShader(_program_linesadjacency, ge_lineShader);
    glAttachShader(_program_linesadjacency, frag_lineShader);
    GLuint shaders2[] = {vertex_lineShader, ge_lineShader, frag_lineShader};
    for (int i = 0; i < 3; i++) {
        GLuint deleteShader = shaders2[i];
        glDeleteShader(deleteShader);
        deleteShader = 0;
    }
    
    if (![self linkProgram:_program_linesadjacency]) {
        NSLog(@"Failed to link _tessProgram");
        if (_program_linesadjacency != 0) {
            glDeleteProgram(_program_linesadjacency);
            _program_linesadjacency = 0;
        }
        return NO;
    }
    _mvp_lineLocation = glGetUniformLocation(_program_linesadjacency, "mvp");
    _vid_line_offsetLocation = glGetUniformLocation(_program_linesadjacency, "vid_offset");
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



