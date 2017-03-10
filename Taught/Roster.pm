package Taught::Roster;

#   Taught::Roster -- create and manipulate "roster" files
#   
#   Part of the Taught suite of course-management software.
#
#   David Alan Black, October 2000
#
# $Id: Roster.pm,v 1.2 2001/01/24 21:18:54 dblack Exp $
# $Name: Taught-0-0-3-pre1 $
# $Author: dblack $

use vars qw(@ISA $VERSION);
use File::Basename;
use Taught::Skeleton;
use Taught::Definer;
@ISA = qw(Taught::Definer Taught::Skeleton);

$VERSION = '0.0.3';

use strict;

sub TIEHASH {
    my $class = shift;
    my $self = bless {}, $class;

    $self->{DATAFILE} = "roster";
    my $params = $self->_init(@_);

#   Defaults for Taught::Roster version of Taught::Definer.
#   These may be overridden by any program actually using this
#   class.
    my $defaults = {
        CCHR    => '#',
        FLDS    => [ qw( Name ID ) ],
        OFT => '%-30s%-15s',
        SRE => '^\s*([\w,\'.\-\ ]+?)\s+([\d-]+)\s*$',
        HDR => $self->_canonical_header,
        SSUB    => 'Name cmp Name',
        FILE    => $self->{FILE},
    };

    $self->_new($params, $defaults);
}

#   makelist() -- a special case of makegrid.
#   Provides one thick cell per person.
sub makelist {
    my ($self, $opts) = @_;
    $opts->{cheight}  = .5;
    $opts->{cells}      = 1;
    $opts->{cwidth} = 6;
    $self->makegrid($opts);
}

#   Aliases for gridtex() and gridlink(), to make
#   the "list" syntax consistently available.
sub listtex {
    my $self = shift;
    $self->gridtex(@_);
}

sub listlink {
    my $self = shift;
    $self->gridlink(@_);
}

sub makegrid {
    my ($self, $opts) = @_;

    my @studs       = sort keys %{$self->{RECS}};
    my $studs       = @studs;
    my $cwidth      = ($opts->{cwidth} || .40) - .25;
    my $cheight     = $opts->{cheight} || .175;
    my $cellno      = $opts->{cells} || 6.5 / ($cwidth + .25);
    my $cellspec    = ('& \cell ' x $cellno) . '\\\\';

    my $tabspec     = '{|l|' . ('l|' x $cellno) . '}';
    my $header      = exists $opts->{header}
                                ? $opts->{header}
                                : $self->{HDR};
    $header         .= " --- $opts->{req}"
                                if $header && $opts->{req};

    my $req         = $opts->{req};
    my $texfile     = $self->_gridfiles($req)->{texfile};
    my $perpage     = $opts->{perpage} || 20;
    my $page        = 1;
    my $pages       = int ($studs / $perpage) + ($studs % $perpage > 0);

    my $pagestart   = _pagestarter($header, $page, $pages, $tabspec);

    if ( -e "$texfile" &&! $opts->{force}) {
        print "Overwrite $texfile? ";
        die "No overwrite.\n" unless <STDIN> =~ /y/i;
    }

    chomp (my $date = `date`);
    my $latextop = <<EOM;
\\documentclass{article}
%
% $texfile
%
% LaTeX output file created by the Taught::Roster module
% from the Taught suite of course-management software,
% $date
%
\\usepackage{fullpage}
\\setlength{\\textheight}{10.5in}
\\setlength{\\topmargin}{-1in}
\\newcommand{\\cell}{\\hspace*{${cwidth}in}}
\\begin{document}
\\pagestyle{empty}
\\setlength{\\parindent}{0pt}
\\setlength{\\parskip}{0pt}
EOM
    $latextop .= &$pagestart;

    open (OUT, ">$texfile") or die "Can't write to $texfile: $!";

    print OUT $latextop;

    my $line = 1;
    foreach (@studs) {
        if ( $line > 1 &&!( ($line - 1) % $perpage) ) {
            print OUT "\\end{tabular}\n\\newpage\n"
                            . &$pagestart;
            $line = 1;
        }

        print OUT <<EOM;
    \\small{$_}
    \\rule{0pt}{${cheight}in}%
    $cellspec
    \\hline
EOM
        print OUT "\\hline\n" unless $line % 5;
        $line++;
    }

    print OUT "\\end{tabular}\n\\end{document}\n";
    close OUT or die $!;
}

