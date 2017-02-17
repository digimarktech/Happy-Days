//
//  ViewController.swift
//  HappyDays
//
//  Created by Marc Aupont on 7/8/16.
//  Copyright © 2016 Digimark Technical Solutions. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Speech

class ViewController: UIViewController {

    @IBOutlet var helpLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func requestPermission(_ sender: AnyObject) {
        
        requestPhotoPermissions()
    }
    
    func requestPhotoPermissions() {
        
        PHPhotoLibrary.requestAuthorization { [unowned self]  authStatus in
            
            DispatchQueue.main.async(execute: {
                
                if authStatus == .authorized {
                    
                    self.requestRecordPermissions()
                    
                } else {
                    
                    self.helpLabel.text = "Photos permission was declined. Please enable it in settings then tap Continue again."
                }
                
            })
        }
    }
    
    func requestRecordPermissions() {
        
        AVAudioSession.sharedInstance().requestRecordPermission() { [unowned self] allowed in
            
            DispatchQueue.main.async(execute: {
                
                if allowed {
                    
                    self.requestTranscribePermissions()
                    
                } else {
                    
                    self.helpLabel.text = "Recording permission was declined. Please enable it in settings then tap Continue again."
                }
                
            })
            
        }
    }
    
    func requestTranscribePermissions() {
    
        SFSpeechRecognizer.requestAuthorization { [unowned self] authStatus in
            
            DispatchQueue.main.async(execute: {
                
                if authStatus == .authorized {
                    
                    self.authorizationComplete()
                    
                } else {
                    
                    self.helpLabel.text = "Transcription permission was declined. Please enable it in settings then tap Continue again."
                }
            })
        }
    
    }
    
    func authorizationComplete() {
        
        dismiss(animated: true)
    }

}

