//
//  isIPad.swift
//  YBVRPlayer
//
//  Created by Isaac Roldan on 02/06/2020.
//  Copyright © 2020 ybvr. All rights reserved.
//

import Foundation
import UIKit

var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}
