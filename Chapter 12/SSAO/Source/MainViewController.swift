//
//  MainViewController.swift
//  SSAO
//
//  Created by chenjie on 2019/12/6.
//  Copyright © 2019 chenjie. All rights reserved.
//

import AppKit

class MainViewController: NSViewController {
    //MARK:- Private Properties
    private var glProfileVeiw: GLCoreProfileView!
    
    private var lifeTimer: Timer!
    // 程序运行的时间
    private var lifeDuration: TimeInterval = 0
    // 除去暂停后实际渲染的时间
    private var paused = false
    
    //MARK:- Life Cycle Methods
    override func loadView() {
        let screenFrame = NSScreen.main!.frame
        let windowFrame = NSRect(x: 0, y: screenFrame.size.width / 2, width: screenFrame.size.width / 2, height: screenFrame.size.height / 2)
        self.view = NSView(frame: windowFrame)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.prepareGLProfileView()
        self.lifeTimer = Timer.scheduledTimer(timeInterval: 1.0/60, target: self, selector: #selector(MainViewController.handleTimerEvent), userInfo: nil, repeats: true)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.monitorKeyboardEvent()
    }
    
    deinit {
        self.lifeTimer?.invalidate()
        self.lifeTimer = nil
    }
    
    //MARK: Private Methods
    private func prepareGLProfileView() {
        let viewFrame = self.view.frame
        let glView = GLCoreProfileView(frame: viewFrame, pixelFormat: nil)!
        glView.translatesAutoresizingMaskIntoConstraints = false
        glView.renderDuration = 0
        self.glProfileVeiw = glView
        self.view.addSubview(glView)
        
        glView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        glView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        glView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        glView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
    }
        
    func monitorKeyboardEvent() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in
            if event.characters == "P" {
                self.paused = !self.paused
            } else if event.characters == "+" {
                self.glProfileVeiw.renderDuration += 0.1
            } else if event.characters == "-" {
                self.glProfileVeiw.renderDuration -= 0.1
            } else if event.characters == "R" {
                self.glProfileVeiw.randomStepLength = !self.glProfileVeiw.randomStepLength
                print("randomStepLength = \(self.glProfileVeiw.randomStepLength)")
            } else if event.characters == "S" {
                self.glProfileVeiw.randomVectorCount += 1
                print("randomVectorCount = \(self.glProfileVeiw.randomVectorCount)")
            } else if event.characters == "X" {
                self.glProfileVeiw.randomVectorCount -= 1
                print("randomVectorCount = \(self.glProfileVeiw.randomVectorCount)")
            } else if event.characters == "Q" {
                self.glProfileVeiw.showShading = !self.glProfileVeiw.showShading
                print("showShading = \(self.glProfileVeiw.showShading)")
            } else if event.characters == "W" {
                self.glProfileVeiw.showAo = !self.glProfileVeiw.showAo
                print("showAo = \(self.glProfileVeiw.showAo)")
            } else if event.characters == "A" {
                self.glProfileVeiw.ssaoRadius += 0.01
                print("ssaoRadius = \(self.glProfileVeiw.ssaoRadius)")
            } else if event.characters == "Z" {
                self.glProfileVeiw.ssaoRadius -= 0.01
                print("ssaoRadius = \(self.glProfileVeiw.ssaoRadius)")
            }
            return event
        }
    }
        
    //MARK:- Event Responding
    @objc private func handleTimerEvent() {
        self.lifeDuration += lifeTimer.timeInterval
        if !self.paused {
            self.glProfileVeiw.renderDuration += lifeTimer.timeInterval
        }
        
        self.glProfileVeiw.draw(self.glProfileVeiw.bounds)
    }
}
