# Cocos Creator Ad Network Packaging Automation

This tool ensures that your "playable ads" meet the specific file structure and API requirements of multiple platforms simultaneously.

## Key Features

* **Multi-Platform Support**: Generates ready-to-upload packages for Google (Adwords), Facebook, Unity, Applovin, IronSource, Mintegral, Liftoff, **Adikteev**, and more.
* **Automatic 7-Zip Integration**: Detects and automatically installs `7z` (via winget/brew/apt), compatible ZIP archives.
* **Script Injection**: Automatically injects specialized `window.adManOpenStore` logic and MRAID support into Unity and Applovin builds, and dynamically updates Store URLs in Adikteev's `creative.js`.
* **HTML Optimization**:
    * Removes Cocos Creator default titles.
    * Strips the exit.js 
    * Ensures `index.html` is at the root of every ZIP (critical for ad network validation).

---

## Prerequisites for Windows Users

1.  **Git-Bash for Windows**: [Download and Install Git](https://git-scm.com/downloads) (includes Git Bash).
2.  **7-Zip**: The script will attempt to install this via `winget` if missing.
3.  The 7z installation is automated w/ user permission (happens automatically just say **`YES`**)

---

## How to Use

1.  **Download the Essentials**: You must have both the script file (`OneForAll.sh`) and the **`Adikteev.zip`** template file.
2.  **Put those in the root of **`Build`** Directory
3.  **Run the Script**: Right-click in the folder, select **"Open Git Bash here"**, and run:
    ```bash
    ./OneForAll.sh
    ```
    or, 
    ```bash
    sh OneForAll.sh
    ```
4.  **Configuration**: Enter your **Project Name**, **iOS Store URL**, and **Android Store URL** when prompted.
5.  **Retrieve Exports**: Find your processed, network-ready files in the `eXport/[ProjectName]` folder.

> [!IMPORTANT]
> **Adikteev Integration**
> The script extracts `Adikteev.zip`, merges it with the latest `js/` folder from your Facebook source, and automatically updates the store URLs inside `creative.js` using the inputs you provided.

---

## Supported Networks

| Output Type | Networks |
| :--- | :--- |
| **Flat HTML** | Adwords, IronSource, Moloco, Smadex, Vungle, Tiktok |
| **Zipped index.html** | Google, Liftoff, Pangle |
| **Asset Packages** | Mintegral, Facebook |
| **Custom Integration** | **Adikteev** (Zip template + FB JS + URL Injection) |
| **Script Injected** | Applovin, Unity |

---
*Created for Cocos Creator Playable Ad workflows.*
