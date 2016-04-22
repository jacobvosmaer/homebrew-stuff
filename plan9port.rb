class Plan9port < Formula
  desc "Many Plan 9 programs ported to UNIX-like operating systems"
  homepage "https://swtch.com/plan9port/"
  url "https://plan9port.googlecode.com/files/plan9port-20140306.tgz"
  sha256 "cbb826cde693abdaa2051c49e7ebf75119bf2a4791fe3b3229f1ac36a408eaeb"
  head "https://github.com/9fans/plan9port.git"

  bottle do
    cellar :any_skip_relocation
    sha256 "eb56faa4c63a522e34ba609fc0d4eb5af9b22715c0915629776129eb64d8625f" => :el_capitan
    sha256 "86fd2ed15a0fe79927c04a064222f88455bfc0e72bc1f97576e2962b11a70cc8" => :yosemite
    sha256 "ef0059997655128f6b41faa1023b37a071ff9976f4c94d3b3bd706be65177aa1" => :mavericks
  end

  depends_on :x11 => :optional

  patch :DATA

  def install
    ENV["PLAN9_TARGET"] = libexec

    if build.with? "x11"
      # Make OS X system fonts available to Plan 9
      File.open("LOCAL.config", "a") do |f|
        f.puts "FONTSRV=fontsrv"
      end
    end

    system "./INSTALL"

    libexec.install Dir["*"]
    bin.install_symlink "#{libexec}/bin/9"
    prefix.install Dir["#{libexec}/mac/*.app"]
  end

  def caveats; <<-EOS.undent
    In order not to collide with OSX system binaries, the Plan 9 binaries have
    been installed to #{libexec}/bin.
    To run the Plan 9 version of a command simply call it through the command
    "9", which has been installed into the Homebrew prefix bin.  For example,
    to run Plan 9's ls run:
        # 9 ls
    EOS
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
      #include <u.h>
      #include <libc.h>
      #include <stdio.h>

      int main(void) {
        return printf("Hello World\\n");
      }
    EOS
    system "#{bin}/9", "9c", "test.c"
    system "#{bin}/9", "9l", "-o", "test", "test.o"
    assert_equal "Hello World\n", `./test`
  end
end

__END__
Nedmail has trouble sending email because it builds invalid paths to
individual mail messages when quoting etc. Might be because we are
using nfs instead of 'original' upas/fs. This patch seems to fix it.

diff a/src/cmd/upas/ned/nedmail.c b/src/cmd/upas/ned/nedmail.c
--- a/src/cmd/upas/ned/nedmail.c
+++ b/src/cmd/upas/ned/nedmail.c
@@ -2549,9 +2549,8 @@ rooted(String *s)
 {
 	static char buf[256];

-	if(strcmp(root, ".") != 0)
-		return s;
-	snprint(buf, sizeof(buf), "/mail/fs/%s/%s", mbname, s_to_c(s));
+	// Edit by Jacob. Not 100% sure what I am doing here but it seems to work
+	snprint(buf, sizeof(buf), "Mail/%s", s_to_c(s));
 	s_free(s);
 	return s_copy(buf);
 }

Because /usr/local is on a case-insensitve filesystem, acme/Mail will
get overwritten by the plan9 'mail' wrapper script. Rename acme/Mail
to acme/Amail.

diff --git a/src/cmd/acme/mail/mkfile b/src/cmd/acme/mail/mkfile
index d95e1b2..1c7ebf3 100644
--- a/src/cmd/acme/mail/mkfile
+++ b/src/cmd/acme/mail/mkfile
@@ -1,6 +1,6 @@
 <$PLAN9/src/mkhdr

-TARG=Mail
+TARG=Amail
 OFILES=\
 		html.$O\
 		mail.$O\

Build programs required for mail: factotum (credential keychain),
mailfs, upas (mail tools), nfs (the 'new' upas/fs implementation of
plan9port).

diff --git a/src/cmd/mkfile b/src/cmd/mkfile
index d256303..53489ce 100644
--- a/src/cmd/mkfile
+++ b/src/cmd/mkfile
@@ -4,7 +4,7 @@ TARG=`ls *.[cy] *.lx | egrep -v "\.tab\.c$|^x\." | sed 's/\.[cy]//; s/\.lx//'`

 <$PLAN9/src/mkmany

-BUGGERED='CVS|faces|factotum|fontsrv|lp|ip|mailfs|upas|vncv|mnihongo|mpm|index|u9fs|secstore|smugfs|snarfer'
+BUGGERED='CVS|faces|fontsrv|lp|ip|vncv|mnihongo|mpm|index|u9fs|secstore|smugfs|snarfer'
 DIRS=lex `ls -l |sed -n 's/^d.* //p' |egrep -v "^($BUGGERED)$"|egrep -v '^lex$'` $FONTSRV

 <$PLAN9/src/mkdirs
diff --git a/src/cmd/upas/mkfile b/src/cmd/upas/mkfile
index 4a33e9f..5335f5e 100644
--- a/src/cmd/upas/mkfile
+++ b/src/cmd/upas/mkfile
@@ -2,7 +2,7 @@

 LIBS=common
 #PROGS=smtp alias fs ned misc q send scanmail pop3 ml marshal vf filterkit unesc
-PROGS=smtp alias fs ned q send marshal vf misc
+PROGS=smtp alias fs ned q send marshal vf misc nfs
 #libs must be made first
 DIRS=$LIBS $PROGS

Another nedmail patch: when forwarding, nedmail leaves the subject
line of the outgoing mail blank. This patch lifts the code that sets
the subject line when replying and applies it to forwarding as well.

--- a/src/cmd/upas/ned/nedmail.c	2016-04-22 21:21:31.000000000 +0200
+++ b/src/cmd/upas/ned/nedmail.c	2016-04-22 21:27:41.000000000 +0200
@@ -181,6 +181,7 @@
 String*		rooted(String*);
 int		plumb(Message*, Ctype*);
 String*		addrecolon(char*);
+String*		addfwdcolon(char*);
 void		exitfs(char*);
 Message*	flushdeleted(Message*);
 
@@ -1949,6 +1950,8 @@
 {
 	char **av;
 	int i, ai;
+	Message *nm;
+	String *subject = nil;
 	String *path;
 
 	if(m == &top){
@@ -1970,6 +1973,15 @@
 	else
 		av[ai++] = "mime";
 
+	for(nm = m; nm != &top; nm = nm->parent){
+		if(*nm->subject){
+			av[ai++] = "-s";
+			subject = addfwdcolon(nm->subject);
+			av[ai++] = s_to_c(subject);;
+			break;
+		}
+	}
+
 	av[ai++] = "-A";
 	path = rooted(extendpath(m->path, "raw"));
 	av[ai++] = s_to_c(path);
@@ -2608,6 +2620,19 @@
 	return str;
 }
 
+String*
+addfwdcolon(char *s)
+{
+	String *str;
+
+	if(cistrncmp(s, "fwd:", 4) != 0){
+		str = s_copy("Fwd: ");
+		s_append(str, s);
+	} else
+		str = s_copy(s);
+	return str;
+}
+
 void
 exitfs(char *rv)
 {
