/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit

struct PhotoManagerNotification {
  // Notification when new photo instances are added
  static let contentAdded = Notification.Name("com.raywenderlich.GooglyPuff.PhotoManagerContentAdded")
  // Notification when content updates (i.e. Download finishes)
  static let contentUpdated = Notification.Name("com.raywenderlich.GooglyPuff.PhotoManagerContentUpdated")
}

struct PhotoURLString {
  // Photo Credit: Devin Begley, http://www.devinbegley.com/
  static let overlyAttachedGirlfriend = "https://i.imgur.com/UvqEgCv.png"
  static let successKid = "https://i.imgur.com/dZ5wRtb.png"
  static let lotsOfFaces = "https://i.imgur.com/tPzTg7A.jpg"
}

typealias PhotoProcessingProgressClosure = (_ completionPercentage: CGFloat) -> Void
typealias BatchPhotoDownloadingCompletionClosure = (_ error: NSError?) -> Void

final class PhotoManager {
  private init() {}                         // how you initialize a singleton
  static let shared = PhotoManager()
    
    
  private let concurrentPhotoQueue =
    DispatchQueue(
        label: "com.raywenderlich.GooglyPuff.photoQueue",
        attributes: .concurrent)
  // ^^^ this initializes concurrentPhotoQueue as a concurrent queue. the lable is a descriptive name that is helpful during debugging
    
    
  private var unsafePhotos: [Photo] = []
  
    var photos: [Photo] {
        var photosCopy: [Photo]!
        
        // 1
        concurrentPhotoQueue.sync {
            
            // 2
            photosCopy = self.unsafePhotos
        }
        return photosCopy
    }
    /*
     
     1) dipatch synchronously on the concurrentPhotoQueue to perform the read
     2) store a copy of the photos array in the photosCopy and return it
     
    */
    
    
  
  func addPhoto(_ photo: Photo) {
//    unsafePhotos.append(photo)              // this is a write method because it modifies a mutable array
//    DispatchQueue.main.async { [weak self] in
//      self?.postContentAddedNotification()
//    }
    
    concurrentPhotoQueue.async(flags: .barrier) { [weak self] in
        // 1
        guard let self = self else {
            return
        }
        
        // 2
        self.unsafePhotos.append(photo)
        
        // 3
        DispatchQueue.main.async { [weak self] in
            self?.postContentAddedNotification()
        }
        
        /*
         1) dispatch the write operation asynchronously with a barrier.
         2) add the object to the array
         3) post a notification that you've added a photo.
        */
    }
  }
  
  func downloadPhotos(withCompletion completion: BatchPhotoDownloadingCompletionClosure?) {
//    var storedError: NSError?
//    for address in [PhotoURLString.overlyAttachedGirlfriend,
//                    PhotoURLString.successKid,
//                    PhotoURLString.lotsOfFaces] {
//                      let url = URL(string: address)
//                      let photo = DownloadPhoto(url: url!) { _, error in
//                        if error != nil {
//                          storedError = error
//                        }
//                      }
//                      PhotoManager.shared.addPhoto(photo)
//    }
//
//    completion?(storedError)    // we incorrectly assume this methods happens when all the photos are finished              downloading. wrong.
    // what we want is for the downloadPhotos(withCompletion:) to call its completion closure after all photos have been downloaded.
    
    // 1
    DispatchQueue.global(qos: .userInitiated).async {
        var storedError: NSError?
        
        // 2
        let downloadGroup = DispatchGroup()
        for address in [PhotoURLString.overlyAttachedGirlfriend,
                        PhotoURLString.lotsOfFaces,
                        PhotoURLString.successKid] {
            let url = URL(string: address)
            
            // 3
            downloadGroup.enter()
                            let photo = DownloadPhoto(url: url!) {_, error in
                                if error != nil {
                                    storedError = error
                                }
                                // 4
                                downloadGroup.leave()
                            }
            PhotoManager.shared.addPhoto(photo)
        }
        
        // 5
        downloadGroup.wait()
        
        // 6
        DispatchQueue.main.async {
            completion?(storedError)
        }
        /*
         
         1) we're using the synchronous wait method which blocks the current thread, you use async to place the entire method into a background queue to ensure you dont block the main queue.
         2) create a new dispatch group
         3) call enter() to notify the group that a task has started. must balance the number of enter() with leave()
         4) notify the group that the work is done
         5) call wait to block the current thread while waiting for tasks completion
         6) it is guaranteed that all the photos have either completed or timed out. you then create a call back to the main queue to run the completion closure
         
        */
    }
    
    
    
  }
  
  private func postContentAddedNotification() {
    NotificationCenter.default.post(name: PhotoManagerNotification.contentAdded, object: nil)
  }
}
