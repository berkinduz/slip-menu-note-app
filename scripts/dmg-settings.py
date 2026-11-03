from pathlib import Path

application = Path(defines["app"])

format = "UDZO"
compression_level = 9
filesystem = "HFS+"
files = [(str(application), "Slip.app")]
symlinks = {"Applications": "/Applications"}
icon = str(application / "Contents/Resources/Slip.icns")
background = defines["background"]

window_rect = ((160, 160), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 104
text_size = 14
icon_locations = {"Slip.app": (170, 190), "Applications": (470, 190)}