#
#   Postprocessing -- run LaTeX and create symlinks to the DVI files.
#

#   Run LaTeX on grid.
sub gridtex {
    my $self = shift;
    my $outfile = $self->_gridfiles(@_)->{texfile};
    chomp (my $oldpwd = `pwd`);
    my $newwd = dirname($outfile);

    chdir $newwd                        or die "Can't chdir to $newwd: $!";
    system("latex $outfile")        and warn "LaTeX failed on $outfile: $!";
    chdir $oldpwd                       or die "Can't chdir to $oldpwd: $!";
}

#   Create symbolic link to grid DVI file.
sub gridlink {
    my $self = shift;
    my ($file, $link) = @{$self->_gridfiles(@_)}{qw( fullfile link )};
    return !(system("ln -sf $file.dvi $link"));
}


#
#
#   Private methods
#
#


#   Subroutines for canonical filenames and headers.
#   These assume a valid term/course/section.
#   They do not fare well in the face of missing elements.


sub _canonical_header {
    my $self = shift;
    return join ", ",
                $self->cp,
                $self->tp,
                "Section $self->{Section}";
}

sub _gridfiles {
    my ($self, $req) = @_;
    $req = "" unless defined $req;
    my $fullfile = $self->_filename($req);      # Full path to filename
    my $link = $self->_linkname($req);          # Full path to symbolic link
    return
            {
                fullfile    => $fullfile,
                texfile => "$fullfile.tex",     # LaTeX output file
                link        => $link,
            };
}

sub _linkname {
    my ($self, $req) = @_;
    $req =~ s/\ /_/g;

    my $name = $self->cp . ".$self->{Section}";
    $name .= ".$req" if $req;
    $name .= ".dvi";

    return
            join '/',
                    $self->_linkdir,    # lists
                    $name
}

sub _filename {
    my ($self, $req) = @_;
    $req =~ s/\ /_/g;
    $req = $req ? "$req.list" : "grid";
    return "$self->{SDIR}/$req";
}

sub _linkdir {
    my $self = shift;
    return "$self->{TDIR}/lists"
}

#   _pagestarter() returns a closure which keeps track of page
#   numbers in _makesheet, embedding them in a nice LaTeX
#   page header.
sub _pagestarter {
    my ($header, $page, $pages, $tabspec) = @_;
    return
            sub {
                my $text = <<EOM;
{\\Large\\textsf{$header\\hfill(page $page of $pages)}}\\\\
\\par\\vspace*{1em}
\\begin{tabular}{$tabspec}
\\hline
EOM
                $page++;
                return $text;
            }
}

1;
__END__


##########################################################

=head1 NAME

Taught::Roster -- class roster module from Taught suite

=head1 SYNOPSIS

    use Taught::Roster;
    my %roster;
    my $ro = tie %roster, "Taught::Roster",
            ({
                 Term     => $string,
                 Course   => $string,
                 Section  => $string,
                 RO       => $bool,      # read-only
                 
            });
 
    $roster{"Student, John Q."} = 0123;  # enroll student
 
    $ro->makegrid($hashref);
    $ro->gridtex;
    $ro->gridlink;
    $ro->makelist($hashref);
    $ro->listtex($string);
    $ro->listlink($string)

    # Alternate syntax for tying, using ordered
    # list of term/course arguments:

    my $ro = tie %roster, "Taught::Roster",
             ($term, $course, $section, { RO => $bool });

=head1 DESCRIPTION

Taught::Roster is a subclass of Taught::Definer, and is part of the Taught
suite of teaching tools.  Taught::Roster defines the class roster format:

  # Hitchcock, Fall 1999, Section AA
  # -----------------------------------------------
  # Name                    ID
  # -----------------------------------------------
  # Student, John Q.        123456789
  # The, Other              987654321
    END

Taught::Roster conforms to the Taught specification for file layout and
naming.  It expects you to have a B<~/teaching> directory (or to set
the I<TAUGHT> environment variable).  See the Taught package for details.

You can use Taught::Roster to manipulate the data in your roster file,
and also to automate the creation of "grid" and "list" files.  A grid
file is suitable for taking attendance.  A list file (which is really
a grid file with only one big cell per line) is good for logging comments
on assignments, because it gives you room to write a fair amount on
each line.  

