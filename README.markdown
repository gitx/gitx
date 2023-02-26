# What is GitX?

[![GitHub Actions Build Status](https://github.com/gitx/gitx/workflows/build-gitx/badge.svg)](https://github.com/gitx/gitx/actions?query=workflow%3Abuild-gitx)

GitX is an OS X (MacOS) native graphical client for the `git` version
control system.

GitX has a long history of various branches and versions maintained by
various people over the years. This github org & repo are an attempt to
consolidate and move forward with a current, common, community-maintained
version.

### How to Install:

Get the latest release of GitX from the [Releases](https://github.com/gitx/gitx/releases)
page. Download, extract and move it to your Applications folder.
For Apple Silicon (M1, M2 processors) please use the `arm64` release.

See also: [How to Build in Xcode](#how-to-build-in-xcode)

### Screenshots

![Staging View](screenshot-stage.png)

![History View](screenshot-history.png)

### How to Build in Xcode:

To build and run in the Xcode app with your own developer account, create
a config file called `Dev.xcconfig` at the project root like this:

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

Replace `YOUR_TEAM_ID` with your development team ID.
If you don't know your ID or don't have one yet, follow the steps below:

1. Open the **Xcode** app.
2. In Settings > Accounts, if you haven't added your Apple ID yet, click the `+` button and add your Apple ID.
3. In your Apple ID account settings, there should be at least one team with your name and **(Personal Team)** in the name. Click on it.
4. Click on the **Manage Certificates** button.
5. If you don't see any certificate listed, click the `+` button and click on **Apple Development**.
6. Click Done and close the Settings window.
7. Use Spotlight to open **Keychain Access** (or open it in Applications > Utilities).
8. Go to the `login` keychain, and open the **My Certificates** tab.
9. Find the certificate named **Apple Development** with your Apple ID email address.
10. Double-click on this certificate to view its details.
11. Copy the **Organizational Unit** value. This is your development team ID.

You can also build and run on the command line. Once you've created the config file,
you may use [the script shared here](https://github.com/gitx/gitx/discussions/366#discussion-4897466).
For x86 builds, please replace `arm64` with `x86_64`.

### Apple Silicon

This project is supported by MacStadium Open Source Developer Program with a free Mac mini for our CI. Thank you !

<img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" width="300" />

### License

GitX is licensed under the GPL version 2. For more information, see the attached COPYING file.
