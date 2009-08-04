#!/home/acme/perl-5.10.0/bin/perl
use strict;
use warnings;
use Capture::Tiny qw(tee);
use IO::File;

# perlhist says: 5.10.0 2007-Dec-18


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
git bisect run /home/acme/run.pl
git bisect reset

=cut

=for file_removed ext/Storable/MANIFEST

# for file_added autodie:
# git log --before=2009-06-01 -n 1
# 20f91e418dfa8bdf6cf78614bfebebc28a7613ee
git bisect reset
git bisect start
git bisect good 20f91e418dfa8bdf6cf78614bfebebc28a7613ee
git bisect bad HEAD
git bisect run /home/acme/run.pl
git bisect reset

=cut

my $log = IO::File->new('>> /home/acme/git/run.log') || die $!;
$log->autoflush(1);

# file_added('./lib/autodie.pm');
file_removed('ext/Storable/MANIFEST');

sub file_added {
    my $filename = shift;

    my $describe = ( call_or_error('git describe') )[1];
    chomp $describe;
    error('No git describe') unless $describe;
    message("\n\n*** $describe ***\n\n");

    if ( -f $filename ) {
        message("have $filename\n");
        exit 1;
    } else {
        message("do not have $filename\n");
        exit 0;
    }
}

sub file_removed {
    my $filename = shift;

    my $describe = ( call_or_error('git describe') )[1];
    chomp $describe;
    error('No git describe') unless $describe;
    message("\n\n*** $describe ***\n\n");

    if ( -f $filename ) {
        message("have $filename\n");
        exit 0;
    } else {
        message("do not have $filename\n");
        exit 1;
    }
}

sub perl {

    # chdir "perl";

    my $describe = ( call_or_error('git describe') )[1];
    chomp $describe;
    error('No git describe') unless $describe;
    message("\n\n*** $describe ***\n\n");

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

    my $status = ( call('./perl -Ilib /home/acme/git/testcase.pl') )[0];
    message("Status: $status\n");

    call_or_error('git clean -dxf');
    call_or_error('git checkout ext/IPC/SysV/SysV.xs makedepend.SH');

    exit $status;
}

sub call {
    my $command = shift;
    my $status;
    my ( $stdout, $stderr ) = tee {
        $status = system($command);
    };
    return ( $status >> 8, $stdout, $stderr );
}

sub call_or_error {
    my $command = shift;
    my ( $status, $stdout, $stderr ) = call($command);
    unless ( $status == 0 ) {
        error("$command failed: $?: $stderr");
    }
    message($command);
    return ( $status, $stdout, $stderr );
}

sub message {
    my $text = shift;
    $log->print("$text\n");
    print "$text\n";
}

sub error {
    my $text = shift;
    $log->print("$text\n");
    warn $text;
    exit 125;
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
