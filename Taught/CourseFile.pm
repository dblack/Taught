package Taught::CourseFile;

use vars qw(@ISA);
use Taught::Definer;
use Taught::Skeleton;
@ISA = qw(Taught::Definer Taught::Skeleton);

# $Id: CourseFile.pm,v 1.2 2001/01/24 21:18:54 dblack Exp $
# $Name: Taught-0-0-3-pre1 $
# $Author: dblack $

use strict;

sub TIEHASH {
    my $class = shift;
    my $self = bless {}, $class;

    $self->{DATAFILE} = "cfile";
    my $params = $self->_init(@_);

    my $defaults = {
        CCHR    => '#',
        FLDS    => [ qw( Assignment Value ) ],
        OFT => '%-25s = %3s',
        SRE => '^\s*(.*\b)\s*=\s*(\d+)$',
        HDR => $self->_canonical_header,
        SSUB    => 'Value <=> Value',
        FILE    => $self->{FILE},
    };

    $self->_new($params, $defaults);
}

sub _canonical_header {
    my $self = shift;
    return join ", ",
                $self->cp,
                $self->tp;
}

__END__


=head1 NAME

Taught::CourseFile -- handles course-requirement files for Taught suite

=head1 SYNOPSIS

    use Taught::CourseFile;

    my %course;
    my $co = tie %course, "Taught::CourseFile",
                {
                   Term       => $string,
                   Course     => $string,
                   RO         => $bool,
                };

    $course{Midterm} = { Value => 25 };       # worth 25%
    $course{"Final Exam"} = 35;               # alternate syntax


    # Alternate syntax for tying, using ordered
    # list of term/course arguments:

    my $co = tie %course, "Taught::CourseFile",
             ("$term", "$course", { RO => $bool });

=head1 DESCRIPTION

Taught::CourseFile is part of the Taught suite of course-management
software.  It defines a course description file, which contains
one line per course requirement.  That line contains the name
of the requirement, an equal sign, and the percentage value of
the requirement.

In the standard Taught file hierarchy, files created and maintained by this
module reside at the "course" level, and are given the name F<cfile>.
A typical F<cfile> might look like this:

    # Hitchcock, Fall 2000, Section AA
    # _______________________________________________
    # Assignment       Value
    # _______________________________________________
      Midterm          25
      Final Exam       35
      Term Paper       40
      END

See the Taught documentation for more on the Taught directory structure
and hierarchy.

Taught::CourseFile is a subclass of Taught::Definer.  See
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
E<lt>I<http://icarus.shu.edu/dblack/taught>E<gt>.  My Web site,
which includes other software and documents of possible interest to
teachers, is at E<lt>I<http://pirate.shu.edu/~blackdav>E<gt>.

=cut
