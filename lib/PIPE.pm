package PIPE;
#-----------------------------------------------+
#    [APM] This moudle was created by amp.pl    |
#    [APM] Created time: 2018-10-22 16:05:58    |
#-----------------------------------------------+
=pod

=head2 v1.0

Date: 2018-10-22 16:05:58

=head1 Name

PIPE -- used to init pipeline

=head1 Synopsis



=head1 Feedback

Author: Peng Ai
Email:  aipeng0520@163.com

=head1 Version

Version history

=head2 v1.0 beta

Date: 10/22/2018 04:09:47 PM

=cut

use strict;
use warnings;

require Exporter;
our @ISA       = qw(Exporter);

use File::Path qw/rmtree remove_tree mkpath make_path/;
use Cwd 'abs_path';

use FindBin qw/$Bin/;
use lib "$FindBin::RealBin";
use lib "$FindBin::RealBin/lib";
use lib "$FindBin::RealBin/../";
use lib "$FindBin::RealBin/../lib";

use PIPE::DEBUG;
use PIPE::CONF qw/load_conf/;
use PIPE::STEP;
use PIPE::MARKDOWN;

#===  FUNCTION  ================================================================
#         NAME: new
#      PURPOSE: create a new object to init a pipeline
#   PARAMETERS: -name, -outdir, -conf_file
#      RETURNS: a 'PIPE' object
#  DESCRIPTION: 
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub new {
    my ($class,%opts) = @_;

    my $pipe = {};
    bless $pipe , $class;

    $pipe->init_pipe(%opts);

    return $pipe;
}

sub init_pipe {
    my ($class,%opts) = @_;

# -name
    ERROR("no_pipe_name") unless $opts{'-name'};
    $class->{pipe_name} = $opts{'-name'};

# -outdir
    my $outdir = $opts{'-outdir'} || $opts{'-name'};
    $outdir = abs_path($outdir);

# -conf
    if (ref $opts{'-conf'} eq "HASH") {
        $class->{conf} = $opts{'-conf'};
    } else {
        $class->{conf} = load_conf($opts{'-conf'});
    }

## init some public vars 
    $class->{step_id}     = 1;
    $class->{analysis_id} = 1;
    $class->{path}        = $outdir;
    $class->{shelldir}    = "$outdir/shell";
    $class->{mode}        = $opts{'-mode'} || "shell";
    $class->{ctime}       = ftime();  # created time
    $class->{ftime}       = "NA";  # finished time
    $class->{steps}       = {};

# for 'track' model, will save all detail run info (contain time) in MySQL
    if ($class->{mode} eq "track") {

    }
}

#===  FUNCTION  ================================================================
#         NAME: step
#      PURPOSE: create a step object
#   PARAMETERS: -name    <STR>    the name of this step
#               -cpu     <INT>    the max job of this step, default 1, effective without analysis in step
#               -mem     <STR>    the max memory used, default '1G'
#               -queue   <STR>    qsub the jobs to specific queue, default null
#               -threads <INT>    the threads number for each job, default 1, effective without analysis in step
#      RETURNS: a step object
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub step {
    my ($class,%opts) = @_;
    my $step = PIPE::STEP->new($class,%opts);
    $class->{steps}->{$step->{id}} = $step;
    return $step;
}

# return all steps object of a pipe
sub all_steps {
    my ($class,%opts) = @_;
    my @steps = map { $class->{steps}->{$_} } sort {$a<=>$b} keys %{$class->{steps}};
    return @steps;
}

# return all analysis object of a pipe, default contain steps object 
# options: -no_step
sub all_analysis {
    my ($class,%opts) = @_;

    my @analysis;
    my @steps = $class->all_steps;
    foreach (@steps) {
        @analysis = $opts{'-no_step'} ? (@analysis,$_->all_analysis) : (@analysis,$_,$_->all_analysis);
    }
    return @analysis;
}

sub run {
    my ($class,%opts) = @_;

    if ($class->{mode} eq "shell") {
        $class->make_path_tree();
        $class->create_shell(-run=>0);
        $class->pipeinfo();
    } elsif ($class->{mode} eq "track") {
        $class->make_path_tree();
        $class->create_shell(-run=>1);
        $class->pipeinfo();
    }
}

sub make_path_tree {
    my ($class,%opts) = @_;

    rmtree($class->{path}) if ($opts{'-clear'});

    my @folders   = map { $_->{path} } $class->all_analysis();
    my @shelldirs = map { $_->{shelldir} } grep { $_->{shelldir} } $class->all_steps();
    mkpath($class->{path},0,0755);
    mkpath(\@folders,0,0755);
    mkpath($class->{shelldir},0,0755);
    mkpath(\@shelldirs,0,0755);
}


