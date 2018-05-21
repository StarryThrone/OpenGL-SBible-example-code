//
//  TextureManager.h
//  ConfigureEnvironment
//
//  Created by 陈杰 on 11/12/2017.
//  Copyright © 2017 陈杰. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <GLKit/GLKit.h>

typedef struct header_t {
    unsigned char       identifier[12];
    unsigned int        endianness;
    unsigned int        gltype;
    unsigned int        gltypesize;
    unsigned int        glformat;
    unsigned int        glinternalformat;
    unsigned int        glbaseinternalformat;
    unsigned int        pixelwidth;
    unsigned int        pixelheight;
    unsigned int        pixeldepth;
    unsigned int        arrayelements;
    unsigned int        faces;
    unsigned int        miplevels;
    unsigned int        keypairbytes;
} header;

@interface TextureManager : NSObject

+ (instancetype)shareManager;
- (int)loadObjectWithFileName:(NSString *)name toTextureID:(GLuint *)texureID;

@end
