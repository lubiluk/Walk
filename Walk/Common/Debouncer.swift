//
//  Debouncer.swift
//  Walk
//
//  Created by Paweł Gajewski on 21/05/2019.
//  Copyright © 2019 Paweł Gajewski. All rights reserved.
//

import Foundation

class Debouncer {
    var queue = DispatchQueue.main
    var delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    deinit {
        workItem?.cancel()
    }
    
    func schedule(block: @escaping () -> Void ) {
        workItem?.cancel()
        
        workItem = DispatchWorkItem(block: block)
        queue.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}