# create shell files of all steps 
sub create_shell {
    my ($class,%opts) = @_;

    open my $fh_total_sh , ">" , "$class->{shelldir}/all_steps.sh" or die $!;
    foreach my $step ( $class->all_steps() ) {
        $step->{ctime} = ftime();
        my $step_sh = "$class->{shelldir}/SH$step->{id}.$step->{name}.sh";
        open my $fh_step_sh , ">" , $step_sh or die $!;

        foreach my $analysis ( $step->all_analysis() ) {
            if ( $analysis->{cmd} eq "" ) {
                WARN("The cmd of step [$analysis->{id}.$analysis->{name}] is null, skip ...");
                next;
            }

            $analysis->{ctime} = ftime();
            
            my $analysis_sh = "$step->{shelldir}/SH$analysis->{id}.$analysis->{name}.sh";
            open my $fh_analysis_sh , ">" , $analysis_sh or die $!;
            print $fh_analysis_sh $analysis->{cmd};
            close $fh_analysis_sh;
            
            print $fh_step_sh qsub_cmd($analysis,$analysis_sh,$opts{'-run'});
            $analysis->{ftime} = ftime();
        }

        print $fh_step_sh $step->{cmd} if $step->{cmd};
        close $fh_step_sh;

        print $fh_total_sh qsub_cmd($step,$step_sh,$opts{'-run'});
        $step->{ftime} = ftime();
    }
    close $fh_total_sh;
    $class->{ftime} = ftime();
}


sub qsub_cmd {
    my ( $object  , $shell , $run )= @_;
    return "" unless $object->{cmd};

    my $cmd = "# step $object->{id}: $object->{name}\n";
    $cmd .= qq|echo [`date +"%F %T"`] start to run step $object->{id}, $object->{name} ...\n|;
    if ($object->{cpu} == 1) {
        my $time = time();
        $cmd .= "qsub -cwd -S /bin/sh -sync y -q $object->{queue} -l vf=$object->{mem} -o $shell.o$time -e $shell.e$time $shell\n";
    } else {
        $cmd .= "qsub-sge.pl --queue=$object->{queue} --convert no --resource vf=$object->{mem} --maxjob $object->{cpu} $shell\n";
    }
    $cmd .= qq|echo [`date +"%F %T"`] finished step $object->{id}, $object->{name}.\n\n|;

    if ($run && $run !~ /^no$/i) {
        system($cmd);
        return "";
    } else {
        return $cmd 
    }
}


# create a file with markdown format to save the detail pipe run information step by step
sub pipeinfo {
    my ($class,%opts) = @_;

    my $markdown = <<MD;
[TOC]

## Pipeline: $class->{pipe_name}

Created User: **$ENV{USER}**
Created Time: **`$class->{ctime}`**
Finished Time: **`$class->{ftime}`**

Work dir: **`$class->{path}`**
Total shell file: **`$class->{shelldir}/all_steps.sh`**
MD

    foreach my $step ( $class->all_steps() ) {
        $markdown .= <<MD;
\n### $step->{id}.$step->{name}\n
+ Created time: **`$step->{ctime}`**
+ Finished time: **`$step->{ftime}`**
+ Work dir: **`$step->{path}`**
+ Shell file: **`$class->{shelldir}/SH$step->{id}.$step->{name}.sh`**
+ CPUs: **$step->{cpu}**
+ Queue: **$step->{queue}**
+ Memory: **$step->{mem}**
MD
        $markdown .= md_cmd($step);
        foreach my $analysis ( $step->all_analysis() ) {
            $markdown .= <<MD;
\n#### $analysis->{id}.$analysis->{name}
+ Created time: **`$analysis->{ctime}`**
+ Finished time: **`$analysis->{ftime}`**
+ Work dir: **`$analysis->{path}`**
+ Shell file: **`$class->{shelldir}/$step->{id}.$step->{name}/SH$analysis->{id}.$analysis->{name}.sh`**
+ Cpus: **$analysis->{cpu}**
+ Queue: **$analysis->{queue}**
+ Memory: **$analysis->{mem}**
MD
            $markdown .= md_cmd($step);
        }
    }

    my $fname = $opts{'-file'} || $class->{pipe_name};
    open my $fh_md , ">$class->{path}/${fname}.pipe.md" or die "can't open file $fname";
    print $fh_md $markdown;
    close $fh_md;
}
