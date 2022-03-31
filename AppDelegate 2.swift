//
//  AppDelegate.swift
//  DriveProPlayer
//
//  Created by HahaSU on 2020/3/31.
//  Copyright © 2020 Transcend. All rights reserved.
//

import UIKit
import Alamofire

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        DispatchQueue.main.async{
            SocketManager.shared.disconnect()
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        makeSocketConnection()
    }
    
    func makeSocketConnection() {
        let parameter: [String: Any] = ["cmd": "7001"]
        Alamofire.request("http://192.168.1.254/?custom=1",
                          method: .get,
                          parameters: parameter,
                          encoding: URLEncoding.default,
                          headers: nil)
        .response(completionHandler: { (defaultDataResponse) in
            if let data = defaultDataResponse.data {
                let dict = XMLHandler.shared.parse(data: data)
                guard let status = dict["Status"] as? String,
                    status == "0", let model = dict["ModelName"] as? String else {
                        return
                }
                SocketManager.shared.model = model
                if !SocketManager.shared.connected {
                    SocketManager.shared.connect()
                }
            }
        })
    }
}

