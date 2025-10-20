> [!CAUTION]
> Arbor is currently in active development.

# 🌳 Arbor

Arbor is a native music player for Apple devices.

I built this originally to easily pitch-shift, adjust speed, and add reverb on the go, but it can be used as an alternative to a music streaming service.

Arbor's core app is built in Swift, but it uniquely ships an embedded version of the Python runtime. This enables Arbor to use battle-tested libraries like [yt-dlp](https://github.com/yt-dlp/yt-dlp) directly on device.

## Local Setup
1. Download Python.xcframework to the root of the repository
  
```
curl -L -O https://github.com/beeware/Python-Apple-support/releases/download/3.14-b8/Python-3.14-iOS-support.b8.tar.gz
tar -xzf Python-3.14-iOS-support.b8.tar.gz
rm Python-3.14-iOS-support.b8.tar.gz
```

2. Install Python dependencies using your global installation of pip
```
pip3 install --target=./python_modules --platform=any --only-binary=:all: -r requirements.txt
```

3. Open the project in Xcode (`xed Arbor.xcodeproj`) and run


## FAQ

Q. **Will Arbor be published to the App Store?**

- No. Apple prevents apps that download YouTube videos from being published to the App Store as this explicitly violates [Guideline 5.2.3 of Apple's App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#5.2.3). Note that the issue is *not* because we're embedding the Python runtime, which is allowed.

Q. **Where did the name come from?**

- I started working on this while I was visiting the city of [Ann Arbor](https://www.google.com/search?q=ann+arbor+michigan).
