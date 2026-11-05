cask "slip" do
  version "0.3.0"
  sha256 "dd59b9fc72adbc28dc815a0291df37b28f020961419f0b2edac65469312b857c"

  url "https://github.com/berkinduz/slip-menu-note-app/releases/download/v#{version}/Slip-v#{version}-macos-arm64.dmg"
  name "Slip"
  desc "Quick notes and Markdown in your menu bar"
  homepage "https://github.com/berkinduz/slip-menu-note-app"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Slip.app"
end
