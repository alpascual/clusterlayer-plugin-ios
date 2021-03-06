//
//  AGSGraphic+AGSClustering.h
//  Cluster Layer
//
//  Created by Nicholas Furness on 3/28/14.
//  Copyright (c) 2014 ESRI. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
@class AGSCluster;

@interface AGSGraphic (AGSClustering)

//Determines whether the graphic is a cluster
@property (nonatomic, readonly) BOOL isCluster;
@property (nonatomic, readonly) BOOL isClusterCoverage;
@property (nonatomic, readonly) AGSCluster *owningCluster;

-(id)clusterItemKey;
@end
