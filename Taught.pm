#!/usr/bin/perl -w

# $Id: Taught.pm,v 1.2 2001/01/24 21:19:11 dblack Exp $
# $Name: Taught-0-0-3-pre1 $
# $Author: dblack $

=head1 NAME

Taught.pm -- information management for teaching database

=head1 SYNOPSIS

=over 4

=item C<use Taught qw(:standard);>

=item C<scan Taught;>

=item C<my $teachhome = tdir()>

=item C<my %reqs = reqs(I<term>, I<course>);>

=item C<my @tlist = terms();>

=item C<my $bool = isterm(I<term>);>

=item C<my @tlist = terms_with(I<course>);>

=item C<my @clist = courses_in(I<term>);>

=item C<my @slist = sections_of(I<term>, I<course>);>

=item C<my @studlist = students_in(I<term>, I<course>, I<section>);>

=item C<my @clist = course_names();>

=item C<my $thash = ttree([[[I<term>,] I<course>,] I<section>]);>

=item C<newterm(I<term>)>;

=item C<my $chash = newcourse(I<term>, I<course>);>

=item C<my $rhash = newsection(I<term>, I<course>, I<section>);>

=back

=head1 DESCRIPTION

Taught.pm is part of the Taught suite of course-maintenance software.
Its chief role is to scan the master teaching directory (usually
I<$HOME/teaching>) and build a data tree of terms (semesters),
courses, and sections.  It then makes various views of that tree
available through its query methods.

=head2 The Taught directory structure in brief

The directory structure scanned and parsed by Taught.pm is the
structure used generally in the Taught suite of course-maintenance
software.  See the main Taught documentation for details.  In brief,
the directory structure uses a naming hierarchy based on the following
levels:

   master                        (top-level directory)
      term                       (i.e., semester; e.g., "fall1999")
          course                 (e.g., "seminar", "hitchcock")
             section             (e.g., "AA") 
             section
               ...  
          course
           ...
      term
      ...

Any section can thus be uniquely identified, below the master level,
by three strings: term, course, section.  For example, the directory
F<fall1999/hitchcock/AA> will contain the class roster and grading
information for Section AA of the Hitchcock course offered in the Fall
of 1999.  The section level also contains F<.tex> and F<.dvi> versions
of nicely formatted attendance sheets and grade-book pages, if you
decide to generate these.

At the "course" level of the hierarchy (for example, in
F<fall1999/hitchcock>) is stored the course-description file,
F<cfile>, which contains a list of all the requirements for the course
and the percentage value of each one.

At the "term" level, in addition to the course subdirectories, there
is a directory called F<lists>, which contains symbolic links to the
F<.dvi> files mentioned above.  

Finally, each level contains a directory called F<docs>, which is
intended as a private space for miscellaneous materials.  None of the
Taught software examines or changes anything in these areas.

=head2 The interface to the directory structure

Taught.pm encapsulates pretty much everything; you can write programs
which use it without having to do any file IO yourself.  The
abstraction described above -- directory names corresponding to term,
course, and section -- should suffice.

Taught.pm makes use of the Taught::Roster and Taught::CourseFile
modules.  Those modules, in turn, make use of Taught::Definer, a
generic tool for defining and using simple plain-text databases.  (See
the Taught package.)  Caution: the Taught::Definer-derived modules
tend to allow either a list of arguments (in a predefined order) or a
reference to a hash of arguments.  In most cases, Taught.pm passes the arguments
along pretty much intact, so for methods which use Taught::Definer
either approach will work.  But sometimes Taught.pm behaves in its own
way, for various reasons.  So follow the argument syntax under
L<METHODS>, below.  (Of course you can examine the underpinnings,
and/or do your own programming with Taught::Definer and relatives if
you like.)

=cut

package Taught;

$VERSION = '0.0.3';
use strict;
use Carp;
use File::Path;
use Taught::Roster;
use Taught::CourseFile;

require Exporter;
use vars qw(@ISA %EXPORT_TAGS @EXPORT_OK @EXPORT);
@ISA = qw(Exporter);
%EXPORT_TAGS = (
    standard => [qw(
                            scan 
                            newterm 
                            newcourse 
                            newsection 
                            terms_with 
                            course_names 
                            courses_in 
                            sections_of 
                            students_in
                            reqs 
                            terms 
                            ttree
                            isterm 
                            tdir 
            )]
    );

@EXPORT_OK      = @{$EXPORT_TAGS{standard}};

my $TEre            = '(^[^\W\d_]+)(\d+)$';             # Regex for terms
my $SEre            = '(^[^\W\d_]{2})$';                    # Regex for sections
my %T_EXDIRS    = map { $_, 1 } qw(docs lists); # Extra directories
my @T_EXDIRS    = keys %T_EXDIRS;
my @C_EXDIRS    = qw(docs);
my @S_EXDIRS    = qw(docs);

