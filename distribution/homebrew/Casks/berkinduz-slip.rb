cask "berkinduz-slip" do
  version "0.3.0"
  sha256 "9176fec26e02bb785b120c39cb4ed3f293edcb2652c7db08f6ac28d0d84f2707"

  url "https://github.com/berkinduz/slip-menu-note-app/releases/download/v#{version}/Slip-v#{version}-macos-arm64.dmg"
  name "Slip"
  desc "Quick notes and Markdown in your Mac menu bar"
  homepage "https://github.com/berkinduz/slip-menu-note-app"

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "Slip.app"
end
