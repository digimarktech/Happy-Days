//
//  MemoriesViewController.swift
//  HappyDays
//
//  Created by Marc Aupont on 7/8/16.
//  Copyright © 2016 Digimark Technical Solutions. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import Speech
import CoreSpotlight
import MobileCoreServices

class MemoriesViewController: UICollectionViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVAudioRecorderDelegate {
    
    var memories = [URL]()
    
    var activeMemory: URL!
    
    var audioRecorder: AVAudioRecorder?
    
    var recordingURL: URL!
    
    var audioPlayer: AVAudioPlayer?
    
    var filteredMemories = [URL]()
    
    var searchQuery: CSSearchQuery?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        recordingURL = try?
            
            getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(cameraTapped))
        
        loadMemories()

    }
    
    func cameraTapped() {
        
        //create view controller that handles selecting photos
        let vc = UIImagePickerController()
        vc.modalPresentationStyle = .formSheet
        vc.delegate = self
        
        navigationController?.present(vc, animated: true, completion: nil)
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        
        dismiss(animated: true, completion: nil)
        
        if let possibleImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            saveNewMemory(image: possibleImage)
            loadMemories()
        }
    }
    
    func saveNewMemory(image: UIImage) {
        
        //create a unique name for this memory
        
        let memoryName = "memory-\(Date().timeIntervalSince1970)"
        
        //use the unique anme to create filenames for the full-size image and the thumbnail
        
        let imageName = memoryName + ".jpg"
        
        let thumbnailName = memoryName + ".thumb"
        
        do {
            
            //create a URL where we can write the JPEG
            
            let imagePath = try
            
            getDocumentsDirectory().appendingPathComponent(imageName)
            
            //convert the UIImage into a JPEG data object
            
            if let jpegData = UIImageJPEGRepresentation(image, 80) {
                
                try jpegData.write(to: imagePath, options: [.atomic])
            }
            
            //create thumbnail here
            
            if let thumbnail = resizeImage(image: image, to: 200) {
                
                let imagePath = try
                
                getDocumentsDirectory().appendingPathComponent(thumbnailName)
                
                if let jpegData = UIImageJPEGRepresentation(thumbnail, 80) {
                    
                    try jpegData.write(to: imagePath, options: [.atomic])
                }
            }
            
        } catch {
            
            print("Failed to save to disk.")
        }
    }
    
    func resizeImage(image: UIImage, to width: CGFloat) -> UIImage? {
        
        //calculate how much we need to bring the width down to match our target size
        
        let scale = width / image.size.width
        
        //bring the height down by the same amount so that the aspect ratio is preserved
        
        let height = image.size.height * scale
        
        //create a new image context we can draw into
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        
        //draw the original image into the context
        
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        
        //pull out the resized version
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        //end the context so UIKit can clean up
        
        UIGraphicsEndImageContext()
        
        //send it back to the caller
        
        return newImage
        
    }
    
    func checkPermissions() {
        
        let photoAuthorized = PHPhotoLibrary.authorizationStatus() == .authorized
        let recordingAuthorized = AVAudioSession.sharedInstance().recordPermission() == .granted
        let transcribeAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
        
        //make a single boolen out of all three
        
        let authorized = photoAuthorized && recordingAuthorized && transcribeAuthorized
        
        if !authorized {
            
            if let vc = storyboard?.instantiateViewController(withIdentifier: "FirstRun") {
                
                navigationController?.present(vc, animated: true)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        checkPermissions()
        
    }
    
    func getDocumentsDirectory() -> URL {
        
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        
        return documentsDirectory
    }
    
    func loadMemories() {
        
        memories.removeAll()
        
        guard let files = try?
            FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil, options: [])
            
        else {
            
            return
        }
        
        for file in files {
            
            let filename = file.lastPathComponent
            
            if filename.hasSuffix("thumb") {
                
                let noExtension = filename.replacingOccurrences(of: ".thumb", with: "")
                
                if let memoryPath = try?
                
                    getDocumentsDirectory().appendingPathComponent(noExtension) {
                    
                    memories.append(memoryPath)
                }
                
            }
        }
        
        filteredMemories = memories
        
        collectionView?.reloadSections(IndexSet(integer: 1))
        
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filterMemories(text: searchText)
    }
    
    func filterMemories(text: String) {
        
        guard text.characters.count > 0 else {
            
            filteredMemories = memories
            
            UIView.performWithoutAnimation({
                
                collectionView?.reloadSections(IndexSet (integer: 1))
            })
            
            return
        }
        
        var allItems = [CSSearchableItem]()
        
        searchQuery?.cancel()
        
        let queryString = "contentDescription == \"*\(text)*\"c"
        searchQuery = CSSearchQuery(queryString: queryString, attributes: nil)
        
        searchQuery?.foundItemsHandler = { items in
            
            allItems.append(contentsOf: items)
    }
        
        searchQuery?.completionHandler = { error in
            
            DispatchQueue.main.async(execute: { [unowned self] in
                
                self.activateFilter(matches: allItems)
            })
            
        }
        
        searchQuery?.start()
        
    }
    
    func activateFilter(matches: [CSSearchableItem]) {
        
        filteredMemories = matches.map { item in
            
            return URL(fileURLWithPath: item.uniqueIdentifier)
        }
        
        UIView.performWithoutAnimation { 
            
            collectionView?.reloadSections(IndexSet (integer: 1))
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        searchBar.resignFirstResponder()
    }
    
    func imageURL(for memory: URL) -> URL {
        
        return try! memory.appendingPathExtension("jpg")
    }
    
    func thumbnailURL(for memory: URL) -> URL {
        
        return try! memory.appendingPathExtension("thumb")
    }
    
    func audioURL(for memory: URL) -> URL {
        
        return try! memory.appendingPathExtension("m4a")
    }
    
    func transcriptionURL(for memory: URL) -> URL {
        
        return try! memory.appendingPathExtension("txt")
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 2
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if section == 0 {
            
            return 0
            
        } else {
            
        }
        
        return filteredMemories.count
        
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Memory", for: indexPath) as! MemoriesCell
        
        let memory = filteredMemories[indexPath.row]
        let imageName = thumbnailURL(for: memory).path ?? ""
        let image = UIImage(contentsOfFile: imageName)
        
        cell.imageView.image = image
        
        if cell.gestureRecognizers == nil {
            
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(memoryLongPress))
            
            recognizer.minimumPressDuration = 0.25
            
            cell.addGestureRecognizer(recognizer)
            
            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = 3
            cell.layer.cornerRadius = 10
            
        }
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let memory = filteredMemories[indexPath.row]
        
        let fm = FileManager.default
        
        do {
            
            let audioName = audioURL(for: memory)
            let transcriptionName = transcriptionURL(for: memory)
            
            if fm.fileExists(atPath: audioName.path) {
                
                audioPlayer = try AVAudioPlayer(contentsOf: audioName)
                
                audioPlayer?.play()
            }
            
            if fm.fileExists(atPath: transcriptionName.path) {
                
                let contents = try String(contentsOf: transcriptionName)
                    
                    print(contents)
                }
                
            } catch {
                
                print("Error loading Audio")
            }
        
    }
    
    func memoryLongPress(sender: UILongPressGestureRecognizer) {
        
        if sender.state == .began {
            
            let cell = sender.view as! MemoriesCell
            
            if let index = collectionView?.indexPath(for: cell) {
                
                activeMemory = filteredMemories[index.row]
                recordMemory()
            }
            
        } else if sender.state == .ended {
            
            finishRecording(success: true)
        }
    }
    
    func recordMemory() {
        
        audioPlayer?.stop()
        
        //1. The easy bit
        
        collectionView?.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        
        //this just saves us from writing AvAudioSession.sharedInstance() everywhere
        
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            
            //2. configure the session for recording and playback through the speaker
            
            try
            recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
            
            try recordingSession.setActive(true)
            
            //3. setup a high-quality recording session 
            
            let settings = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 4400, AVNumberOfChannelsKey: 2, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            
            //4. create the audio recording , and assign ourselves at the delegate.
            
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
        } catch let error {
            
            //Failed to record
            
            print("Failed to record: \(error)")
            
            finishRecording(success: false)
            
        }
    }
    
    func finishRecording(success: Bool) {
        
        //1. Set background of collection view back to grey
        collectionView?.backgroundColor = UIColor.darkGray
        
        //2. Stop the audoio recording
        
        audioRecorder?.stop()
        
        if success {
            
            do {
                
                let memoryAudioURL = try
                activeMemory.appendingPathExtension("m4a")
                let fm = FileManager.default
                
                if fm.fileExists(atPath: memoryAudioURL.path) {
                    
                    try fm.removeItem(at: memoryAudioURL)
                }
                
                try fm.moveItem(at: recordingURL, to: memoryAudioURL)
                
                transcribeAudio(memory: activeMemory)
                
            } catch let error {
                
                
            }
        }
    }
    
    func transcribeAudio(memory: URL) {
        
        //get paths to where the audio is, and where the transcription should be
        
        let audio = audioURL(for: memory)
        
        let transcription = transcriptionURL(for: memory)
        
        //create a new recognizer and point it at our audio
        
        let recognizer = SFSpeechRecognizer()
        
        let request = SFSpeechURLRecognitionRequest(url: audio)
        
        //start recognition
        
        recognizer?.recognitionTask(with: request) { [unowned self] (result,error) in
        
            //abort if we didnt get any transcription back
            
            guard let result = result else {
                
                print("There was an error \(error!)")
                
                return
            }
            
            //if we got the final transcription back, we need to write it to disk
            
            if result.isFinal {
                
                //pull out the best transcription...
                
                let text = result.bestTranscription.formattedString
                
                //...and write it to disk at the correct filename for this memory,
                
                do {
                    
                    try text.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
                    
                    self.indexMemory(memory: memory, text: text)
                    
                } catch {
                    
                    print("Failed to save transcription")
                }
            }
        }
    }
    
    func indexMemory(memory:URL, text: String) {
        
        //create a basic attribute set
        
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        
        attributeSet.title = "Happy Days Memory"
        attributeSet.contentDescription = text
        
        attributeSet.thumbnailURL = thumbnailURL(for: memory)
        
        //wrap it in a searchable item, using the memory's full path as its unique identifier
        
        let item = CSSearchableItem(uniqueIdentifier: memory.path, domainIdentifier: "com.digimarktech", attributeSet: attributeSet)
        
        //make it never expire
        
        item.expirationDate = Date.distantFuture
        
        //ask Spotlight to index the item
        
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            
            if let error = error {
                
                print("Indexing error: \(error.localizedDescription)")
                
            } else {
                
                print("Search item successfully indexed \(text)")
            }
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        
        if !flag {
            
            finishRecording(success: false)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        if section == 1 {
            
            return CGSize.zero
            
        } else {
            
            return CGSize(width: 0, height: 50)
        }
    }

}
