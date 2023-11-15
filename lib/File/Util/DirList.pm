package File::Util::DirList;

use strict;
use warnings;
use Log::ger;

use Exporter qw(import);
use Perinci::Object;

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(
                       mv_files_to_dirs
               );
# cp_files_to_dirs
# ln_files_to_dirs

our %SPEC;

our %argspecs_common = (
    files_then_dirs => {
        'x.name.is_plural' => 1,
        'x.name.singular' => 'file_or_dir',
        summary => 'One or more existing file names then the same number of existing directories',
        schema => ['array*', of=>'filename::exists*', min_len=>2],
        pos => 0,
        slurpy => 1,
    },
);

sub _cp_or_mv_or_ln_files_to_dirs {
    my $action = shift;
    my %args = @_;

    my ($files_then_dirs, $half_size);
  CHECK_ARGUMENTS: {
        $files_then_dirs = $args{files_then_dirs} or return [400, "Please specify files_then_dirs"];
        (ref $files_then_dirs eq 'ARRAY') && (@$files_then_dirs >= 2) && (@$files_then_dirs % 2 == 0)
            or return [400, "files_then_dirs must be array of even number of elements, minimum 2"];
        $half_size = @$files_then_dirs / 2;
        for my $i ($half_size .. $#{$files_then_dirs}) {
            -d $files_then_dirs->[$i] or return [400, "files_then_dirs[$i] not a directory"];
        }
    }

    my $envres = envresmulti();

    require File::Copy::Recursive;

  FILE:
    for my $i (0 .. $half_size-1) {
        my $file = $files_then_dirs->[$i];
        my $dir  = $files_then_dirs->[$i+$half_size];

        if ($action eq 'mv') {
            if ($args{-dry_run}) {
                log_info "[DRY_RUN] [#%d/%d] Moving %s to dir %s ...", $i+1, scalar(@$files_then_dirs), $file, $dir;
                $envres->add_result(200, "OK (dry-run)", {item_id=>$i, payload=>$file});
            } else {
                log_info "[#%d/%d] Moving %s to dir %s ...", $i+1, scalar(@$files_then_dirs), $file, $dir;
                my $ok = File::Copy::Recursive::rmove($file, $dir);
                if ($ok) {
                    $envres->add_result(200, "OK", {item_id=>$i, payload=>$file});
                } else {
                    log_error "Can't move %s to dir %s: %s", $file, $dir, $!;
                    $envres->add_result(500, "Error: $!", {item_id=>$i, payload=>$file});
                }
            }
        } else {
            return [501, "Action unknown or not yet implemented"];
        }
    }

    $envres->as_struct;
}

$SPEC{mv_files_to_dirs} = {
    v => 1.1,
    summary => 'Move files to directories, one file to each directory',
    args => {
        %argspecs_common,
    },
    features => {
        dry_run => 1,
    },
};
sub mv_files_to_dirs {
    _cp_or_mv_or_ln_files_to_dirs('mv', @_);
}

1;
# ABSTRACT: File utilities involving a list of directories

=head1 SYNOPSIS

 use File::Util::Tempdir qw(get_tempdir get_user_tempdir);

 my $tmpdir = get_tempdir(); # => e.g. "/tmp"

 my $mytmpdir = get_user_tempdir(); # => e.g. "/run/user/1000", or "/tmp/1000"


=head1 DESCRIPTION


=head1 FUNCTIONS

None are exported by default, but they are exportable.

=head2 get_tempdir

Usage:

 my $dir = get_tempdir();

A cross-platform way to get system-wide temporary directory.

On Windows: it first looks for one of these environment variables in this order
and return the first value that is set: C<TMP>, C<TEMP>, C<TMPDIR>, C<TEMPDIR>.
If none are set, will look at these directories in this order and return the
first value that is set: C<C:\TMP>, C<C:\TEMP>. If none are set, will die.

On Unix: it first looks for one of these environment variables in this order and
return the first value that is set: C<TMPDIR>, C<TEMPDIR>, C<TMP>, C<TEMP>. If
none are set, will look at these directories in this order and return the first
value that is set: C</tmp>, C</var/tmp>. If none are set, will die.

=head2 get_user_tempdir

Usage:

 my $dir = get_user_tempdir();

Get user's private temporary directory.

When you use world-writable temporary directory like F</tmp>, you usually need
to create randomly named temporary files, such as those created by
L<File::Temp>. If you try to create a temporary file with guessable name, other
users can intercept this and you can either: 1) fail to create/write your
temporary file; 2) be tricked to read malicious data; 3) be tricked to write to
other location (e.g. via symlink).

This routine is like L</"get_tempdir"> except: on Unix, it will look for
C<XDG_RUNTIME_DIR> first (which on a Linux system with systemd will have value
like C</run/user/1000> which points to a RAM-based tmpfs). Also,
C<get_user_tempdir> will first check that the temporary directory is: 1) owned
by the running user; 2) not group- and world-writable. If not, it will create a
subdirectory named C<$EUID> (C<< $> >>) with permission mode 0700 and return
that. If that subdirectory already exists and is not owned by the user or is
group-/world-writable, will try C<$EUID.1> and so on.

It will die on failure.


=head1 SEE ALSO

L<File::Spec> has C<tmpdir> function. It also tries to look at environment
variables, e.g. on Unix it will look at C<TMPDIR> (but not C<TEMPDIR>) and
then falls back to C</tmp> (but not C</var/tmp>).

L<File::HomeDir>, a cross-platform way to get user's home directory and a few
other related directories.

L<File::Temp> to create a temporary directory.

L<https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html>
for the specification of C<XDG_RUNTIME_DIR>.
