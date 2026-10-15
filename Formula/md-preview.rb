class MdPreview < Formula
  desc "macOS Markdown preview app with double-click-to-edit"
  homepage "https://github.com/devinjones812/md-preview"
  url "https://github.com/devinjones812/md-preview/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "612b81217e38145555c1f01c3233801a4ff8c43e599dffe0387a9ae8503993bc"
  license "GPL-3.0-only"

  depends_on :macos
  depends_on "pandoc"

  def install
    system "./build.sh"
    prefix.install "build/MD Preview.app"
  end

  def caveats
    <<~EOS
      Add MD Preview to Applications:
        ln -sf "#{opt_prefix}/MD Preview.app" /Applications/
      Then open it and choose MD Preview > Set as Default for .md Files.
    EOS
  end

  test do
    assert_path_exists prefix/"MD Preview.app/Contents/MacOS/MDPreview"
  end
end
