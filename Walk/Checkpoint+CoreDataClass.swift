//
//  Checkpoint+CoreDataClass.swift
//  Walk
//
//  Created by Paweł Gajewski on 20/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Checkpoint)
public class Checkpoint: NSManagedObject {
    static let entityName = "Checkpoint"
    
    class func insertIntoContext(_ managedObjectContext: NSManagedObjectContext) -> Checkpoint {
        return NSEntityDescription.insertNewObject(forEntityName: Checkpoint.entityName, into: managedObjectContext) as! Checkpoint
    }
    
    class func deleteAllFromContext(_ managedObjectContext: NSManagedObjectContext) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Checkpoint.entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        try managedObjectContext.execute(deleteRequest)
    }
}
