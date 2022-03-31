//
//  DriveProVideoViewController.swift
//  DriveProNew
//
//  Created by Rock Lee on 2018/3/16.
//  Copyright © 2018年 Wei Chieh. All rights reserved.
//

import UIKit
import TsBrowser
import TsDrawer
import AVFoundation
import AVKit
import Alamofire

protocol DriveProVideoBrowserViewDelegate{
    
    func updateVideoFileList(index: Int)
}

class DriveProVideoViewController: VideoViewController {
    
    var filePath: [String] = []
    
    var currentIndex: Int = 0
    
    var videoPlayerViewController = AVPlayerViewController()
    
    lazy var indicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        view.layer.cornerRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    
    fileprivate var vlcPlayer: VLCMediaPlayer?
    
    lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: ImageLoader("ic_clear_36pt").image, style: .plain, target: self, action: #selector(cancelButtonDidTap))
        return button
    }()
    
    func showLoader(show: Bool){
        DispatchQueue.main.async {
            if show {
                self.playingStatus = .buffering
                self.view.addSubview(self.indicatorView)
                self.indicatorView.widthAnchor.constraint(equalToConstant: 50).isActive = true
                self.indicatorView.heightAnchor.constraint(equalToConstant: 50).isActive = true
                self.indicatorView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
                self.indicatorView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
                self.indicatorView.startAnimating()
            } else {
                self.indicatorView.stopAnimating()
                self.indicatorView.removeFromSuperview()
                if self.vlcPlayer?.isPlaying ?? false {
                    self.playingStatus = .playing
                } else {
                    self.playingStatus = .pause
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let navigation = navigationController as? DrawerNavigationController {
            navigation.isDrawerEnable = false
        }
        
        setupNavigationBarItems()
        delegate = self
        isUseSingleView = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        preparePlayback()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.vlcPlayer?.play()
        self.playingStatus = .playing
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        UIApplication.shared.isIdleTimerDisabled = false
        
        super.viewWillDisappear(animated)
        
        if vlcPlayer?.isPlaying ?? false {
            vlcPlayer?.stop()
            vlcPlayer?.delegate = nil
        }
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            let value = NSNumber(value: UIInterfaceOrientation.portrait.rawValue)
            UIDevice.current.setValue(value, forKey: "orientation")
        }
    }
    
    func setupNavigationBarItems() {
        navigationItem.leftBarButtonItems = [cancelButton]
    }
    
    @objc private func cancelButtonDidTap() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func preparePlayback(callingMethod: String = #function){
        
        let nTempVideoPath = "http://192.168.1.254/" + SocketManager.shared.model + "/TEMP/" + filePath[currentIndex]
        let media = VLCMedia(url: URL(string: nTempVideoPath)!)
        let dic = ["network-caching":"300"]
        media.addOptions(dic)
        vlcPlayer = VLCMediaPlayer()
        vlcPlayer?.delegate = self
        vlcPlayer?.media = media
        vlcPlayer?.drawable = self.mediaView
        
        if let length = vlcPlayer?.media.length.intValue {
            let totalTime = Int(length / 1000)
            timeInfo = TimeInfo(time: getDurationInText(time: CMTimeMake(Int64(0), Int32(1.0))), duration: getDurationInText(time:CMTimeMake(Int64(totalTime), Int32(1.0)) ), position: 0.0)
        }
    }
    
    func getDurationInText(time:CMTime)->String{
        let totalSeconds = CMTimeGetSeconds(time)
        if totalSeconds.isNaN {
            return ""
        }
        let hours:Int = Int(totalSeconds / 3600)
        let minutes:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 3600)/60)//Int(totalSeconds % 3600 / 60)
        let seconds:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    func VLCPlayerItemDidReachEnd(){
        vlcPlayer?.stop()
        vlcPlayer?.delegate = self
        playingStatus = .pause
        preparePlayback()
    }
}

extension DriveProVideoViewController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filePath.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoCell.identifier, for: indexPath) as! VideoCell
        
        return cell
    }
}

extension DriveProVideoViewController: VideoDelegate {
    