In fact, Taught::Roster provides a fairly general mechanism for creating
grid sheets based on the students' names.  See L<METHODS>, below.

=head2 Output files and their names

Every Taught::Roster object operates on a roster file in
a Taught section directory.  Output include the roster file
itself, upon creation or updating, as well as LaTeX and
DVI files if you create grids.

Given this:

    $ENV{TAUGHT} = "$ENV{HOME}/teaching";  # the default

    my $ro = tie %roster, "Taught::Roster", ({
                Term     => "falll1999",
                Course   => "hitchcock",
                Section  => "AA" });

    my $args = { force => 1 };      # force overwrite
                                    # see METHODS for more options

if you do this:

    $ro->makegrid($args);
    $ro->gridtex;
    $ro->gridlink;

the resulting files and link would be:

    ~/teaching/fall1999/hitchcock/AA/grid.tex     # grid file
    ~/teaching/fall1999/hitchcock/AA/grid.dvi     # DVI file
    ~/teaching/fall1999/lists/Hitchcock.AA.dvi    # symlink to DVI file

If you supply a string argument -- generally the name
of a requirement:

    my $req = "Final Exam";
    $args->{req} = $req;
    $ro->makegrid($args);
    $ro->gridtex($req);
    $ro->gridlink($req);

then the results would be:

    ~/teaching/fall1999/hitchcock/AA/Final_Exam.list.tex
    ~/teaching/fall1999/hitchcock/AA/Final_Exam.list.dvi
    ~/teaching/fall1999/lists/Hitchcock.AA.Final_Exam.dvi

Note that these files are called "list" instead of "grid".
Anything with a requirement name built into it is considered
a list.  If you want a list with one big cell per line, you
can do:

    $ro->makelist($args);
    $ro->listtex($req);
    $ro->listlink($req);

Each file has a header based on the course name, the term,
the section, and the requirement (if given).  In the above situation,
the file F<grid.tex> would have the header:

   Hitchcock, Fall 1999, Section AA

F<Exam_1.list.tex> would have the header:

   Hitchcock, Fall 1999, Section AA --- Exam 1

=head1 METHODS

=over 4

=item C<makegrid($hashref)>

=item C<makelist($hashref)>

I<makegrid> creates a LaTeX file with one line for each student,
and a header specifying this roster's term, course, and section.

I<makelist> is a frontend to I<makegrid>, specifically for creating
a file with one wide "cell" per line.  This is useful for recording
comments, per student, on an assignment (whereas the finer grids are
better for taking attendance).

The hash reference by I<$hashref> can contain values for the following:

=back

=over 8

=item cells

number of cells per line in grid.  Default is
calculated based on width of cells 

=item cheight

height of each cell, in inches (default: .175in)

=item cwidth

width of each cell, in inches (defaults: .25in)

=item force

force overwrite of .tex file

=item perpage

number of lines (students) per page

=item req

a requirement (e.g., "Term Paper") which is used in header and filenames.

=back

The default grid is a fairly fine grid with 16 cells per line.  

=over 4

=item C<gridtex>

=item C<gridtex(I<requirement>)>

These methods run LaTeX on the .tex files output by I<makegrid> and
I<makelist>.  I<listtex> is an alias for I<gridtex>.  If I<requirement>
is provided, it will be added to the header and the output filenames.

=item C<gridlink>

=item C<gridlink(I<requirement>)>

These methods create symbolic links from a special directory to the
.dvi files output by I<gridtex> and I<listtex>.  If I<requirement>
is provided, it will be added to the header and the output filenames.

=item C<listtex>, C<listlink>

These are aliasas for the "grid" equivalents.

=back

=head1 EXAMPLES

If you have them, look at the B<makelist> and B<makegrid> programs, which
are essentially frontends to the Taught::Roster module.

A couple of other examples:

    # after tying %roster to Taught::Roster
    # with the underlying object in $r:
    
    # Grid with five cells per line, .2 inches wide.
    $r->makegrid( { cells => 5, cwidth => .2 });
    
    # Grid with five cells per line, cell width determined
    # dynamically to fill line.
    $r->makegrid( { cells => 5 });

=head1 BUGS AND LIMITATIONS

The grid/list stuff is pretty hard-coded for a certain size and
layout of paper.  

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