#   Always return the same reference (since there's no point having
#   two Taught objects in existence).
my $taught;
if (!$taught) {
    $taught = bless {}, __PACKAGE__;
}

#   To work around lack of object first argument in imported method calls

sub AUTOLOAD {
    use vars qw($AUTOLOAD);
    my $func = $AUTOLOAD;
    return if $func =~ /::DESTROY/;
    @_ = __ref_or(@_);
    $func =~ s/::([^_])/::_$1/;
    no strict qw(refs);
    &{$func}(@_);
}

sub __ref_or {
    return $taught unless defined $_[0];
    $_[0] eq $taught ? (@_) : ($taught, @_);
}

=head1 METHODS

Note: all of these methods are exported in the C<:standard> export
tag.  They can also be called on a Taught object.  You can get
such an object back from C<scan()>.  

Other note: some methods require I<term> and/or I<course>
and/or I<section> arguments.  Such argument lists always go in
the order term, course, section.  When they're passed in as
hashes, which some methods require, the keys should be initially
capitalized, as shown.  

=over 4

=item C<scan()>

Triggers the scan of the master teaching directory, and
the gathering of all information.  The usual way to use
this module is: 

    use Taught qw(:standard);
    scan Taught;

C<scan()> returns a Taught object -- in fact, I<the> Taught
object, as only one such object can be instantiated per program
run.

=cut

sub _scan {
    my ($self) = $taught;

    ($self->{_tdir}
            = $ENV{TAUGHT} || "$ENV{HOME}/teaching/")
            =~ s!([^/])$!$1/!;
    my $tdir = $self->tdir;

    $ENV{PATH} = "$ENV{PATH}:$tdir/bin";

    chdir $tdir or die $!;
    my @terms = grep { -d && /^$TEre$/ } <*>;

TERMS:
    for my $t (@terms) {
        $self->{_taught}{$t} = {};
        chdir $tdir or die $!;
        chdir $t or next TERMS;

        my @courses =
            grep { !$T_EXDIRS{$_} }
            grep { -d }
            <*>;

COURSES:
        for my $c (@courses) {
            $self->{_taught}{$t}{$c} = {};
            chdir "$tdir/$t/$c" or next COURSES;
            my @sections = grep { -d && /^$SEre$/ } <*>;

SECTIONS:
            for my $s (@sections) {
                $self->{_taught}{$t}{$c}{$s} = {};
            }
        }
        chdir $tdir or die $!;
    }
    return $self;
}

=item C<tdir()>

Returns the full path to the master Taught directory (usually F<~/teaching>).

=cut

sub _tdir {
    my ($self) = shift;
    $self->{_tdir} = shift if @_;
    return $self->{_tdir}
}


#
# Queries
#

=item C<reqs(I<term>, I<course>)>

Returns a hash of all course requirements for specified
course.  Keys are requirement names; values are percentage
values.

=cut

sub _reqs {
    my $self = shift;
    my %course;
    tie %course,
        "Taught::CourseFile",
        (@_, { RO => 1 } );
    my %reqs = map { $course{$_}->{Assignment}, $course{$_}->{Value} } keys %course;
    untie %course;
    return %reqs;
}

=item C<terms()>

Returns a list of all terms in the master teaching directory.
Order is not guaranteed.

=cut

sub _terms {
    my ($self) = shift;
    return keys %{$self->{_taught}}
}

=item C<isterm(I<term>)>

Boolean: true if term I<term> exists.

=cut

sub _isterm {
    my ($self, $t) = @_;
    return $self->{_taught}{$t}
}

=item C<terms_with(I<course>)>;

Returns a list of terms during which I<course> has been taught.

=cut

sub _terms_with {
    my ($self, $c) = @_;
    my @res = ();
    for my $t (keys %{$self->{_taught}}) {
        push @res, $t if $self->{_taught}{$t}{$c}
    }
    return @res;
}

=item C<courses_in(I<term>)>

Returns a list of all courses taught during I<term>.

=cut

sub _courses_in {
    my ($self, $t) = @_;
    return keys %{$self->{_taught}{$t}};
}


=item C<sections_of(I<term>, I<course>)>

Returns a list of all sections of I<course> offered
during I<term>.

=cut

sub _sections_of {
    my ($self, $t, $c) = @_;
    return keys %{$self->{_taught}{$t}{$c}}
}

=item C<students_in(I<term>, I<course>, I<section>)>

Returns a list of all students in specified section.

=cut

sub _students_in {
    my $self = shift;
    my %roster;
    tie %roster, "Taught::Roster", (@_, { RO => 1 } );
    return [ keys %roster ];
}

=item C<course_names()>

