//
//  MainViewController.swift
//  FindRabbit
//
//  Created by chenjie on 2019/12/30.
//  Copyright © 2019 chenjie. All rights reserved.
//

import AppKit
import GLKit
import Accelerate

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
        
    private func monitorKeyboardEvent() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in
            if event.characters == "P" {
                self.paused = !self.paused
            } else if event.characters == "+" {
                self.glProfileVeiw.renderDuration += 0.1
            } else if event.characters == "-" {
                self.glProfileVeiw.renderDuration -= 0.1
            } else if event.characters == "w" {
                self.forward()
            } else if event.characters == "s" {
                self.backward()
            } else if event.characters == "a" {
                self.turnLeft()
            } else if event.characters == "d" {
                self.turnRight()
            } else if event.characters == "8" {
                self.lookup()
            } else if event.characters == "2" {
                self.lookdown()
            }
            return event
        }
    }
    
    //MARK: Event Responding Methods
    private func forward() {
        let currentLocation = simd_float2(x: Float(self.glProfileVeiw.location.x), y: Float(self.glProfileVeiw.location.y))
        let walkingDirection = simd_float2(x: self.glProfileVeiw.viewDirection.x, y: self.glProfileVeiw.viewDirection.z)
        var destinationLocation = currentLocation + walkingDirection * 0.1
        destinationLocation = clamp(destinationLocation, min: -64, max: 64)
        self.glProfileVeiw.location = CGPoint(x: CGFloat(destinationLocation.x), y: CGFloat(destinationLocation.y))
    }
    
    private func backward() {
        let currentLocation = simd_float2(x: Float(self.glProfileVeiw.location.x), y: Float(self.glProfileVeiw.location.y))
        let walkingDirection = simd_float2(x: self.glProfileVeiw.viewDirection.x, y: self.glProfileVeiw.viewDirection.z)
        var destinationLocation = currentLocation - walkingDirection * 0.1
        destinationLocation = clamp(destinationLocation, min: -64, max: 64)
        self.glProfileVeiw.location = CGPoint(x: CGFloat(destinationLocation.x), y: CGFloat(destinationLocation.y))
    }
    
    private func turnLeft() {
        var destinationCourse = self.glProfileVeiw.course - 1
        if destinationCourse < 0 {
            destinationCourse += 360
        }
        self.glProfileVeiw.course = destinationCourse
        self.updateViewDirection()
    }
    
    private func turnRight() {
        var destinationCourse = self.glProfileVeiw.course + 1
        if destinationCourse >= 360 {
            destinationCourse -= 360
        }
        self.glProfileVeiw.course = destinationCourse
        self.updateViewDirection()
    }
    
    private func lookup() {
        var destinationAngle = self.glProfileVeiw.verticalViewAngle + 1
        destinationAngle = min(destinationAngle, 90)
        self.glProfileVeiw.verticalViewAngle = destinationAngle
        self.updateViewDirection()
    }
    
    private func lookdown() {
        var destinationAngle = self.glProfileVeiw.verticalViewAngle - 1
        destinationAngle = max(destinationAngle, 0)
        self.glProfileVeiw.verticalViewAngle = destinationAngle
        self.updateViewDirection()
    }
    
    private func updateViewDirection() {
        var viewDirection = simd_float3(x: sinf(GLKMathDegreesToRadians(Float(self.glProfileVeiw.course))),
                                        y: sinf(GLKMathDegreesToRadians(Float(self.glProfileVeiw.verticalViewAngle))),
                                        z: -cosf(GLKMathDegreesToRadians(Float(self.glProfileVeiw.course))))
        viewDirection = simd_normalize(viewDirection)
        self.glProfileVeiw.viewDirection = viewDirection
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
