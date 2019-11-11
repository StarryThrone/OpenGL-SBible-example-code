//
//  AppDelegate.swift
//  PhongLighting
//
//  Created by chenjie on 2019/11/8.
//  Copyright © 2019 chenjie. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var mainWindow: NSWindow?
    var mainViewController: MainViewController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let screenFrame = NSScreen.main!.frame
        let windowRect = NSRect(x: 0, y: screenFrame.size.width / 2, width: screenFrame.size.width / 2, height: screenFrame.size.height / 2)
        let style: NSWindow.StyleMask = [NSWindow.StyleMask.titled, NSWindow.StyleMask.closable, NSWindow.StyleMask.miniaturizable, NSWindow.StyleMask.resizable]
        self.mainWindow = NSWindow(contentRect: windowRect, styleMask: style, backing: .buffered, defer: false)
        self.mainWindow?.title = "PhongLighting"
        self.mainWindow?.makeKeyAndOrderFront(nil)
        
        self.mainViewController = MainViewController()
        self.mainWindow?.contentViewController = self.mainViewController
    }
}

