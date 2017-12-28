//
//  PlayerController.swift
//  MusicMatePlayerDemo
//
//  Created by 1100442 on 2017. 10. 18..
//  Copyright © 2017년 sktechx. All rights reserved.
//

import Foundation

import RxSwift
import SwiftyJSON
import MusicMatePlayer

@objc protocol PlayerControllerDelegate: class {
    @objc func controller(_: PlayerController, didChangeMetaData data: String)
    @objc func controller(_: PlayerController, didChangeState state: String)
    @objc func controller(_: PlayerController, didReceivePlayResponse response: String)
    @objc func controller(_: PlayerController, didReceiveLogResponse code: String)
    @objc func controller(_: PlayerController, didRetriveSessionToken token: String)
}

@objc class PlayerController: NSObject {
    @objc static let shared = PlayerController()
    
    // FIXME: Singleton 객체이기 때문에 정확힌 Observer 패턴을 써야 한다.
    @objc weak var delegate: PlayerControllerDelegate?
    
    fileprivate let player: MusicPlayer = MusicMateMusicPlayer()
    fileprivate let disposeBag = DisposeBag()
    
    override private init() {
        super.init()
        
        bindPlayerEvent()
    }
    
    private func bindPlayerEvent() {
        // onState
        player.status
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.delegate?.controller(self, didChangeState: self.state(status: $0))
            })
            .disposed(by: disposeBag)
        
        // onMetadata
        Observable.combineLatest(player.currentTrackIndex, player.currentTime, player.duration) { ($0, $1, $2) }
            .throttle(1, scheduler: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.delegate?.controller(self, didChangeMetaData: self.metadata(index: $0.0, position: $0.1, duration: $0.2))
            })
            .disposed(by: disposeBag)
        
        // onPlayResponse
        player.playResponse
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                let json = "{code:\($0.code),isFree:\($0.isFree),bugsCode:\($0.externalCode)}"
                self.delegate?.controller(self, didReceivePlayResponse: json)
            })
            .disposed(by: disposeBag)
        
        // onTicket
        player.playLogResult
            .subscribe(onNext: { [weak self] in
                guard let `self` = self else { return }
                let json = "{code:\($0)}"
                self.delegate?.controller(self, didReceiveLogResponse: json)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Objc interface

extension PlayerController {
    /// Frontend의 커맨드 처리
    @objc func processCommand(json: String) {
        let message = JSON(parseJSON: json)
        guard let command = Command(rawValue: message["command"].stringValue) else {
            return
        }
        
        let params = message["params"]
        
        switch command {
        case .setPlaylist:
            let playlist = parsePlaylist(json: params["playlist"])
            let index = params["currentIndex"].intValue
            player.set(playlist: playlist, currentIndex: index)
            
        case .play:
            if let index = params["index"].int {
                player.play(at: index)
            } else {
                player.play()
            }
            
        case .next:
            player.next()
            
        case .previous:
            player.prev(force: false)
            
        case .pause:
            player.pause()
            
        case .seek:
            let sec = params["position"].intValue
            player.seek(second: Double(sec))
            
        case .shuffle:
            let on = params["state"].boolValue
            player.shuffleMode = on ? .shuffle : .no
            
        case .repeat:
            let mode = params["state"].intValue
            if mode == 0 {
                player.repeatMode = .no
            } else if mode == 1 {
                player.repeatMode = .repeat
            } else if mode == 2 {
                player.repeatMode = .one
            }
            
        case .setToken:
            player.sessionToken = params["sessionToken"].string
            player.refreshToken = params["refreshToken"].string
            player.deviceId = params["deviceId"].string
            
        case .getToken:
            self.delegate?.controller(self, didRetriveSessionToken: player.sessionToken ?? "")
            
        case .currentMetadata:
            _ = Observable.combineLatest(player.currentTrackIndex, player.currentTime, player.duration) { ($0, $1, $2) }
                .take(1)
                .subscribe(onNext: { [weak self] in
                    guard let `self` = self else { return }
                    self.delegate?.controller(self, didChangeMetaData: self.metadata(index: $0.0, position: $0.1, duration: $0.2))
                })
            
        case .currentState:
            _ = player.status
                .take(1)
                .subscribe(onNext: { [weak self] in
                    guard let `self` = self else { return }
                    self.delegate?.controller(self, didChangeState: self.state(status: $0))
                })
        }
    }
    
    /**
     로그아웃 처리(로그인 관련정보 삭제 및 재생 중지)
     */
    @objc func logout() {
        player.stop()
        player.sessionToken = nil
        player.refreshToken = nil
        player.deviceId = nil
    }
    
    /**
     재생시 데이터네트워크 사용 여부 설정(defalut true)
     - true: 재생허용
     - false: 데이터네트워크를 이용한 재생 불가(이미 캐시된 음원은 재생)
     */
    @objc var allowCellularNetwork: Bool {
        get {
            return player.allowCellularNetwork
        }
        set {
            player.allowCellularNetwork = newValue
        }
    }
}

// MARK: - Webview interface helper

extension PlayerController {
    fileprivate enum Command: String {
        case setPlaylist
        case play
        case next
        case previous
        case pause
        case seek
        case shuffle
        case `repeat`
        case setToken
        
        // request
        case getToken
        case currentMetadata
        case currentState
    }
    
    func parsePlaylist(json: JSON) -> [PlayerTrack] {
        var playlist = [PlayerTrack]()
        
        let jsonObject = json.arrayValue
        jsonObject.forEach { track in
            var playerTrack = PlayerTrack()
            playerTrack.id = track["id"].intValue
            playerTrack.name = track["name"].string
            
            if let listObject = track["artistList"].array {
                let nameList = listObject.map { $0["name"].stringValue }.filter { !$0.isEmpty }
                playerTrack.artistNames = nameList.joined(separator: " & ")
            }
            
            var album = PlayerAlbum()
            album.id = track["album"]["id"].intValue
            album.title = track["album"]["title"].string
            album.imageList = track["album"]["imgList"].arrayValue.map { image -> PlayerImageURL in
                var imageURL = PlayerImageURL()
                imageURL.size = image["size"].intValue
                imageURL.url = image["url"].string
                return imageURL
            }
            playerTrack.album = album
            
            playlist.append(playerTrack)
        }
        
        return playlist
    }
    
    fileprivate func metadata(index: Int, position: Double, duration: Double) -> String {
        return "{index:\(index), position:\(position), duration:\(duration)}"
    }
    
    fileprivate func state(status: MusicPlayerStatus) -> String {
        var state: Int
        var errorJson: String?
        
        switch status {
        case .playing:
            state = 0
        case .paused:
            state = 1
        case let .stopped(error):
            state = 2
            if let error = error {
                var code: Int?
                
                switch error.kind {
                case .network:
                    code = 1
                case .needCellular:
                    code = 2
                case .playPermission:
                    code = 3
                case .invalidRefreshToken, .invalidRefreshTokenByChangePassword, .invalidSessionToken:
                    code = 4
                case .audioSession, .prepareAsset, .playerItem, .failedToPlayToEndTime:
                    break
                }
                
                if let code = code {
                    errorJson = "{code:\(code),message:\(error.localizedDescription)}"
                }
            }
        case .connecting(_):
            state = 3
        }
        
        return "{state:\(state), error:{\(errorJson ?? "")}}"
    }
}
