#!/usr/bin/perl

use strict;
use warnings;

my $docker_file    = 'Dockerfile';
my $maintainer_env = 'EXPLORER_MAINTAINER';
my $path_sep       = '/';
sub usage {
    return "$0 create|build|run {args}

This is a shortcut for quick learning using Docker to isolate your system.

ENVIRONMENTAL VARIABLES:
    EXPLORER_MAINTAINER - if present it will use this as the MAINTAINER unless command line arg given

create <name> [docker image] [maintainer]
    Will create a directory structure and a Dockerfile 'stub'
    name will be used to create subdirectory in the current directory - it will die if directory already exists
    The following are order specific!!!
        If 'docker image' not provided then script will ask.
        If 'maintainer' is not provided it will try to use \$ENV{$maintainer_env} or it will ask

build
    Assumes that you are in the directory where your Dockerfile exists and builds it.
    Basically does: docker build --rm=false -t <docker name> .
        docker name is the parent directory - if you are in /tmp/xyz then docker name is xyz

exec
    connects you to your running container (assumes that run/daemon have be run)
    Basically does: docker exec -it my_<docker name> /bin/bash


daemon
    Basically does: docker run -d --rm --name my_<docker name> -v <dir>/code:/code <docker name>
    

run [view] [additional run options]
    runs your docker (docker image name is the parent directory) mounting the code directory
    Basically does: docker run -it --rm --name my_<docker name> -v <dir>/code:/code <docker name> /bin/bash
    if 'view' is provided then it will show you the command instaed of running it.
    anything else provided (other than 'view') will be pasted into the run command:
      IE: run -p 3000:3000
        docker run -it --rm -p 3000:3000 --name my_<docker name> -v <dir>/code:/code <docker name> /bin/bash
";
}

die usage() . "\n" unless @ARGV;

my $cmd = shift @ARGV;

if    ($cmd eq 'create') { create();                }
elsif ($cmd eq 'build')  { build();                 }
elsif ($cmd eq 'exec')   { connect_to();            }
elsif ($cmd eq 'daemon') { daemon();                }
elsif ($cmd eq 'run')    { run();                   }
else  { die "Unrecognized command!\n" . usage() . "\n"; }

sub create {
    my $name       = $ARGV[0] || die("No name provided for create command\n" . usage() . "\n");
    my $from       = $ARGV[1] || '';
    my $maintainer = $ARGV[2] || '';

    die("$name directory already exists\n") if -d $name;

    if (!$from) {
        print "What Docker image will the be based on: ";
        $from = <STDIN>;
        chomp($from);
        die("no image name provided\n") unless $from;
    }

    if (!$maintainer) {
        if (exists $ENV{$maintainer_env}) {
            $maintainer = $ENV{$maintainer_env};
        }
        else {
            print "Who is Docker image maintainer: ";
            $maintainer = <STDIN>;
            chomp($maintainer);
            die("no image maintainer provided\n") unless $maintainer;
        }
    }

    system("mkdir $name");
    system("mkdir $name/code");

    open(my $fh, '>', "$name$path_sep$docker_file") || die("Unable to open file ($name$path_sep$docker_file) for write: $!\n");
    print $fh "FROM $from\n";
    print $fh "MAINTAINER $maintainer\n\n";
    while (my $line = <DATA>) {
        print $fh $line;
    }
    close($fh);
}

sub build {
    my $image_name  = get_name();
    system("docker build --rm=false -t $image_name .");
}

sub run {
    my $image_name  = get_name();
    my $docker_name = "my_$image_name";

    if (@ARGV == 1 && $ARGV[0] eq 'view') {
        print("docker run -it --rm --name $docker_name -v $ENV{PWD}/code:/code $image_name /bin/bash\n");
    }
    else {
        my $extra_args = @ARGV ? join(' ' , @ARGV) : '';
        system("docker run -it --rm $extra_args --name $docker_name -v $ENV{PWD}/code:/code $image_name /bin/bash");
    }
}

sub connect_to {
    my $image_name  = get_name();
    my $docker_name = "my_$image_name";

    system("docker exec -it $docker_name /bin/bash");
}

sub daemon {
    my $image_name  = get_name();
    my $docker_name = "my_$image_name";

    my $extra_args = @ARGV ? join(' ' , @ARGV) : '';
    system("docker run -d --rm $extra_args --name $docker_name -v $ENV{PWD}/code:/code $image_name");
}

sub get_name {
    my $path = $ENV{PWD} || die("No PWD environmental information found\n");
    my @parts = split(/$path_sep/, $path);
    return lc($parts[-1]);
}

__DATA__

WORKDIR /code

RUN echo 'alias ll="ls -al"' >> ~/.bashrc;