class Libasr < Formula
  desc "A free, simple and portable asynchronous resolver library."
  homepage "https://github.com/OpenSMTPD/libasr"
  url "https://opensmtpd.org/archives/libasr-1.0.2.tar.gz"
  version "1.0.2"
  sha256 "a6f5d1c6306938156da3427525572b9b16c1e6be6c69845d390bb63f41a58b34"

  depends_on "libressl"

  keg_only "This library is only (?) used by OpenSMTPD."

  def install
    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! It's enough to just replace
    # "false" with the main program this formula installs, but it'd be nice if you
    # were more thorough. Run the test with `brew test libasr`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    system "false"
  end
end
