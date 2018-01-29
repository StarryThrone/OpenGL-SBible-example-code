//
//  TDModelManger.m
//  ConfigureEnvironment
//
//  Created by 陈杰 on 11/12/2017.
//  Copyright © 2017 陈杰. All rights reserved.
//

#import "TDModelManger.h"
#import <stdio.h>

#define MAX_SUB_OBJECTS 256

@interface TDModelManger()

@property (nonatomic, assign) GLuint vertex_buffer;
@property (nonatomic, assign) GLuint index_buffer;
@property (nonatomic, assign) GLuint num_indices;
@property (nonatomic, assign) GLuint index_type;


@property (nonatomic, strong) NSArray *sub_object;
@end

@implementation TDModelManger

+ (instancetype)shareManager {
    static TDModelManger *shareManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareManager = [[TDModelManger alloc] init];
    });
    return shareManager;
}

- (void)loadObjectWithFileName:(NSString *)name {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:name ofType:nil];
    FILE *infile = fopen([filePath cStringUsingEncoding:NSUTF8StringEncoding], "rb");
    size_t filesize;
    char *data;
    
    [self free];
    
    fseek(infile, 0, SEEK_END);
    filesize = ftell(infile);
    fseek(infile, 0, SEEK_SET);
    
    data = (char *)malloc(filesize);
    fread(data, filesize, 1, infile);
    
    char *ptr = data;
    SB6M_HEADER *header = (SB6M_HEADER *)ptr;
    ptr += header->size;
    
    SB6M_VERTEX_ATTRIB_CHUNK *vertex_attrib_chunk = NULL;
    SB6M_CHUNK_VERTEX_DATA *vertex_data_chunk = NULL;
    SB6M_CHUNK_INDEX_DATA *index_data_chunk = NULL;
    SB6M_CHUNK_SUB_OBJECT_LIST *sub_object_chunk = NULL;
    
    for (int i = 0; i < header->num_chunks; i++) {
        SB6M_CHUNK_HEADER *chunk = (SB6M_CHUNK_HEADER *)ptr;
        ptr += chunk->size;
        switch (chunk->chunk_type) {
            case SB6M_CHUNK_TYPE_VERTEX_ATTRIBS:
                vertex_attrib_chunk = (SB6M_VERTEX_ATTRIB_CHUNK *)chunk;
                break;
            case SB6M_CHUNK_TYPE_VERTEX_DATA:
                vertex_data_chunk = (SB6M_CHUNK_VERTEX_DATA *)chunk;
                break;
            case SB6M_CHUNK_TYPE_INDEX_DATA:
                index_data_chunk = (SB6M_CHUNK_INDEX_DATA *)chunk;
                break;
            case SB6M_CHUNK_TYPE_SUB_OBJECT_LIST:
                sub_object_chunk = (SB6M_CHUNK_SUB_OBJECT_LIST *)chunk;
                break;
            default:
                break;
        }
    }
    
    if (sub_object_chunk != NULL) {
        if (sub_object_chunk->count > MAX_SUB_OBJECTS) {
            sub_object_chunk->count = MAX_SUB_OBJECTS;
        }
        
        NSMutableArray *temp = [[NSMutableArray alloc] initWithCapacity:5];
        for (int i = 0; i < sub_object_chunk->count; i++) {
            SB6M_SUB_OBJECT_DECL object_decl = sub_object_chunk->sub_object[i];
            NSValue *value = [NSValue valueWithBytes:&object_decl objCType:@encode(SB6M_SUB_OBJECT_DECL)];
            [temp addObject:value];
        }
        _sub_object = temp.copy;
        _num_sub_objects = sub_object_chunk->count;
    } else {
        SB6M_SUB_OBJECT_DECL object_decl;
        object_decl.first = 0;
        object_decl.count = vertex_data_chunk->total_vertices;
        _num_sub_objects = 1;
        
        NSValue *value = [NSValue valueWithBytes:&object_decl objCType:@encode(SB6M_SUB_OBJECT_DECL)];
        _sub_object = [[NSArray alloc] initWithObjects:value, nil];
    }
    
    glGenBuffers(1, &_vertex_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertex_buffer);
    glBufferData(GL_ARRAY_BUFFER, vertex_data_chunk->data_size, data+vertex_data_chunk->data_offset, GL_STATIC_DRAW);
    
    glGenVertexArrays(1, &_vao);
    glBindVertexArray(_vao);
    
    for (int i = 0; i < vertex_attrib_chunk->attrib_count; i++) {
        SB6M_VERTEX_ATTRIB_DECL attrib_decl = vertex_attrib_chunk->attrib_data[i];
        glVertexAttribPointer(i,
                              attrib_decl.size,
                              attrib_decl.type,
                              attrib_decl.flags & SB6M_VERTEX_ATTRIB_FLAG_NORMALIZED ? GL_TRUE : GL_FALSE,
                              attrib_decl.stride,
                              (GLvoid *)(uintptr_t)attrib_decl.data_offset);
        glEnableVertexAttribArray(i);
    }
    
    if (index_data_chunk != NULL) {
        glGenBuffers(1, &_index_buffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _index_buffer);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER,
                     index_data_chunk->index_count * (index_data_chunk->index_type == GL_UNSIGNED_SHORT ? sizeof(GLushort) : sizeof(GLubyte)),
                     data + index_data_chunk->index_data_offset, GL_STATIC_DRAW);
        _num_indices = index_data_chunk->index_count;
        _index_type = index_data_chunk->index_type;
    } else {
        _num_indices = vertex_data_chunk->total_vertices;
    }
    
    free(data);
    fclose(infile);
    //    glBindVertexArray(0);
    //    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

- (void)free {
    glDeleteVertexArrays(1, &_vao);
    glDeleteBuffers(1, &_vertex_buffer);
    glDeleteBuffers(1, &_index_buffer);
    
    _vao = 0;
    _vertex_buffer = 0;
    _index_buffer = 0;
    _num_indices = 0;
}

- (void)render {
    if (_index_buffer != 0) {
        glDrawElementsInstanced(GL_TRIANGLES,
                                _num_indices,
                                _index_type,
                                0,
                                1);
    } else {
        SB6M_SUB_OBJECT_DECL object_decl;
        NSValue *object_dec1_value = self.sub_object.firstObject;
        [object_dec1_value getValue:&object_decl];
        glDrawArraysInstanced(GL_TRIANGLES,
                              object_decl.first,
                              object_decl.count,
                              1);
    }
}

- (void)getSubObjectInfoWithIndex:(NSUInteger)index first:(GLuint *)first count:(GLuint *)count {
    if (index >= _num_sub_objects) {
        *first = 0;
        *count = 0;
    } else {
        NSValue *subObjectValue = _sub_object[index];
        SB6M_SUB_OBJECT_DECL subObject;
        [subObjectValue getValue:&subObject];
        *first = subObject.first;
        *count = subObject.count;
    }
}
@end
