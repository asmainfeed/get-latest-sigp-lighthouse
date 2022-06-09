#!/bin/bash
: '
This script downloads and extracts the latest pre-built binary release 
of sigp/lighthouse (etheruem consensus client) and verifies the associated gpg signature.
'

### CONSTANTS ###
# SIGP public key URL
SIGP_PUBKEY_URL="https://keybase.io/sigp/pgp_keys.asc?fingerprint=15e66d941f697e28f49381f426416dc3f30674b0"
# SIGP/Lighthouse release URL
SIGP_LIGHTHOUSE_RELEASE_URL="https://api.github.com/repos/sigp/lighthouse/releases/latest"
# determine current terminal width
TTY_WIDTH=$(stty -a <"/dev/pts/0" |grep -Po '(?<=columns )\d+')
# output directory
OUTPUT_DIR="$HOME/lighthouse_bins"

# utility function to print chars at terminal width
function repeat_char() {
    local char="$1"
    for (( i = 0; i < "$TTY_WIDTH"; ++i ))
    do
        echo -n "$char"
    done
}
repeat_char '~'
repeat_char '~'
printf "NOTE: Assumes lighthouse binary lives at /usr/local/bin/lighthouse\n"
printf "NOTE: Assumes target binary/arch is x86_64-unknown-linux-gnu.tar.gz\n"
printf "NOTE: Assumes Sigma Prime PubKey URL is: \n\n"
printf "\t%s\n\n" "$SIGP_PUBKEY_URL"
repeat_char '~'
repeat_char '~'

# prompt continue
read -rp "Continue? (y/n):  " choice
case "$choice" in 
  y|Y ) printf "\n";;
  n|N ) printf "\nCancelled!\n"; exit 0;;
  * ) printf "\nInvalid\n"; exit 0;;
esac

# check for jq
printf "Check jq installed:"
if hash jq 2>/dev/null; then
  printf " \u2705\n"
else
  printf "\u274c\n"
  echo "You need jq. Install it? "
  read -r -e -p "(y/n)? " choice
  if [[ "y" = "$choice" || "Y" = "$choice" ]]; then
    sudo apt install jq
  else
    echo "We need jq. Stopping."
    exit
  fi
fi

# check for existing lighthouse
printf "Check for existing lighthouse installation:"
if hash lighthouse 2>/dev/null; then
  printf " \u2705\n"
  # save existing lighthouse version
  LOCAL_LIGHTHOUSE_VERSION="$(/usr/local/bin/lighthouse -V | cut -c 13-17)"
else
  printf "\u274c\n"
  LOCAL_LIGHTHOUSE_VERSION="not installed"
fi



# get the latest release binary url
LATEST_LIGHTHOUSE_BIN_URL="$(curl -s $SIGP_LIGHTHOUSE_RELEASE_URL \
| jq -r '.assets[] | select(.name |test("x86_64-unknown-linux-gnu.tar.gz$")) .browser_download_url')"

# get the latest release binary url .asc file
LATEST_LIGHTHOUSE_ASC_URL="$(curl -s $SIGP_LIGHTHOUSE_RELEASE_URL \
| jq -r '.assets[] | select(.name |test("x86_64-unknown-linux-gnu.tar.gz.asc$")) .browser_download_url')"

LATEST_RELEASE_NAME="$(curl -s $SIGP_LIGHTHOUSE_RELEASE_URL | jq -r '[.tag_name, .name] | join(" ")')"

LATEST_LIGHTHOUSE_BIN_FILENAME=${LATEST_LIGHTHOUSE_BIN_URL##*/}
LATEST_LIGHTHOUSE_ASC_FILENAME=${LATEST_LIGHTHOUSE_ASC_URL##*/}

# log current version
printf "Installed version of Lighthouse is:\t\tv%s\n\n" "$LOCAL_LIGHTHOUSE_VERSION"

# log it to console
printf "Latest available release is:\t\t\t%s\n" "$LATEST_RELEASE_NAME"
printf "Latest available release url:\n\t%s\n\n" "$LATEST_LIGHTHOUSE_BIN_URL"

# Check output dir exists
printf "Checking output directory: %s exists...\n" "$OUTPUT_DIR"
if [[ ! -d "$OUTPUT_DIR" ]];
then
    printf "\n\t%s directory not found!\n" "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR" && cd "$_" || exit
    printf "\n\tCreated %s.\n\n" "$OUTPUT_DIR"
else
    printf "\n\t%s directory exists!\n\n" "$OUTPUT_DIR"
    cd "$OUTPUT_DIR" || exit
fi

read -rp "Download ${LATEST_RELEASE_NAME} (y/n)?  " choice
case "$choice" in 
  y|Y ) printf "\n\n"; printf "Downloading %s\n\n" "$LATEST_LIGHTHOUSE_BIN_FILENAME"
  curl -#LO "$LATEST_LIGHTHOUSE_BIN_URL"; 
  printf "\nDownloading %s\n\n" "$LATEST_LIGHTHOUSE_ASC_FILENAME"
  curl -#LO "$LATEST_LIGHTHOUSE_ASC_URL";;
  n|N ) printf "\nCancelled!\n"; exit 0;;
  * ) printf "\nInvalid\n"; exit 0;;
esac
printf "\n\n"

read -rp "Verify signature? (y/n)?  " choice
case "$choice" in 
  y|Y ) printf "\n"; 
  curl -# "$SIGP_PUBKEY_URL" |gpg --import && gpg --verify "$LATEST_LIGHTHOUSE_ASC_FILENAME" "$LATEST_LIGHTHOUSE_BIN_FILENAME";;
  n|N ) printf "Skipped!\n"; exit 0;;
  * ) printf "Invalid\n"; exit 0;;
esac
printf "\n\n"

read -rp "Unpack tarball? (y/n)?  " choice
case "$choice" in 
  y|Y ) printf "\n"; tar -xf "$LATEST_LIGHTHOUSE_BIN_FILENAME";;
  n|N ) printf "\Skipped!\n"; exit 0;;
  * ) printf "\nInvalid\n"; exit 0;;
esac
printf "\n"

printf "Success! Latest release downloaded to %s\n" "$OUTPUT_DIR"
printf "NOTE: Make sure to cp the new binary into /usr/local/bin\n"
