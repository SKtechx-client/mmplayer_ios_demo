# mmplayer_ios_demo
## 실행 방법
다운로드 또는 클론 후
```bash
$ pod install
```
or
```bash
$ pod install --repo-update
```

## info.plist 설정
```xml
<key>NSAppTransportSecurity</key>
<dict>
<key>NSAllowsArbitraryLoads</key>
<true/>
</dict>
<key>UIBackgroundModes</key>
<array>
<string>audio</string>
</array>
```

## 중요 코드
### PlayerController.swift 
- 플레이어 SDK Objective-C Wrapper

### ViewController.m
- Front-End Javascript interface
