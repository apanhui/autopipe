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

# load software 
    if ($ENV{'AP_PATH'} && -e "$ENV{'AP_PATH'}/etc/software.conf") {
        $class->{soft} = load_conf("$ENV{'AP_PATH'}/etc/software.conf");
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
    if ($class->{mode} eq "track") { }
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

    if ($class->{'mode'} eq "shell") {
        $class->make_path_tree();
        $class->create_shell(-run=>0);
        $class->pipeinfo();
    } elsif ($class->{'mode'} eq "track") {
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


#-------------------------------------------------------------------------------
# create shell files of all steps 
#-------------------------------------------------------------------------------
sub create_shell {
    my ($class,%opts) = @_;
    
    timeLOG("** start to create pipe: [$class->{pipe_name}] **");
    open my $fh_total_sh , ">" , "$class->{shelldir}/all_steps.sh" or die $!;
    foreach my $step ( $class->all_steps() ) {
        timeLOG("**** start to run step: [$step->{id}.$step->{name}] ****");
        $step->{ctime} = ftime();
        my $step_sh = "$class->{shelldir}/SH$step->{id}.$step->{name}.sh";
        open my $fh_step_sh , ">" , $step_sh or die $!;

        foreach my $analysis ( $step->all_analysis() ) {
            if ( $analysis->{cmd} eq "" ) {
                WARN("The cmd of step [$analysis->{id}.$analysis->{name}] is null, skip ...");
                next;
            }

            timeLOG("****** start to run substep: [$analysis->{id}.$analysis->{name}] ******");
            $analysis->{ctime} = ftime();
            
            my $analysis_sh = "$step->{shelldir}/SH$analysis->{id}.$analysis->{name}.sh";
            open my $fh_analysis_sh , ">" , $analysis_sh or die $!;
            print $fh_analysis_sh $analysis->{cmd};
            close $fh_analysis_sh;
            
            print $fh_step_sh qsub_cmd($analysis,$analysis_sh,$opts{'-run'});
            $analysis->{ftime} = ftime();
            timeLOG("****** substep [$analysis->{id}.$analysis->{name}] was done ******");
        }

        print $fh_step_sh $step->{cmd} if $step->{cmd};
        close $fh_step_sh;

        print $fh_total_sh qsub_cmd($step,$step_sh,$opts{'-run'});
        $step->{ftime} = ftime();
        timeLOG("**** step [$step->{id}.$step->{name}] was done ****");
    }
    close $fh_total_sh;
    $class->{ftime} = ftime();
    timeLOG("** pipe [$class->{pipe_name}] was done :) **");
}


sub qsub_cmd {
    my ( $object  , $shell , $run )= @_;
    return "" unless $object->{cmd};
    
    my $qsub = $object->{parent}->soft('qsub');
    my $sge  = $object->{parent}->soft('qsubsge');

    my $cmd = "# step $object->{id}: $object->{name}\n";
    $cmd .= qq|echo [`date +"%F %T"`] start to run step $object->{id}, $object->{name} ...\n|;
    if ($object->{cpu} == 1) {
        my $time = time();
        $cmd .= "$qsub -cwd -S /bin/sh -sync y -q $object->{queue} -l vf=$object->{mem} -o $shell.o$time -e $shell.e$time $shell\n";
    } else {
        $cmd .= "$sge --queue=$object->{queue} --convert no --resource vf=$object->{mem} --maxjob $object->{cpu} $shell\n";
    }
    $cmd .= qq|echo [`date +"%F %T"`] finished step $object->{id}, $object->{name}.\n\n|;

    if ($run && $run !~ /^no$/i) {
        system($cmd);
        return "";
    } else {
        return $cmd 
    }
}


#-------------------------------------------------------------------------------
# create a file with markdown format to save the detail pipe run information step by step
#-------------------------------------------------------------------------------
sub pipeinfo {
    my ($class,%opts) = @_;
    
    my $prjid = $class->{conf}->{project_id} || "NA";
    my $markdown = md_context($class,2);

    foreach my $step ( $class->all_steps() ) {
        $markdown .= md_context($step,3);
        $markdown .= md_cmd($step);
        foreach my $analysis ( $step->all_analysis() ) {
            $markdown .= md_context($analysis,4);
            $markdown .= md_cmd($analysis);
        }
    }

    my $fname = $opts{'-file'} || $class->{pipe_name};
    open my $fh_md , ">$class->{path}/${fname}.pipe.md" or die "can't open file $fname";
    print $fh_md $markdown;
    close $fh_md;

    return "$class->{path}/${fname}.pipe.md";
}


#-------------------------------------------------------------------------------
#  fetch the sample names which defined in the config 
#-------------------------------------------------------------------------------
sub samples {
    my ($class,%opts) = @_;
    $opts{'-attr'} ||= "samples";
    $opts{'-sep'} ||= "[;,\\s\\t]";

    if (exists $class->{conf}->{$opts{'-attr'}}){
        my @samples = split /$opts{'-sep'}/ , $class->{conf}->{$opts{'-attr'}};
        return @samples;
    } else {
        ERROR("The samples is not defined in config! [$opts{'-attr'}]");
    }
}

#-------------------------------------------------------------------------------
# fetch the software of database path 
#-------------------------------------------------------------------------------
sub soft {
    my $class = shift;
    my $name = shift;

    if ($class->{conf}->{$name}){
        return $class->{conf}->{$name};
    } elsif ($class->{conf}->{soft}->{$name}) {
        return $class->{conf}->{soft}->{$name};
    } elsif ($class->{conf}->{software}->{$name}) {
        return $class->{conf}->{software}->{$name};
    } elsif ($class->{soft}->{$name}) {
        return $class->{soft}->{$name};
    } elsif (`which $name`) {
        my $p = `which $name`;
        chomp $p;
        return $p;
    } else {
        ERROR('no_software_exists',$name);
    }
}