    func onScrollSeekbarOnVideoView(position: Float, touchStatus: TouchStatus) {
        guard let playerTime = self.vlcPlayer?.media.length.value else {
            return
        }
        let time = NSNumber(value: playerTime.floatValue * position)
        
        if touchStatus == .began {
            print("scroll seekbar begin")
        } else if touchStatus == .ended {
            print("scroll seekbar ended")
            vlcPlayer?.time = VLCTime(number: time)
        }
        
        if let vlcTime = VLCTime(number: time), let min = vlcTime.stringValue.components(separatedBy: ":").first, let sec = vlcTime.stringValue.components(separatedBy: ":").last, let minInt = Int(min), let secInt = Int(sec) {
            
            let time = minInt * 60 + secInt//Float()
            let totalTime = Int(((self.vlcPlayer?.media.length.intValue ?? 0) / 1000))
            
            DispatchQueue.main.async {
                self.timeInfo = TimeInfo(time: self.getDurationInText(time: CMTimeMake(Int64(time), Int32(1.0))), duration: self.getDurationInText(time:CMTimeMake(Int64(totalTime), Int32(1.0)) ), position: Float(Float(time)/Float(totalTime)))
            }
        }
    }
    
    func onPressPreviousButtonOnVideoView(){
        currentIndex += 1
        
        if currentIndex != filePath.count{
            
            vlcPlayer?.stop()
            vlcPlayer?.delegate = nil
            playingStatus = .pause
            
            self.SetVideoButtonEnable(value: false)
            
            self.preparePlayback()
            
            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                self.vlcPlayer?.play()
            })
        } else {
            currentIndex -= 1
        }
    }
    
    //Press previous button
    func onPressNextButtonOnVideoView(){
        currentIndex -= 1
        
        if currentIndex >= 0 {
            vlcPlayer?.stop()
            vlcPlayer?.delegate = nil
            playingStatus = .pause
            
            self.SetVideoButtonEnable(value: false)
            
            self.preparePlayback()
            
            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                self.vlcPlayer?.play()
            })
        } else {
            currentIndex += 1
        }
    }
    
    func onPressPlayButtonOnVideoView() {
        DispatchQueue.main.async {
            if self.vlcPlayer?.isPlaying ?? false {
                self.playingStatus = .pause
                self.vlcPlayer?.pause()
            } else {
                self.playingStatus = .playing
                self.vlcPlayer?.play()
            }
        }
    }
    
}

extension DriveProVideoViewController: VLCMediaPlayerDelegate {
    
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        guard let state = vlcPlayer?.state else {
            return
        }
        
        DispatchQueue.main.async {
            switch state {
            case .stopped:
                self.playingStatus = .pause
                self.dismiss(animated: true, completion: nil)
                print("[\(#function)] State: Stop")
                
            case .opening:
                self.playingStatus = .playing
                
            case .buffering:
                print("[\(#function)] State: buffering")
                
                self.SetVideoButtonEnable(value: true)
                self.showLoader(show: true)
                self.playingStatus = .buffering
                
            case .ended:
                print("[\(#function)] State: ended")
                self.showLoader(show: false)
                self.playingStatus = .pause
                
            case .error:
                print("[\(#function)] State: error")
                self.showLoader(show: false)
                self.playingStatus = .pause
                
            case .playing:
                print("[\(#function)] State: playing")
                self.showLoader(show: false)
                self.playingStatus = .playing
                
            case .paused:
                print("[\(#function)] State: paused")
                self.showLoader(show: false)
                self.playingStatus = .pause
                
            default:
                break
            }
        }
    }
    
    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        if let vlcTime = vlcPlayer?.time, let min = vlcTime.stringValue.components(separatedBy: ":").first, let sec = vlcTime.stringValue.components(separatedBy: ":").last, let minInt = Int(min), let secInt = Int(sec) {
            print("VLC Played Time:\(vlcTime)")
        
            self.showLoader(show: false)
            self.playingStatus = .playing
            
            self.SetVideoButtonEnable(value: true)
            
            let time = minInt * 60 + secInt//Float()
            
            let totalTime = Int(((self.vlcPlayer?.media.length.intValue ?? 0) / 1000))
            
            if time != totalTime {

                if totalTime != 0 {
                    DispatchQueue.main.async {
                        self.timeInfo = TimeInfo(time: self.getDurationInText(time: CMTimeMake(Int64(time), Int32(1.0))), duration: self.getDurationInText(time:CMTimeMake(Int64(totalTime), Int32(1.0)) ), position: Float(Float(time)/Float(totalTime)))
                    }
                }
            } else {
                // reach end
                self.VLCPlayerItemDidReachEnd()
            }
        } else {
            print("time lost: \(String(describing: aNotification.object)), \(String(describing: vlcPlayer?.time))")
        }
    }
}
