//
//  AppDelegate.swift
//  AVAEGamingExample
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/4/20.
//
///*
//    Copyright (C) 2015 Apple Inc. All Rights Reserved.
//    See LICENSE.txt for this sample’s licensing information
//
//    Abstract:
//    Application Delegate
//*/
//
//@import Cocoa;
import Cocoa
//
//@interface AppDelegate : NSObject <NSApplicationDelegate>
@NSApplicationMain
@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate {
//
//@property (assign) IBOutlet NSWindow *window;
    @IBOutlet weak var window: NSWindow!
//
//@end
//
//#import "AppDelegate.h"
//
//@implementation AppDelegate
//
//- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
//{
    func applicationDidFinishLaunching(aNotification: NSNotification) {
//    // Insert code here to initialize your application
//}
    }
//
//- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    func applicationShouldTerminateAfterLastWindowClosed(theApplication: NSApplication) -> Bool {
//
//    return YES;
        return true
//}
    }
//
//@end
}