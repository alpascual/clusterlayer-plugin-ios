//
//  AGSClusterGridRow.m
//  Cluster Layer
//
//  Created by Nicholas Furness on 4/7/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterGridRow.h"
#import "AGSCluster.h"
#import "AGSCluster_int.h"
#import "AGSClusterGrid.h"

@interface AGSClusterGridRow ()
@property (nonatomic, strong, readwrite) NSMutableDictionary *clusters;
@end

@implementation AGSClusterGridRow
+(AGSClusterGridRow *)clusterGridRowForClusterGrid:(AGSClusterGrid *)grid {
    return [[AGSClusterGridRow alloc] initForClusterGrid:grid];
}

-(id)initForClusterGrid:(AGSClusterGrid *)grid {
    self = [super init];
    if (self) {
        self.clusters = [NSMutableDictionary dictionary];
        self.parentGrid = grid;
    }
    return self;
}

-(AGSCluster *)clusterForGridCoord:(CGPoint)gridCoord atPoint:(AGSPoint *)point{
    AGSCluster *result = self.clusters[@(gridCoord.x)];
    if (!result) {
        result = [AGSCluster clusterForPoint:point];
        result.cellCoordinate = gridCoord;
        result.parentGrid = self.parentGrid;
        [self.clusters setObject:result forKey:@(gridCoord.x)];
    }
    return result;
}

-(void)removeAllClusters {
    [self.clusters removeAllObjects];
}
@end