Returns a uniqued list of the names of all courses taught
during all terms.

=cut

sub _course_names {
    my ($self) = @_;
    my $tt = $self->{_taught};
    my @names = map { keys %{$tt->{$_}} } keys %{$tt};
    return keys %{{@names, @names}}
}

=item C<ttree([[[I<term>,] I<course>,] I<section>])>

Returns a recursive structure (hash reference) containing all sections
(or just I<section>, if specified) of all courses
(or just I<course>, if specified) during all terms
(or just I<term>, if specified).  

=cut

sub _ttree {
    my ($self, $T, $C, $S) = @_;
    $_ = $_ || 0 for ($T, $C, $S);
    
    my %tree;
    for my $t (grep { /$T/ ||! $T } $self->terms) {
        $tree{$t} = {};
        for my $c (grep { /$C/ ||! $C }  $self->courses_in($t)) {
            $tree{$t}{$c} = {};
            for my $s (grep { /$S/ ||! $S } $self->sections_of($t, $c)) {
                $tree{$t}{$c}{$s} = {}
            }
        }
    }
    return \%tree;
}

#
# Methods to create new terms, courses, and sections
#

=item C<newterm( { Term => I<term> } )>

Create a new term called 'term'.  Creates directories as needed.
Silently succeeds if section already exists.

=cut

sub _newterm {
    my ($self, $params) = @_;
    my $t = $params->{Term};
    $self->__vivifydirs($t, \@T_EXDIRS) or die $!;
    return $self;
}

=item C<newcourse( { Term => I<term>, Course => I<course>,
reqs => $reqs, (clobbered|replace)  => $bool } )>

=item C<newsection( { Term => I<term>, Course => I<course>, Section => I<section>,
studs => $studs, (clobbered|replace)  => $bool } )>

Create a new course or section directory, for the given
term/course[/section].  Returns a reference to a hash tied to the data
file.  Creates directories as needed; silently succeeds if directories
already exist.  With clobbered flag true, deletes all old entries
(reqs or studs).  With replace flag, replaces any overlapping old/new
ones, but leaves other old ones alone.  With neither flag (or C<append
=> 1>, if you like), leaves all old ones alone and only adds unique
new ones.

=cut

sub _newcourse {
    my ($self, $params) = @_;
    my ($t, $c) = @{$params}{qw( Term Course )};
    my $reqs = $params->{reqs} || {};

    $self->__vivifydirs("$t/$c", \@C_EXDIRS) or die $!;
    $self->__updaterows("Taught::CourseFile", $reqs, $params);
}

sub _newsection {
    my ($self, $params) = @_;
    my ($t, $c, $s) = @{$params}{qw(Term Course Section)};
    my $studs = $params->{studs} || {};

    $self->__vivifydirs("$t/$c/$s", \@S_EXDIRS) or die $!;
    $self->__updaterows("Taught::Roster", $studs, $params);
}

sub __updaterows {
    my ($self, $type, $records, $params) = @_;
    my %tieee;
    tie %tieee, $type, $params;
    (tied %tieee) ->touch;
    my ($clb, $rep) = @{$params}{qw( clobber replace )};
    if ($clb) {
        %tieee = %$records
    }
    elsif ($rep) {
        @tieee{keys %$records} = @{$records}{keys %$records};
    }
    else {
        for (keys %$records) {
            $tieee{$_} = $records->{$_} unless $tieee{$_}
        }
    }
    return \%tieee;
}

sub __vivifydirs {
    my $self = shift;
    my $basedir = shift;
    my $extras = shift || [];
    my $tdir = $self->tdir;

    -d
        or mkpath $_
        or die $!
            for "$tdir/$basedir",
                map { "$tdir/$basedir/$_" } @$extras;
    return $self;
}

=back

=cut

1;

__END__

=head1 EXAMPLES

The best examples of the uses of this module are in the
programs in the Taught package, especially B<setup> and
prepterm.

=head1 BUGS AND LIMITATIONS

Please report any.

=head1 AUTHOR

David Alan Black (blackdav@shu.edu), Associate Professor, Department
of Communication, Seton Hall University, South Orange, NJ 07079. 

=head1 COPYRIGHT AND DISCLAIMER

Copyright (c) 2000, David Alan Black.  This program is free software;
you may redistribute it and/or modify it under the same terms as Perl
itself.  This software comes with no warranty of any kind whatsoever.
Use at your own risk.

=head1 HISTORY

This software is part of the Taught suite of course-maintenance
software.  Taught has developed (and is still developing) out of
various small programs and modules I've written and had scattered
around for years.

=head1 SEE ALSO

The rest of the Taught software package, which is available at
E<lt>I<http://icarus.shu.edu/dblack/taught>E<gt>.

=cut
