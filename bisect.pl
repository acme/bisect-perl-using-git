#!/home/acme/perl-5.10.0/bin/perl
use strict;
use warnings;
use Capture::Tiny qw(tee);
use IO::File;

my $log = IO::File->new('>> /home/acme/git/run.log') || die $!;
$log->autoflush(1);

=for file_added autodie

# for file_added autodie:
# git log --before=2008-12-01 -n 1
# 1409bc0658469580630ba458c85fe9cc3cb2d78c
# git log --before=2008-12-31 -n 1
# 675b0f774d374f6951c02c6463c64a746ad46acd
git bisect reset
git bisect start
git bisect good 1409bc0658469580630ba458c85fe9cc3cb2d78c
git bisect bad 675b0f774d374f6951c02c6463c64a746ad46acd
git bisect run /home/acme/git/bisect/bisect.pl
git bisect reset

=cut

# file_added('./lib/autodie.pm');

=for file_removed ext/Storable/MANIFEST

# for file_added autodie:
# git log --before=2009-06-01 -n 1
# 20f91e418dfa8bdf6cf78614bfebebc28a7613ee
git bisect reset
git bisect start
git bisect good 20f91e418dfa8bdf6cf78614bfebebc28a7613ee
git bisect bad HEAD
git bisect run /home/acme/git/bisect/bisect.pl
git bisect reset

=cut

# file_removed('ext/Storable/MANIFEST');

=for perl_fails

# http://rt.perl.org/rt3/Public/Bug/Display.html?id=62056
# perl-5.8.8
# use charnames ':full';
# my $x;
# m/$x\N{START OF HEADING}/
git bisect reset
git bisect start
git bisect good perl-5.8.8
git bisect bad perl-5.10.0
git bisect run /home/acme/git/bisect/bisect.pl
git bisect reset

=cut

perl_fails('/home/acme/testcase.pl');

=for command_fails

# for file_added autodie:
# git log --before=2009-06-01 -n 1
# 20f91e418dfa8bdf6cf78614bfebebc28a7613ee
git bisect reset
git bisect start
git bisect good 20f91e418dfa8bdf6cf78614bfebebc28a7613ee
git bisect bad HEAD
git bisect run /home/acme/git/bisect/bisect.pl
git bisect reset

=cut

# command_fails('"./perl -Ilib $filename ');

sub file_added {
    my $filename = shift;
    describe();

    if ( -f $filename ) {
        message("have $filename");
        exit 1;
    } else {
        message("do not have $filename");
        exit 0;
    }
}

sub file_removed {
    my $filename = shift;
    describe();

    if ( -f $filename ) {
        message("have $filename");
        exit 0;
    } else {
        message("do not have $filename");
        exit 1;
    }
}

sub perl_fails {
    my $filename = shift;
    describe();

    call_or_error('git clean -dxf');

    # Fix configure error in makedepend: unterminated quoted string
    # http://perl5.git.perl.org/perl.git/commitdiff/a9ff62
    call_or_error(q{perl -pi -e "s|##\`\"|##'\`\"|" makedepend.SH});

    # Allow recent gccs (4.2.0 20060715 onwards) to build perl.
    # It switched from '<command line>' to '<command-line>'.
    # http://perl5.git.perl.org/perl.git/commit/d64920
    call_or_error(
        q{perl -pi -e "s|command line|command-line|" makedepend.SH});

    # Allow IPC/SysV to compile on recent Linux
    # http://perl5.git.perl.org/perl.git/commit/205bd5
    call_or_error(
        q{perl -pi -e "s|#   include <asm/page.h>||" ext/IPC/SysV/SysV.xs});

    call_or_error(
        'sh Configure -des -Dusedevel -Doptimize="-g" -Dcc=ccache\ gcc -Dld=gcc'
    );

    -f 'config.sh' || error('Missing config.sh');

    call_or_error('make');
    -x './perl' || error('No ./perl executable');

    my $code = call("./perl -Ilib $filename")->{code};
    message("Status: $code");
    if ( $code < 0 || $code >= 128 ) {
        message("Changing code to 127 as it is < 0 or >= 128");
        $code = 127;
    }

    call_or_error('git clean -dxf');
    call_or_error('git checkout ext/IPC/SysV/SysV.xs makedepend.SH');

    exit $code;
}

sub describe {
    my $describe = call_or_error('git describe')->{stdout};
    chomp $describe;
    error('No git describe') unless $describe;
    message("\n*** $describe ***\n");
}

sub call {
    my $command = shift;
    my $status;
    my ( $stdout, $stderr ) = tee {
        $status = system($command);
    };
    my $code = $status >> 8;
    return {
        code   => $code,
        stdout => $stdout,
        stderr => $stderr,
    };
}

sub call_or_error {
    my $command  = shift;
    my $captured = call($command);
    unless ( $captured->{code} == 0 ) {
        error( "$command failed: $?: " . $captured->{stderr} );
    }
    message($command);
    return $captured;
}

sub message {
    my $text = shift;
    $log->print("$text\n");
    print "$text\n";
}

sub error {
    my $text = shift;
    message($text);
}

__END__

# If you can use ccache, add -Dcc=ccache\ gcc -Dld=gcc to the Configure line
sh Configure -des -Dusedevel -Doptimize="-g" -Dcc=ccache\ gcc -Dld=gcc
test -f config.sh || exit 125
# Correct makefile for newer GNU gcc
perl -ni -we ' print unless /<(?:built-in|command)/' makefile x2p/makefile
# if you just need miniperl, replace test_prep with miniperl
make -j4 test_prep
-x ./perl || exit 125
./perl -Ilib /home/acme/git/testcase.pl
ret=$?
git clean -dxf
exit $ret
