> [!CAUTION]
> Arbor is currently in active development.

# 🌳 Arbor

Arbor is a native music player for Apple devices.

I built this originally to easily pitch-shift, adjust speed, and add reverb on the go, but it can be used as an alternative to a music streaming service.

Arbor's core app is built in Swift, but it uniquely ships an embedded version of the Python runtime. This enables Arbor to use battle-tested libraries like [yt-dlp](https://github.com/yt-dlp/yt-dlp) directly on device.

## FAQ

Q. **Will Arbor be published to the App Store?**

- No. Apple prevents apps that download YouTube videos from being published to the App Store as this explicitly violates [Guideline 5.2.3 of Apple's App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#5.2.3). Note that the issue is *not* because we're embedding the Python runtime, which is allowed.

Q. **Where did the name come from?**

- I started working on this while I was visiting the city of [Ann Arbor](https://www.google.com/search?q=ann+arbor+michigan).
