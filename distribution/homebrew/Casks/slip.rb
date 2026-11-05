cask "slip" do
  version "0.3.1"
  sha256 "802ca80054af118bd08260335225c52895c1e8d14eb036073e36da0d108906ed"

  url "https://github.com/berkinduz/slip-menu-note-app/releases/download/v#{version}/Slip-v#{version}-macos-arm64.dmg"
  name "Slip"
  desc "Quick notes and Markdown in your menu bar"
  homepage "https://github.com/berkinduz/slip-menu-note-app"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Slip.app"
end
