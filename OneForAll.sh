#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 

# --- Global 7-Zip Detection ---
Z7_CMD="7z"
if ! command -v 7z >/dev/null 2>&1; then
    if [ -f "/c/Program Files/7-Zip/7z.exe" ]; then
        Z7_CMD="/c/Program Files/7-Zip/7z.exe"
    elif [ -f "C:/Program Files/7-Zip/7z.exe" ]; then
        Z7_CMD="C:/Program Files/7-Zip/7z.exe"
    fi
fi

ensure_7z() {
  if ! command -v "$Z7_CMD" >/dev/null 2>&1; then
    echo "7z not found. Attempting to install..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      sudo apt-get update && sudo apt-get install -y p7zip-full
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      brew install sevenzip
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
      if command -v winget >/dev/null 2>&1; then
        winget install 7zip.7zip --silent
        echo "Installed via winget."
      else
        echo "Error: winget not found. Please install 7-Zip manually."
        exit 1
      fi
    fi
  fi
}

ensure_7z

zip_folder() {
  local folder="$1"
  local zip_path="$2"

  echo "  [7z] Zipping $folder -> $zip_path"

  "$Z7_CMD" a -tzip -mx5 -y "$zip_path" "$folder"/*

  if [[ ! -f "$zip_path" ]]; then
    echo "❌ Zip failed for $folder"
    exit 1
  fi

  echo "  Cleaning up source files in $folder..."
  find "$folder" -mindepth 1 ! -name "$(basename "$zip_path")" -delete
}


inject_script() {
  local file="$1"
  local script="$2"
  awk -v insert="$script" '/<div/ && !done { print insert; done=1 } { print }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# --- INPUT FUNCTION ---
get_valid_url() {
    local prompt_text="$1"
    local url_input=""
    local cleaned_url=""
    
    while true; do
        read -e -r -p "$prompt_text" url_input
        
        cleaned_url=$(echo "$url_input" | tr -d '[:cntrl:]' | grep -oE '(https?://|www\.)[^[:space:]"]+' | head -n1 || echo "")

        if [[ "$cleaned_url" == "www."* ]]; then
            cleaned_url="https://$cleaned_url"
        fi

        if [[ -n "$cleaned_url" ]]; then
            if [[ "$cleaned_url" == *"|"* ]]; then
                echo "  [Error] URL cannot contain the pipe character '|'. Please encode it as %7C."
            else
                echo "$cleaned_url"
                break
            fi
        else
            echo "  [Error] Invalid input. Please enter a valid URL starting with http://, https://, or www."
        fi
    done
}

echo "Creating eXport folder..."
mkdir -p "$SCRIPT_DIR/eXport"
cd "$SCRIPT_DIR/eXport" || exit 1

# --- MAIN EXECUTION ---
read -p "Enter project name: " PROJECT_NAME
mkdir -p "$PROJECT_NAME" || exit 1 

echo "------------------------------------------------"
IOS_URL=$(get_valid_url "Enter iOS Store URL: ")
echo "  -> Accepted: $IOS_URL"

echo "------------------------------------------------"
ANDROID_URL=$(get_valid_url "Enter Android Store URL: ")
echo "  -> Accepted: $ANDROID_URL"
echo "------------------------------------------------"

cd "$PROJECT_NAME" || exit 1

# Source locations
ORIGINAL_HTML="$SCRIPT_DIR/Google.html"
MINTEGRAL_SRC="$SCRIPT_DIR/Mintegral"
FACEBOOK_SRC="$SCRIPT_DIR/Facebook"
ADIKTEEV_ZIP="$SCRIPT_DIR/Adikteev.zip"

[[ -f "$ORIGINAL_HTML" ]] || { echo "Google.html not found"; exit 1; }
[[ -d "$MINTEGRAL_SRC" ]] || { echo "Mintegral folder not found"; exit 1; }
[[ -d "$FACEBOOK_SRC" ]] || { echo "Facebook folder not found"; exit 1; }

echo "Cleaning Google.html..."
CLEAN_HTML="$(mktemp)"
trap 'rm -f "$CLEAN_HTML"' EXIT
sed -e 's/Cocos Creator | //g' -e 's|<script type="text/javascript" src="https://tpc.googlesyndication.com/pagead/gadgets/html5/api/exitapi.js"></script>||g' "$ORIGINAL_HTML" > "$CLEAN_HTML"
echo "------------------------------------------------"

# --- INJECTION SCRIPT ---
INJECT_MRAID_SCRIPT="<script>
window.adManOpenStore = function (url) {
    console.log('Overwritten openStore called!');
    const IOS_STORE_URL = '$IOS_URL';
    const ANDROID_STORE_URL = '$ANDROID_URL';
    
    var isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) || navigator.userAgent.includes('Macintosh');
    const clickTag = isIOS ? IOS_STORE_URL : ANDROID_STORE_URL;
    if(typeof mraid !== 'undefined' && mraid.open) { 
      mraid.open(clickTag); 
    }
    else {
      window.open(clickTag);
    }
  }
</script>"

INJECT_META_SCRIPT="<script>
window.adManOpenStore = function (url) {
    console.log('Overwritten openStore called!');
    const IOS_STORE_URL = '$IOS_URL';
    const ANDROID_STORE_URL = '$ANDROID_URL';
    
    var isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) || navigator.userAgent.includes('Macintosh');
    const clickTag = isIOS ? IOS_STORE_URL : ANDROID_STORE_URL;
    if(typeof FbPlayableAd !== 'undefined' && FbPlayableAd.onCTAClick) { FbPlayableAd.onCTAClick(); 
    }
    else {
      window.open(clickTag);
    }
}
</script>"

LOWER_HTML_FOLDERS=(Adwords IronSource Smadex Moloco Vungle Applovin Unity Tiktok)
echo "Generating standard HTML network folders..."
for folder in "${LOWER_HTML_FOLDERS[@]}"; do
  mkdir -p "$folder"
  target_html="$folder/$folder.html"
  cp "$CLEAN_HTML" "$target_html"

  if [[ "$folder" != "Moloco" ]]; then
    inject_script "$target_html" "$INJECT_MRAID_SCRIPT"
  else
    inject_script "$target_html" "$INJECT_META_SCRIPT"
  fi
done

INDEX_ZIP_FOLDERS=(Google Liftoff Pangle)
echo "Generating Zipped network folders..."
for folder in "${INDEX_ZIP_FOLDERS[@]}"; do
  mkdir -p "$folder"
  target_html="$folder/index.html"
  cp "$CLEAN_HTML" "$target_html"
  inject_script "$target_html" "$INJECT_MRAID_SCRIPT"
  zip_folder "$folder" "$folder/$folder.zip"
done

echo "Processing Mintegral..."
mkdir -p Mintegral
cp -r "$MINTEGRAL_SRC/"* Mintegral/
zip_folder "Mintegral" "Mintegral/Mintegral.zip"

echo "Processing Facebook..."
mkdir -p Facebook
cp -r "$FACEBOOK_SRC/"* Facebook/
if [[ -f "Facebook/index.html" ]]; then
  target_html="Facebook/index.html"
  inject_script "$target_html" "$INJECT_META_SCRIPT"
  sed -i.bak 's/Cocos Creator | //g' Facebook/index.html
  rm -f Facebook/index.html.bak
fi
zip_folder "Facebook" "Facebook/Facebook.zip"

# --- ADIKTEEV PROCESSING ---
echo "Processing Adikteev..."
mkdir -p Adikteev

if [[ -f "$ADIKTEEV_ZIP" ]]; then
    echo "  Extracting base Adikteev files..."
    mkdir -p Adikteev_temp
    "$Z7_CMD" x "$ADIKTEEV_ZIP" -o"Adikteev_temp" -y >/dev/null
    
    if [[ -d "Adikteev_temp/Adikteev" ]]; then
        cp -r Adikteev_temp/Adikteev/* Adikteev/
    else
        cp -r Adikteev_temp/* Adikteev/
    fi
    rm -rf Adikteev_temp
else
    echo "Warning: Adikteev.zip not found at $ADIKTEEV_ZIP"
fi

if [[ -d "$FACEBOOK_SRC/js" ]]; then
    echo "  Copying js folder from Facebook source..."
    cp -r "$FACEBOOK_SRC/js" Adikteev/
fi

# --- LinKsChanged in creative.js ---
CREATIVE_JS="Adikteev/creative.js"
if [[ -f "$CREATIVE_JS" ]]; then
    echo "  Updating Store URLs in creative.js..."
    
    SAFE_IOS="${IOS_URL//&/\\&}"
    SAFE_ANDROID="${ANDROID_URL//&/\\&}"

    sed -i "s|^.*const IOS_STORE_URL =.*$|const IOS_STORE_URL = \"$SAFE_IOS\";|g" "$CREATIVE_JS"
    sed -i "s|^.*const ANDROID_STORE_URL =.*$|const ANDROID_STORE_URL = \"$SAFE_ANDROID\";|g" "$CREATIVE_JS"
    
    echo "  URLs updated successfully."
else
    echo "Warning: creative.js not found in Adikteev folder. Skipping URL update."
fi
echo "Zipping Adikteev..."
zip_folder "Adikteev" "Adikteev/Adikteev.zip"

echo "Export structure created successfully!"
