package Taught::GradeSheet;

use Taught::Definer;
use Taught::Skeleton;
use Taught::Roster;
use Taught::CourseFile;

use vars qw(@ISA $VERSION);
@ISA = qw(Taught::Definer Taught::Skeleton);

# $Id: GradeSheet.pm,v 1.2 2001/01/24 21:18:54 dblack Exp $
# $Name: Taught-0-0-3-pre1 $
# $Author: dblack $

use strict;

$VERSION = '0.0.3';

sub TIEHASH {
    my $class = shift;
    my $self = bless {}, $class;
    $self->{DATAFILE} = "gradesheet";

    my $params = $self->_init(@_);

    my ($t, $c, $s) =
        map { $self->{$_} } qw( Term Course Section );

#   Get hold of roster and course (requirement) info,
#   by querying the appropriate tied hashes.
    my %roster;
    tie %roster, "Taught::Roster", {
                Term        => $t,
                Course  => $c,
                Section => $s,
                RO          => 1,
    };

    my %course;
    tie %course, "Taught::CourseFile", {
                Term        => $t,
                Course  => $c,
                RO          => 1,
    };

    my (@reqs) = sort keys %course;
    my $reqn = @reqs;

#   Trust the course file for reqs, but keep both
#   lists of students: the grade file, and the roster.
    $self->{course} = \%course;
    $self->{roster} = \%roster;

#   untie %roster;
#   untie %course;

    my $sre = '\s*([\w.,\ \'-]+?)\s+\|\s+';
    $sre .= '(\S+)\s*' x $reqn;

    my $oft = '%-20s|  ';
    $oft .= '%-8s' x $reqn;

    my $defaults = {
        CCHR => '#',
        FILE => $self->{FILE},
        SRE  => $sre,
       OFT  => $oft,
        FLDS => [ "Name", @reqs ],
        HDR  => $self->_canonical_header,
        SSUB    => 'Name cmp Name',
    };

    $self->_new($params, $defaults);
    return $self;
}

sub course {
    my $self = shift;
    return $self->{course};
}

sub roster {
    my $self = shift;
    return $self->{roster};
}

sub reqs {
    my $self = shift;
    return sort keys %{$self->{course}};
}

sub on_roster {
    my $self = shift;
    return sort keys %{$self->{roster}};
}

sub on_sheet {
    my $self = shift;
    return sort keys %{$self->{RECS}};
}

#   On roster but not gradesheet.
sub missing {
    my $self = shift;
    return sort grep { ! $self->{RECS}{$_} }
                keys %{$self->{roster}}
}

#   On gradesheet but not roster.
sub extras {
    my $self = shift;
    return sort grep { ! $self->{roster}{$_} }
                keys %{$self->{RECS}}
}

sub _canonical_header {
    my $self = shift;
    return
        (join ", ",
            $self->cp,
            $self->tp,
            "Section $self->{Section}") . " --- grades";
}

1;

__END__

=head1 NAME

Taught::GradeSheet -- handles gradesheets for Taught suite

=head1 SYNOPSIS

    use Taught::GradeSheet;

    my $params =  {
                     Term       => $string,
                     Course     => $string,
                     Section    => $string,
                     RO         => $bool,
    };

    my %grades;
    my $gr = tie %grades, "Taught::GradeSheet", $params; 

    my @studs = $gr->studs;      # list of students
    my @reqs = $gr->reqs;        # list of requirements

    $grades{"Black, David. A."}{"Exam 1"} = "D-";

    # Alternate syntax for tying, using ordered
    # list of term/course/section arguments:

    my $co = tie %course, "Taught::GradeSheet",
                ($term, $course, $section,
                   { RO => $bool });

=head1 DESCRIPTION

Taught::GradeSheet is part of the Taught suite of course-management
software.  It operates on the union of a roster file and a course file,
producing a gradesheet with one space per student per course requirement.
(See Taught::Roster and Taught::CourseFile.)

Taught::GradeSheet is used by B<gradelog>, a program in the Taught
suite used for interactive entry of students' grades.

Taught::GradeSheet is a subclass of Taught::Definer.  See
Taught::Definer for more on the behavior and general format of
the data files defined by that module and its subclasses.

=head1 METHODS

=over 4

=item C<reqs>

Returns a sorted list of all the requirements (Exam 1, etc.) for
the course.

=item C<course>

Returns a reference to a hash tied to the Taught course file for
this course.

=item C<roster>

Returns a reference to a hash tied to the Taught roster file for
this section.

=item C<on_roster>

Returns a sorted list of names of students on the roster for this
section.

=item C<on_sheet>

Returns a sorted list of names of students on the gradesheet for
this section.

=item C<extras>

Returns a sort list of names of students who are on the gradesheet
for this section, but are not on the roster.

=item C<missing>

Returns a sort list of names of students who are on the roster
for this section, but are not on the gradesheet.

=back

=head1 AUTHOR

David Alan Black (blackdav@shu.edu), Associate Professor, Department of
Communication, Seton Hall University, South Orange, NJ 07079. 

=head1 COPYRIGHT AND DISCLAIMER

Copyright (c) 2000, David Alan Black.  This program is free software;
you may redistribute it and/or modify it under the same terms as Perl
itself.  This software comes with no warranty of any kind whatsoever.
Use at your own risk.

=head1 HISTORY

This software is part of the Taught suite of course-maintenance software.
Taught has developed (and is still developing) out of various small
programs and modules I've written and had scattered around for years.

=head1 SEE ALSO

The rest of the Taught software package, which is available at
E<lt>I<http://icarus.shu.edu/dblack/taught>E<gt>.  My Web site, which includes
other software and documents of possible interest to teachers, is at
E<lt>I<http://pirate.shu.edu/~blackdav>E<gt>.

=cut
