package Taught::GradeReport;

use Taught::Definer;
use Taught::Skeleton;
use Taught::Roster;
use Taught::CourseFile;

use vars qw(@ISA $VERSION);
@ISA = qw(Taught::Definer Taught::Skeleton);

# $Id: GradeReport.pm,v 1.2 2001/01/24 21:18:54 dblack Exp $
# $Name: Taught-0-0-3-pre1 $
# $Author: dblack $

use strict;

$VERSION = '0.0.3';

sub TIEHASH {
    my $class = shift;
    my $self = bless {}, $class;
    $self->{DATAFILE} = "report";

    my $params = $self->_init(@_);

    my ($t, $c, $s) =
        map { $self->{$_} } qw( Term Course Section );

#   Person, John Q. :  B+
    my $sre = '^\s*([\w.,\ \'-]+?)\s*:\s*([\w+-]+)\s*$';

    my $oft = '%-25s: %-2s';

    my $defaults = {
        CCHR => '#',
        FILE => $self->{FILE},
        SRE  => $sre,
       OFT  => $oft,
        FLDS => [ "Name", "Grade"],
        HDR  => $self->_canonical_header,
        SSUB    => 'Name cmp Name',
    };

    $self->_new($params, $defaults);
}

sub _canonical_header {
    my $self = shift;
    return
        (join ", ",
            $self->cp,
            $self->tp,
            "Section $self->{Section}") . " --- final grades";
}

1;

__END__

=head1 NAME

Taught::GradeReport -- do final grade calculations

=head1 SYNOPSIS

    use Taught::GradeReport;

    my %grades;
    my $gr = tie %grades, "Taught::GradeReport",
                {
                   Term       => $string,
                   Course     => $string,
                   Section    => $string,
                   RO         => $bool,
                };

    $grades{"Black, David A."} = "F";

    # Alternate syntax for tying, using ordered
    # list of term/course/section arguments:

    my $gr = tie %course, "Taught::GradeReport",
                 ($term, $course, $section,
                   { RO => $bool });

=head1 DESCRIPTION

Taught::GradeReport defines a subclass of Taught::Definer, to
handle final grade lists for sections, as per the specifications
of the Taught suite of course-management software.  

This module will mainly be of interest to anyone writing a program
to calculate grades, or a program allowing manual entry of final
grades for a course.  See, for example, B<dogrades>, in the Taught
package.

Taught::GradeReport is a subclass of Taught::Definer.  See
Taught::Definer for more on the behavior and general format of
the data files defined by that module and its subclasses.

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
