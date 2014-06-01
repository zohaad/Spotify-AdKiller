#!/bin/bash

# Spotify-Adkiller Respository: https://github.com/SecUpwN/Spotify-AdKiller/
# Feel free to contribute improvements and suggestions to this funky script!

# Spotify-AdKiller-Mode: Automute-Continuous
# Automatically mutes Spotify when ad comes on and plays random local file
# Automatically continues Spotify playback afterwards

# IMPORTANT REMINDER! CAREFULLY READ AND UNDERSTAND THIS PART. THANK YOU.
# -----------------------------------------------------------------------
# Spotify is a fantastic service and worth every penny.
# This script is *NOT* meant to circumvent buying premium.
# Please do consider switching to premium to support Spotify!
# -----------------------------------------------------------------------

# This script has a history! Here's how this awesome script was born:
# Original GitHub Gist by pcworld in 2012: https://gist.github.com/pcworld/3198763
# Multiple improvement suggestions and forks by several members of GitHub
# Mayjor re-write by Feltzer in 2014 to support continuous music playback
# Last Error-Fix by hairyheron in May 2014 before creating our Repository

# -----------------------------------------------------------------------
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# -----------------------------------------------------------------------

# Settings

LOCALMUSIC="$HOME/Music"
ALERT="/usr/share/sounds/gnome/default/alerts/glass.ogg"
PLAYER="mpv --vo null"

# VAR

WMTITLE="Spotify - Linux Preview"
ADMUTE=0
PAUSED=0

# FCT

print_horiz_line(){
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

spotify_playpause(){
    dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 \
    org.mpris.MediaPlayer2.Player.PlayPause > /dev/null 2>&1
}

get_pactl_nr(){
    LC_ALL=C pactl list | grep -E '(^Sink Input)|(media.name = \"Spotify\"$)' | cut -d \# -f2 \
    | grep -v Spotify
}

player(){
    RANDOMTRACK="$(find "$LOCALMUSIC" -name "*.mp3" | sort --random-sort | head -1)"
    notify-send -i spotify "Spotify ad muter" "Playing ${RANDOMTRACK##*/}"
    $PLAYER "$ALERT"
    $PLAYER "$RANDOMTRACK"
    spotify_playpause # continue Spotify playback. This triggers the xprop spy and
                      # subesequent actions like unmuting Spotify
}

# MAIN

xprop -spy -name "$WMTITLE" WM_ICON_NAME |
while read -r XPROPOUTPUT; do
    XPROP_TRACKDATA="$(echo "$XPROPOUTPUT" | cut -d \" -f 2 )"
    DBUS_TRACKDATA="$(dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify / \
    org.freedesktop.MediaPlayer2.GetMetadata | grep xesam:title -A 1 | grep variant | cut -d \" -f 2)"

    echo "XPROP:    $XPROP_TRACKDATA"
    echo "DBUS:     $DBUS_TRACKDATA"

    if [[ "$XPROP_TRACKDATA" = "Spotify" ]]
      then
          echo "PAUSED:      Yes"
          PAUSED="1"
      else
          PAUSED="0"
          echo "PAUSED:      No"
    fi

    if [[ "$PAUSED" = "1" || "$XPROP_TRACKDATA" =~ "$DBUS_TRACKDATA" ]]
      then
          echo "AD:          No"
          if [[ "$ADMUTE" = "1" ]]
            then
                if ps -p $ALTPID > /dev/null 2>&1       # if alternative player still running
                  then
                      if [[ "$PAUSED" != "1" ]]         ## and if track not yet paused
                        then
                            spotify_playpause           ### then pause
                            echo "##Pausing Spotify until local playback finished##"
                      fi
                      continue                          ## reset loop
                  else                                                          # if player not running
                      for PACTLNR in $(get_pactl_nr); do
                          pactl set-sink-input-mute "$PACTLNR" no > /dev/null 2>&1 ## unmute
                          echo "##Unmuting sink $PACTLNR##"
                          echo "##Switching back to Spotify##"
                      done
                fi
          fi
          ADMUTE=0
      else
          echo "AD:          Yes"
          if [[ "$ADMUTE" != "1" ]]
            then
                for PACTLNR in $(get_pactl_nr); do
                    pactl set-sink-input-mute "$PACTLNR" yes > /dev/null 2>&1
                    echo "##Muting sink $PACTLNR##"
                done
                if ! ps -p $ALTPID > /dev/null 2>&1
                  then
                      echo "##Switching to local playback##"
                      player > /dev/null 2>&1 &
                      ALTPID="$!"
                fi
          fi
          ADMUTE=1
    fi
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
done

echo "Spotify not active. Exiting."

exit 0
