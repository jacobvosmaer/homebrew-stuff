class Opensmtpd < Formula
  desc "A FREE implementation of the server-side SMTP protocol as defined by RFC 5321, with some additional standard extensions."
  homepage "https://www.opensmtpd.org"
  url "https://www.opensmtpd.org/archives/opensmtpd-5.7.3p1.tar.gz"
  version "5.7.3p1"
  sha256 "848a3c72dd22b216bb924b69dc356fc297e8b3671ec30856978950208cba74dd"
  head "https://github.com/OpenSMTPD/OpenSMTPD.git", :branch => "portable"

  # thank you https://gist.github.com/mistydemeo/5519261
  depends_on "automake => :build
  depends_on "autoconf" => :build
  depends_on "libtool" => :build
  depends_on "bison"" => :build
  depends_on "pkg-config" => :build
  depends_on "libressl"
  depends_on "libasr"
  depends_on "libevent"

  def install
    # avoid T_CNAME errors, thank you https://gist.github.com/mistydemeo/5519261
    ENV.append_to_cflags "-DBIND_8_COMPAT=1"

    # avoid re-defining snprintf (provided by stdio.h)
    ENV.append_to_cflags "-DHAVE_SNPRINTF=1"

    system "./bootstrap" if !File.exist?("config.guess")

    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--sysconfdir=#{etc}",
                          "--prefix=#{prefix}"

    system "make", "install"
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! It's enough to just replace
    # "false" with the main program this formula installs, but it'd be nice if you
    # were more thorough. Run the test with `brew test opensmtpd-5.7.3p`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system "#{bin}/program", "do", "something"`.
    cfg = 'fake-config'
    FileUtils.touch cfg
    system "#{bin}/smtpd", "-nf", cfg
  end
end
