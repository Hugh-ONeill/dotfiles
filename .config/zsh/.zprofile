if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then	
  #Hyprland
  #HYPRLAND_TRACE=1
  #HYPRLAND_NO_RT=1
  #HYPRLAND_NO_SD_NOTIFY=1
  #HYPRLAND_NO_SD_VARS=1
  #HYPRLAND_CONFIG=
  #Aquamarine
  #AQ_TRACE=1
  #AQ_DRM_DERVICES=
  #AQ_MGPU_NO_EXPLICIT=1
  #AQ_NO_MODIFIERS=1
  start-hyprland >| "$XDG_CACHE_HOME"/hyprland.log 2>&1
  #if uwsm check may-start; then
  #  exec uwsm start hyprland.desktop >| "$XDG_CACHE_HOME"/hyprland.log 2>&1
  #fi
fi
