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
        summary => 'One or more existing file (or directory) names then the same number of existing directories',
        schema => ['array*', of=>'pathname::exists*', min_len=>2],
        req => 1,
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
                $envres->add_result(200, "OK (dry-run)", {item_id=>$file});
            } else {
                log_info "[#%d/%d] Moving %s to dir %s ...", $i+1, scalar(@$files_then_dirs), $file, $dir;
                my $ok = File::Copy::Recursive::rmove($file, $dir);
                if ($ok) {
                    $envres->add_result(200, "OK", {item_id=>$file});
                } else {
                    log_error "Can't move %s to dir %s: %s", $file, $dir, $!;
                    $envres->add_result(500, "Error: $!", {item_id=>$file});
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
    examples => [
        {
            summary => 'Move f1 to d1, f2 to d2, f3 to d3',
            argv => [qw/f1 f2 f3 d1 d2 d3/],
            test => 0,
            'x.doc.show_result' => 0,
        },
    ],
};
sub mv_files_to_dirs {
    _cp_or_mv_or_ln_files_to_dirs('mv', @_);
}

1;
# ABSTRACT: File utilities involving a list of directories

=cut
