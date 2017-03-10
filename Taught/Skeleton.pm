package Taught::Skeleton;

#   Common things for Roster, CourseFile, and GradeSheet.

#   Calculates TAUGHT, FILE, CDIR/SDIR.

# $Id: Skeleton.pm,v 1.2 2001/01/24 21:18:54 dblack Exp $
# $Name: Taught-0-0-3-pre1 $
# $Author: dblack $

use strict;

sub _init {
    my $self = shift;

    my $params = {};
    if (ref $_[0]) {
        $params = shift
    }
    elsif (ref $_[-1]) {
        $params = pop;
    }

    my @levels = qw( Term Course Section );
    for my $l (@levels) {
        next if $params->{$l} ||! @_;
        $params->{$l} = shift;
    }

#   Set some lexical variables, to save typing, and
#   some instance data.
    $self->{TAUGHT} = $params->{TAUGHT}
                                || $ENV{TAUGHT}
                                || "$ENV{HOME}/teaching";

    $self->{$_} = $params->{$_} || ""
        for @levels;

#   Set $self->{[TCS]DIR} and $self->{FILE}
    my %dirnames = (
                                Term        => "TDIR",
                                Course  => "CDIR",
                                Section => "SDIR"
                        );

    my $filedir = $self->{TAUGHT};

    for (grep { defined $self->{$_} } @levels) {
        $filedir .= "/$self->{$_}";
        $self->{ $dirnames{$_} } = $filedir;
    }
    $self->{FILE} = "$filedir/$self->{DATAFILE}";

    return $params;
}

#
#   Prettification routines (and/or underscores for spaces)
#

sub cp {
    my $self = shift;
    my $c = $self->{Course} or return;
    $c =~ s/^([a-z])/uc$1/e;        # Capitalized course name.
    return $c;
}

sub cu {
    my $self = shift;
    my $c = $self->{Course} or return;
    $c =~ s/ /_/g;                  # Spaces to '_'.
    return $c;
}

sub tp {
    my $self = shift;
    my $t = $self->{Term} or return;
    $t =~ s/(\D+)(\d+)/\u$1 $2/;    # Term name prettified.
    return $t;
}

1;
