//
//  AGSClusterDistanceGrid.m
//  ClusterLayerSample
//
//  Created by Nicholas Furness on 3/24/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import "AGSClusterGrid.h"
#import "AGSCluster.h"
#import "AGSCluster_int.h"
#import "AGSClusterGridRow.h"
#import "Common.h"
#import <objc/runtime.h>

#define kAddFeaturesArrayKey @"__tempArrayKey"

NSString * const AGSClusterGridClusteringNotification = @"AGSClusterGridNotification_StartClustering";
NSString * const AGSClusterGridClusteredNotification = @"AGSClusterGridNotification_EndClustering";

#pragma mark - Helper Methods
CGPoint getGridCoordForMapPoint(AGSPoint* pt, NSUInteger cellSize) {
    return CGPointMake(floor(pt.x/cellSize), floor(pt.y/cellSize));
}

AGSPoint* getGridCellCentroid(CGPoint cellCoord, NSUInteger cellSize) {
    return [AGSPoint pointWithX:(cellCoord.x * cellSize) + (cellSize/2)
                              y:cellCoord.y * cellSize + (cellSize/2)
               spatialReference:[AGSSpatialReference webMercatorSpatialReference]];
}

#pragma mark - Cluster Grid
@interface AGSClusterGrid()
@property (nonatomic, assign, readwrite) NSUInteger cellSize;
@property (nonatomic, strong) NSMutableDictionary *rows;
@property (nonatomic, strong, readwrite) NSMutableArray *items;
@property (nonatomic, weak) AGSClusterLayer *owningClusterLayer;
@end

@implementation AGSClusterGrid
-(id)initWithCellSize:(NSUInteger)cellSize forClusterLayer:(AGSClusterLayer *)clusterLayer {
    self = [self init];
    if (self) {
        self.cellSize = cellSize;
        self.rows = [NSMutableDictionary dictionary];
        self.items = [NSMutableArray array];
        self.owningClusterLayer = clusterLayer;
    }
    return self;
}

-(void)addItems:(NSArray *)items {
    [self.items addObjectsFromArray:items];

    [self clusterItems];
    [self.gridForPrevZoomLevel addItems:self.clusters];
}

-(void)removeAllItems {
    for (AGSClusterGridRow *row in [self.rows objectEnumerator]) {
        for (AGSCluster *cluster in [row.clusters objectEnumerator]) {
            [cluster clearItems];
        }
        [row removeAllClusters];
    }
    [self removeAllRows];
}

-(void)clusterItems {
    [[NSNotificationCenter defaultCenter] postNotificationName:AGSClusterGridClusteringNotification object:self];
    NSDate *startTime = [NSDate date];

    NSArray *items = self.items;
    // NSLog(@"Adding %d features/clusters to zoom level %@", items.count, self.zoomLevel);

    // Add each item to the clusters (creating new ones if necessary).
    NSMutableSet *clustersForItems = [NSMutableSet set];
    for (AGSClusterItem *item in items) {
        // Find out what cluster this item should belong to.
        AGSCluster *cluster = [self clusterForItem:item];
        
        // And track this item in an array associated with this cluster.
        NSMutableArray *itemsToAddToCluster = objc_getAssociatedObject(cluster, kAddFeaturesArrayKey);
        if (!itemsToAddToCluster) {
            itemsToAddToCluster = [NSMutableArray array];
            objc_setAssociatedObject(cluster, kAddFeaturesArrayKey, itemsToAddToCluster, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [itemsToAddToCluster addObject:item];
        
        // Also track the clusters we've touched with these items.
        [clustersForItems addObject:cluster];
    }
    
    // Now go over the clusters we've touched
    // And bulk add items to each individual cluster.
    NSUInteger featureCount = 0;
    for (AGSCluster *cluster in clustersForItems) {
        NSArray *itemsToAdd = objc_getAssociatedObject(cluster, kAddFeaturesArrayKey);
        [cluster addItems:itemsToAdd];
        featureCount += cluster.displayCount;
        // Remove the temporary reference to the array that tracked the items to add to this cluster
        objc_setAssociatedObject(cluster, kAddFeaturesArrayKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }
    
    NSTimeInterval clusteringDuration = -[startTime timeIntervalSinceNow];
    [[NSNotificationCenter defaultCenter] postNotificationName:AGSClusterGridClusteredNotification object:self
                                                      userInfo:@{
                                                                 @"itemsClustered": @(featureCount),
                                                                 @"clusters": @(self.clusters.count),
                                                                 @"duration": @(clusteringDuration),
                                                                 @"zoomLevel": self.zoomLevel
                                                                 }];
    
    // NSLog(@"%2d [%4d items in %4d clusters sized %7d] in %.4fs", self.zoomLevel.unsignedIntegerValue, self.items.count, self.clusters.count, self.cellSize, clusteringDuration);
}

-(AGSCluster *)clusterForItem:(AGSClusterItem *)item {
    AGSPoint *pt = (AGSPoint *)item.geometry;
    NSAssert(pt != nil, @"Graphic Geometry is NIL!");
    
    // What cell (cluster) should this graphic go into?
    CGPoint gridCoord = getGridCoordForMapPoint(pt, self.cellSize);
    
    // Return the cluster
    return [self clusterForGridCoord:gridCoord atPoint:pt];
}

-(AGSCluster *)clusterForGridCoord:(CGPoint)gridCoord atPoint:(AGSPoint *)point {
    // Find the cells along that row.
    AGSClusterGridRow *row = [self rowForGridCoord:gridCoord];
    return [row clusterForGridCoord:gridCoord atPoint:point];
}

-(AGSClusterGridRow *)rowForGridCoord:(CGPoint)gridCoord {
    AGSClusterGridRow *row = self.rows[@(gridCoord.y)];
    if (!row) {
        row = [AGSClusterGridRow clusterGridRowForClusterGrid:self];
        [self.rows setObject:row forKey:@(gridCoord.y)];
    }
    return row;
}

-(AGSPoint *)cellCentroid:(CGPoint)cellCoord {
    return getGridCellCentroid(cellCoord, self.cellSize);
}

-(NSArray *)clusters {
    NSMutableArray *clusters = [NSMutableArray array];
    for (AGSClusterGridRow *row in [self.rows objectEnumerator]) {
        for (AGSCluster *cluster in [row.clusters objectEnumerator]) {
            [clusters addObject:cluster];
        }
    }
    return [NSArray arrayWithArray:clusters];
}

-(void)removeAllRows {
    [self.rows removeAllObjects];
}

-(NSString *)description {
    NSUInteger clusterCount = 0;
    NSUInteger featureCount = 0;
    NSUInteger loneFeatures = 0;
    for (AGSCluster *cluster in self.clusters) {
        if (cluster.features.count > 1) {
            clusterCount++;
        } else {
            loneFeatures++;
        }
        featureCount += cluster.features.count;
    }
    return [NSString stringWithFormat:@"Cluster Grid: %d features in %d clusters (with %d unclustered)", featureCount, clusterCount, loneFeatures];
}
@end
